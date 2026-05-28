#!/usr/bin/env julia

import YAML

function usage()
    println(stderr, """
    Usage:
      generate-dependabot.jl [--inventory PATH] [--list-repos]
      generate-dependabot.jl [--inventory PATH] [--describe] REPO
      generate-dependabot.jl [--inventory PATH] REPO
    """)
end

function parse_args(args)
    options = Dict{String,Any}(
        "inventory" => "DependabotConfig/repo-inventory.yml",
        "list_repos" => false,
        "describe" => false,
        "repo" => nothing,
    )

    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--inventory"
            index += 1
            index <= length(args) || error("--inventory requires a path")
            options["inventory"] = args[index]
        elseif arg == "--list-repos"
            options["list_repos"] = true
        elseif arg == "--describe"
            options["describe"] = true
        elseif startswith(arg, "--")
            error("unknown option: $(arg)")
        elseif isnothing(options["repo"])
            options["repo"] = arg
        else
            error("unexpected argument: $(arg)")
        end
        index += 1
    end

    return options
end

function normalize_repo_name(repo::AbstractString)
    parts = split(repo, "/"; limit = 2)
    return length(parts) == 2 ? String(parts[2]) : String(repo)
end

function load_inventory(path::AbstractString)
    data = YAML.load_file(path)
    data isa AbstractDict || error("Inventory must be a YAML mapping: $(path)")
    return data
end

function deep_merge(base, override)
    result = deepcopy(base)
    for (key, value) in override
        if value isa AbstractDict && get(result, key, nothing) isa AbstractDict
            result[key] = deep_merge(result[key], value)
        else
            result[key] = deepcopy(value)
        end
    end
    return result
end

function find_repo_config(inventory, repo_name::AbstractString)
    short_name = normalize_repo_name(repo_name)
    defaults = get(inventory, "defaults", Dict{String,Any}())
    repositories = get(inventory, "repositories", Any[])
    repo_config = Dict{String,Any}()

    for entry in repositories
        if normalize_repo_name(string(get(entry, "name", ""))) == short_name
            repo_config = entry
            break
        end
    end

    merged = deep_merge(defaults, repo_config)
    get!(merged, "name", short_name)
    get!(merged, "package_directories", ["/"])
    return merged
end

function bool_string(value)
    return value == true ? "true" : "false"
end

function quote_yaml(value)
    escaped = replace(string(value), "\\" => "\\\\", "\"" => "\\\"")
    return "\"$(escaped)\""
end

function schedule_lines(config, keys; indent = "      ")
    lines = String[]
    for key in keys
        if haskey(config, key) && !isnothing(config[key])
            push!(lines, "$(indent)$(key): $(quote_yaml(config[key]))")
        end
    end
    return lines
end

function print_dependabot_config(repo_config)
    dependabot = get(repo_config, "dependabot", Dict{String,Any}())
    github_actions = get(dependabot, "github_actions", Dict{String,Any}())
    julia = get(dependabot, "julia", Dict{String,Any}())
    npm = get(dependabot, "npm", Dict{String,Any}())
    julia_directories = get(repo_config, "package_directories", ["/"])
    npm_directories = get(repo_config, "npm_directories", Any[])
    printed_update = false

    function print_separator()
        if printed_update
            println()
        end
        printed_update = true
    end

    println("version: 2")
    if get(dependabot, "enable_beta_ecosystems", false) == true
        println("enable-beta-ecosystems: true")
    end
    println()
    println("updates:")

    if get(github_actions, "enabled", false) == true
        print_separator()
        println("  - package-ecosystem: \"github-actions\"")
        println("    directory: \"/\"")
        println("    schedule:")
        for line in schedule_lines(github_actions, ["interval"])
            println(line)
        end
    end

    if get(julia, "enabled", false) == true
        print_separator()
        println("  - package-ecosystem: \"julia\"")
        if length(julia_directories) == 1
            println("    directory: $(quote_yaml(only(julia_directories)))")
        else
            println("    directories:")
            for directory in julia_directories
                println("      - $(quote_yaml(directory))")
            end
        end
        println("    schedule:")
        for line in schedule_lines(julia, ["interval", "day", "time", "timezone"])
            println(line)
        end
        if get(julia, "group_all", false) == true
            println("    groups:")
            println("      all-julia-packages:")
            println("        patterns:")
            println("          - \"*\"")
        end
    end

    if get(npm, "enabled", false) == true && !isempty(npm_directories)
        print_separator()
        println("  - package-ecosystem: \"npm\"")
        if length(npm_directories) == 1
            println("    directory: $(quote_yaml(only(npm_directories)))")
        else
            println("    directories:")
            for directory in npm_directories
                println("      - $(quote_yaml(directory))")
            end
        end
        println("    schedule:")
        for line in schedule_lines(npm, ["interval", "day", "time", "timezone"])
            println(line)
        end
        if get(npm, "group_all", false) == true
            println("    groups:")
            println("      all-npm-packages:")
            println("        patterns:")
            println("          - \"*\"")
        end
    end
end

function list_repositories(inventory)
    for entry in get(inventory, "repositories", Any[])
        if haskey(entry, "name")
            println(normalize_repo_name(string(entry["name"])))
        end
    end
end

function describe_repo(inventory, repo_name::AbstractString)
    repo_config = find_repo_config(inventory, repo_name)
    directories = get(repo_config, "package_directories", ["/"])
    npm_directories = get(repo_config, "npm_directories", Any[])
    dependabot = get(repo_config, "dependabot", Dict{String,Any}())
    github_actions = get(dependabot, "github_actions", Dict{String,Any}())
    julia = get(dependabot, "julia", Dict{String,Any}())
    npm = get(dependabot, "npm", Dict{String,Any}())

    println("repo=$(normalize_repo_name(repo_name))")
    println("package_directories=$(join(directories, ","))")
    println("npm_directories=$(join(npm_directories, ","))")
    println("github_actions_enabled=$(bool_string(get(github_actions, "enabled", false)))")
    println("julia_enabled=$(bool_string(get(julia, "enabled", false)))")
    println("julia_group_all=$(bool_string(get(julia, "group_all", false)))")
    println("npm_enabled=$(bool_string(get(npm, "enabled", false)))")
    println("npm_group_all=$(bool_string(get(npm, "group_all", false)))")
    println("enable_beta_ecosystems=$(bool_string(get(dependabot, "enable_beta_ecosystems", false)))")
end

function main(args)
    options = parse_args(args)
    inventory = load_inventory(options["inventory"])

    if options["list_repos"]
        list_repositories(inventory)
        return 0
    end

    if isnothing(options["repo"])
        usage()
        return 2
    end

    if options["describe"]
        describe_repo(inventory, options["repo"])
    else
        repo_config = find_repo_config(inventory, options["repo"])
        print_dependabot_config(repo_config)
    end

    return 0
end

try
    exit(main(ARGS))
catch err
    println(stderr, "error: ", err)
    exit(1)
end
