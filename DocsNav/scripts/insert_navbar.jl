# insert_navbar.jl
#
# Usage:
#   julia insert_navbar.jl <html-file-or-directory> <navbar-file-or-url> [--exclude "path1,path2,..."]
#
# Features:
#   - Processes all .html files in the target (either a single file or recursively in a directory).
#   - Removes any previously inserted navbar block (i.e. everything between <!-- NAVBAR START --> and <!-- NAVBAR END -->)
#     along with any extra whitespace immediately following it.
#   - Inserts the new navbar block immediately after the first <body> tag.
#   - If the fetched navbar content does not contain the markers, it is wrapped (without further modification) with:
#         <!-- NAVBAR START -->
#         (navbar content)
#         <!-- NAVBAR END -->
#   - If a file does not contain a <body> tag, that file is skipped.
#   - An optional --exclude parameter (comma‑separated) will skip any file whose path contains one of the provided substrings.
#
# Required package: HTTP
#
# (Install HTTP via Julia’s package manager, e.g. using Pkg; Pkg.add("HTTP"))

using HTTP

# --- Utility: Read file contents ---
function read_file(filename::String)
    open(filename, "r") do io
        read(io, String)
    end
end

# --- Utility: Write contents to a file ---
function write_file(filename::String, contents::String)
    open(filename, "w") do io
        write(io, contents)
    end
end

# --- Exclusion Function ---
function should_exclude(filename::String, patterns::Vector{String})
    for pat in patterns
        if occursin(pat, filename)
            return true
        end
    end
    return false
end

# --- Remove any existing navbar block and any whitespace following it ---
function remove_existing_navbar(html::String)
    start_marker = "<!-- NAVBAR START -->"
    end_marker   = "<!-- NAVBAR END -->"
    while occursin(start_marker, html) && occursin(end_marker, html)
        start_idx_range = findfirst(start_marker, html)
        end_idx_range   = findfirst(end_marker, html)
        # Extract the first index from the returned range.
        start_idx = first(start_idx_range)
        end_idx   = first(end_idx_range)
        # Get prefix: everything before the start marker (or empty if start_idx is 1)
        prefix = start_idx > 1 ? html[1:start_idx-1] : ""
        # Suffix: from the end of the end marker to the end of the file,
        # then remove any leading whitespace.
        suffix = lstrip(html[end_idx + length(end_marker) : end])
        html = string(prefix, suffix)
    end
    return html
end

# --- Wrap navbar HTML with markers if not already present ---
function wrap_navbar(navbar_html::String)
    if !occursin("NAVBAR START", navbar_html) || !occursin("NAVBAR END", navbar_html)
        return "<!-- NAVBAR START -->\n" * navbar_html * "\n<!-- NAVBAR END -->"
    else
        return navbar_html
    end
end

# --- Insert new navbar into HTML ---
function insert_navbar(html::String, navbar_html::String)
    # Remove any previously inserted navbar block (and any trailing whitespace).
    html = remove_existing_navbar(html)
    # Use a regex to find the first <body> tag (case-insensitive).
    m = match(r"(?i)(<body[^>]*>)", html)
    if m === nothing
        println("Warning: Could not find <body> tag in the file; skipping insertion.")
        return html  # Return the unmodified HTML.
    end
    prefix = m.match  # The matched <body> tag.
    # Build the inserted string: the <body> tag, a newline, the navbar block, and a newline.
    inserted = string(prefix, "\n", navbar_html, "\n")
    # Replace only the first occurrence of the <body> tag with our new content.
    html = replace(html, prefix => inserted; count = 1)
    return html
end

# --- Process a Single HTML File ---
function process_file(filename::String, navbar_html::String)
    println("Processing: $filename")
    html = read_file(filename)
    html_new = insert_navbar(html, navbar_html)
    # If the HTML was not modified because no <body> tag was found, print a message and skip writing.
    if html_new == html
        println("Skipped: No <body> tag found in $filename")
    else
        write_file(filename, html_new)
        println("Updated: $filename")
    end
end

# --- Main Function ---
function main()
    if length(ARGS) < 2
        println("Usage: julia insert_navbar.jl <html-file-or-directory> <navbar-file-or-url> [--exclude \"pat1,pat2,...\"]")
        return
    end
    target = ARGS[1]
    navbar_source = ARGS[2]
    
    # Process optional --exclude argument.
    exclude_patterns = String[]
    if length(ARGS) ≥ 4 && ARGS[3] == "--exclude"
        exclude_patterns = map(x -> string(strip(x)), split(ARGS[4], ','))
    end

    # --- Get Navbar Content ---
    navbar_html = ""
    if startswith(lowercase(navbar_source), "http")
        resp = HTTP.get(navbar_source)
        if resp.status != 200
            error("Failed to download navbar from $navbar_source")
        end
        navbar_html = String(resp.body)
    else
        navbar_html = read_file(navbar_source)
    end
    # Preserve the fetched navbar content exactly; do not modify internal formatting.
    navbar_html = string(navbar_html)
    # Wrap with markers if not already present.
    navbar_html = wrap_navbar(navbar_html)

    # --- Process Files ---
    if isfile(target)
        if !should_exclude(target, exclude_patterns)
            process_file(target, navbar_html)
        else
            println("Skipping excluded file: $target")
        end
    elseif isdir(target)
        for (root, _, files) in walkdir(target)
            for file in files
                if endswith(file, ".html")
                    fullpath = joinpath(root, file)
                    if !should_exclude(fullpath, exclude_patterns)
                        process_file(fullpath, navbar_html)
                    else
                        println("Skipping excluded file: $fullpath")
                    end
                end
            end
        end
    else
        error("Target $target is neither a file nor a directory.")
    end
end

main()
