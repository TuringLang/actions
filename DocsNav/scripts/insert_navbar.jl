# insert_navbar.jl
#
# Usage:
#   julia insert_navbar.jl <html-file-or-directory> <navbar-file-or-url> [--exclude "pat1" "pat2"...]
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
#   - An optional --exclude parameter (space‑separated) will skip any file whose path contains one of the provided substrings.
#
# Installs required packages in a temporary environment.

using Pkg
Pkg.activate(temp=true)
Pkg.add("HTTP")

using HTTP
using Logging

const START_MARKER = "<!-- NAVBAR START -->"
const END_MARKER = "<!-- NAVBAR END -->"

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
should_exclude(filename::String, patterns::Vector{String}) = any(pat -> occursin(pat, filename), patterns)

# --- Remove any existing navbar block and any whitespace following it ---
function remove_existing_navbar(html::String)
    while occursin(START_MARKER, html) && occursin(END_MARKER, html)
        start_idx_range = findfirst(START_MARKER, html)
        end_idx_range = findfirst(END_MARKER, html)
        start_idx = first(start_idx_range)
        end_idx = first(end_idx_range)
        prefix = html[1:start_idx-1]
        suffix = lstrip(html[end_idx + length(END_MARKER) : end])
        html = string(prefix, suffix)
    end
    return html
end

# --- Wrap navbar HTML with markers if not already present ---
function wrap_navbar(navbar_html::String)
    if !occursin(START_MARKER, navbar_html) || !occursin(END_MARKER, navbar_html)
        return string(START_MARKER, "\n", navbar_html, "\n", END_MARKER)
    else
        return navbar_html
    end
end

# --- Insert new navbar into HTML ---
function insert_navbar(html::String, navbar_html::String, filename::String)
    html = remove_existing_navbar(html)
    m = match(r"(?i)(<body[^>]*>)", html)
    if m === nothing
        @warn "Could not find <body> tag in $(filename); skipping insertion."
        return html
    end
    prefix = m.match
    inserted = string(prefix, "\n", navbar_html, "\n")
    replace(html, prefix => inserted; count=1)
end

# --- Process a Single HTML File ---
function process_file(filename::String, navbar_html::String)
    println("Processing: $filename")
    html = read_file(filename)
    html_new = insert_navbar(html, navbar_html, filename)
    if html_new != html
        write_file(filename, html_new)
        println("Updated: $filename")
    end
end

# --- Main Function ---
function main()
    if length(ARGS) < 2
        error("Usage: julia insert_navbar.jl <html-file-or-directory> <navbar-file-or-url> [--exclude \"pat1\" \"pat2\"...]")
    end

    target = ARGS[1]
    navbar_source = ARGS[2]
    exclude_patterns = String[]

    if length(ARGS) >= 3
        if ARGS[3] == "--exclude"
            length(ARGS) < 4 && error("--exclude requires at least one pattern.")
            exclude_patterns = ARGS[4:end]
        else
            error("Invalid argument: $(ARGS[3]). Expected --exclude followed by patterns.")
        end
    end

    navbar_html = if startswith(lowercase(navbar_source), "http")
        resp = HTTP.get(navbar_source)
        resp.status != 200 && error("Failed to download navbar from $navbar_source")
        String(resp.body)
    else
        read_file(navbar_source)
    end |> wrap_navbar

    if isfile(target)
        should_exclude(target, exclude_patterns) ? println("Skipping excluded file: $target") : process_file(target, navbar_html)
    elseif isdir(target)
        for (root, _, files) in walkdir(target)
            for file in files
                endswith(file, ".html") || continue
                fullpath = joinpath(root, file)
                should_exclude(fullpath, exclude_patterns) ? println("Skipping excluded file: $fullpath") : process_file(fullpath, navbar_html)
            end
        end
    else
        error("Target $target is neither a file nor a directory.")
    end
end

main()
