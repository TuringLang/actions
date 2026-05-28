#!/usr/bin/env bash

set -euo pipefail

ORG="${ORG:-TuringLang}"
TARGET="${TARGET:-inventory}"
REMOVE_COMPATHELPER="${REMOVE_COMPATHELPER:-true}"
UPDATE_DEPENDABOT="${UPDATE_DEPENDABOT:-true}"
BRANCH="${BRANCH:-dependabot-config}"
DRY_RUN="${DRY_RUN:-true}"
INVENTORY_PATH="${INVENTORY_PATH:-DependabotConfig/repo-inventory.yml}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATOR="${SCRIPT_DIR}/generate-dependabot.mjs"

if [[ -z "${GH_TOKEN:-}" ]]; then
    echo "error: GH_TOKEN is required" >&2
    exit 1
fi

bool_is_true() {
    [[ "${1,,}" == "true" ]]
}

repo_short_name() {
    local repo="$1"
    echo "${repo#${ORG}/}"
}

repo_full_name() {
    local repo="$1"
    if [[ "$repo" == */* ]]; then
        echo "$repo"
    else
        echo "${ORG}/${repo}"
    fi
}

inventory_repos() {
    node "$GENERATOR" --inventory "$INVENTORY_PATH" --list-repos
}

target_repos() {
    case "$TARGET" in
        inventory)
            inventory_repos
            ;;
        *)
            repo_short_name "$TARGET"
            ;;
    esac
}

setting_value() {
    local repo="$1"
    local key="$2"
    node "$GENERATOR" --inventory "$INVENTORY_PATH" --describe "$repo" \
        | awk -F= -v key="$key" '$1 == key { print $2 }'
}

detect_file_state() {
    local repo_dir="$1"
    COMPATHELPER_BEFORE="missing"
    DEPENDABOT_BEFORE="missing"
    EXISTING_DEPENDABOT_PATH=""

    if [[ -f "${repo_dir}/.github/workflows/CompatHelper.yml" || -f "${repo_dir}/.github/workflows/CompatHelper.yaml" ]]; then
        COMPATHELPER_BEFORE="present"
    fi

    if [[ -f "${repo_dir}/.github/dependabot.yml" ]]; then
        DEPENDABOT_BEFORE="present"
        EXISTING_DEPENDABOT_PATH=".github/dependabot.yml"
    elif [[ -f "${repo_dir}/.github/dependabot.yaml" ]]; then
        DEPENDABOT_BEFORE="present"
        EXISTING_DEPENDABOT_PATH=".github/dependabot.yaml"
    fi
}

pr_title() {
    local compat_removed="$1"
    local dependabot_added="$2"
    local dependabot_updated="$3"

    if bool_is_true "$compat_removed" && bool_is_true "$dependabot_added"; then
        echo "Replace CompatHelper with Dependabot"
    elif bool_is_true "$compat_removed" && bool_is_true "$dependabot_updated"; then
        echo "Remove CompatHelper and update Dependabot config"
    elif bool_is_true "$dependabot_added"; then
        echo "Add Dependabot config"
    elif bool_is_true "$dependabot_updated"; then
        echo "Update Dependabot config"
    elif bool_is_true "$compat_removed"; then
        echo "Remove CompatHelper workflow"
    else
        echo "Update Dependabot config"
    fi
}

write_pr_body() {
    local body_file="$1"
    local compat_removed="$2"
    local dependabot_added="$3"
    local dependabot_updated="$4"
    local normalized_yaml="$5"
    local julia_directories="$6"
    local julia_group_all="$7"
    local npm_directories="$8"
    local npm_enabled="$9"
    local npm_group_all="${10}"
    local cargo_directories="${11}"
    local cargo_enabled="${12}"
    local cargo_group_all="${13}"

    {
        echo "## Summary"
        echo
        echo "This PR updates this repository's dependency-update automation for the TuringLang Dependabot rollout."
        echo
        echo "## Detected state before this PR"
        echo
        echo "- CompatHelper workflow: ${COMPATHELPER_BEFORE}"
        echo "- Dependabot config: ${DEPENDABOT_BEFORE}"
        if [[ -n "$EXISTING_DEPENDABOT_PATH" ]]; then
            echo "- Existing Dependabot path: \`${EXISTING_DEPENDABOT_PATH}\`"
        fi
        echo "- Julia package directories: ${julia_directories}"
        if bool_is_true "$npm_enabled"; then
            echo "- npm package directories: ${npm_directories}"
        fi
        if bool_is_true "$cargo_enabled"; then
            echo "- Cargo package directories: ${cargo_directories}"
        fi
        echo
        echo "## Changes made"
        echo
        if bool_is_true "$compat_removed"; then
            echo "- Removed CompatHelper workflow."
        fi
        if bool_is_true "$dependabot_added"; then
            echo "- Added Dependabot config."
        fi
        if bool_is_true "$dependabot_updated"; then
            echo "- Updated Dependabot config."
        fi
        if bool_is_true "$normalized_yaml"; then
            echo "- Normalized \`.github/dependabot.yaml\` to \`.github/dependabot.yml\`."
        fi
        echo
        if bool_is_true "$npm_enabled" && bool_is_true "$cargo_enabled"; then
            echo "Julia, npm, Cargo, and GitHub Actions dependency updates are configured to run weekly."
        elif bool_is_true "$npm_enabled"; then
            echo "Julia, npm, and GitHub Actions dependency updates are configured to run weekly."
        elif bool_is_true "$cargo_enabled"; then
            echo "Julia, Cargo, and GitHub Actions dependency updates are configured to run weekly."
        else
            echo "Julia and GitHub Actions dependency updates are configured to run weekly."
        fi
        if bool_is_true "$julia_group_all"; then
            echo "Julia package updates are grouped into a single Dependabot PR."
        fi
        if bool_is_true "$npm_enabled" && bool_is_true "$npm_group_all"; then
            echo "npm package updates are grouped into a single Dependabot PR."
        fi
        if bool_is_true "$cargo_enabled" && bool_is_true "$cargo_group_all"; then
            echo "Cargo package updates are grouped into a single Dependabot PR."
        fi
    } > "$body_file"
}

dry_run_repo() {
    local repo="$1"
    local full_repo
    local julia_directories
    local github_actions_enabled
    local julia_enabled
    local julia_group_all
    local npm_directories
    local npm_enabled
    local npm_group_all
    local cargo_directories
    local cargo_enabled
    local cargo_group_all

    full_repo="$(repo_full_name "$repo")"
    julia_directories="$(setting_value "$repo" julia_directories)"
    github_actions_enabled="$(setting_value "$repo" github_actions_enabled)"
    julia_enabled="$(setting_value "$repo" julia_enabled)"
    julia_group_all="$(setting_value "$repo" julia_group_all)"
    npm_directories="$(setting_value "$repo" npm_directories)"
    npm_enabled="$(setting_value "$repo" npm_enabled)"
    npm_group_all="$(setting_value "$repo" npm_group_all)"
    cargo_directories="$(setting_value "$repo" cargo_directories)"
    cargo_enabled="$(setting_value "$repo" cargo_enabled)"
    cargo_group_all="$(setting_value "$repo" cargo_group_all)"

    echo
    echo "DRY RUN: ${full_repo}"
    echo "  remove CompatHelper: ${REMOVE_COMPATHELPER}"
    echo "  update Dependabot: ${UPDATE_DEPENDABOT}"
    echo "  branch: ${BRANCH}"
    echo "  Julia directories: ${julia_directories}"
    echo "  GitHub Actions updates enabled: ${github_actions_enabled}"
    echo "  Julia updates enabled: ${julia_enabled}"
    echo "  grouped Julia updates: ${julia_group_all}"
    echo "  npm directories: ${npm_directories:-none}"
    echo "  npm updates enabled: ${npm_enabled}"
    if bool_is_true "$npm_enabled"; then
        echo "  grouped npm updates: ${npm_group_all}"
    fi
    echo "  Cargo directories: ${cargo_directories:-none}"
    echo "  Cargo updates enabled: ${cargo_enabled}"
    if bool_is_true "$cargo_enabled"; then
        echo "  grouped Cargo updates: ${cargo_group_all}"
    fi
}

process_repo() {
    local repo="$1"
    local short_repo
    local full_repo
    local default_branch
    local repo_dir
    local julia_directories
    local julia_group_all
    local npm_directories
    local npm_enabled
    local npm_group_all
    local cargo_directories
    local cargo_enabled
    local cargo_group_all
    local dependabot_added="false"
    local dependabot_updated="false"
    local compat_removed="false"
    local normalized_yaml="false"
    local generated_dependabot
    local title
    local body_file
    local existing_pr

    short_repo="$(repo_short_name "$repo")"
    full_repo="$(repo_full_name "$repo")"

    echo
    echo "==> Processing ${full_repo}"

    default_branch="$(gh repo view "$full_repo" --json defaultBranchRef -q '.defaultBranchRef.name')"
    repo_dir="${WORKDIR}/${short_repo}"

    gh repo clone "$full_repo" "$repo_dir"
    git -C "$repo_dir" checkout "$default_branch"
    git -C "$repo_dir" checkout -B "$BRANCH" "origin/${default_branch}"

    detect_file_state "$repo_dir"
    echo "Detected CompatHelper: ${COMPATHELPER_BEFORE}"
    echo "Detected Dependabot: ${DEPENDABOT_BEFORE}${EXISTING_DEPENDABOT_PATH:+ (${EXISTING_DEPENDABOT_PATH})}"

    if bool_is_true "$REMOVE_COMPATHELPER"; then
        if [[ -f "${repo_dir}/.github/workflows/CompatHelper.yml" ]]; then
            rm "${repo_dir}/.github/workflows/CompatHelper.yml"
            compat_removed="true"
        fi
        if [[ -f "${repo_dir}/.github/workflows/CompatHelper.yaml" ]]; then
            rm "${repo_dir}/.github/workflows/CompatHelper.yaml"
            compat_removed="true"
        fi
    fi

    if bool_is_true "$UPDATE_DEPENDABOT"; then
        mkdir -p "${repo_dir}/.github"
        generated_dependabot="${WORKDIR}/${short_repo}-dependabot.yml"
        node "$GENERATOR" --inventory "$INVENTORY_PATH" "$short_repo" > "$generated_dependabot"

        if [[ "$DEPENDABOT_BEFORE" == "missing" ]]; then
            dependabot_added="true"
        elif [[ -f "${repo_dir}/.github/dependabot.yml" ]] && ! cmp -s "$generated_dependabot" "${repo_dir}/.github/dependabot.yml"; then
            dependabot_updated="true"
        elif [[ -f "${repo_dir}/.github/dependabot.yaml" ]] && ! cmp -s "$generated_dependabot" "${repo_dir}/.github/dependabot.yaml"; then
            dependabot_updated="true"
        fi

        if [[ -f "${repo_dir}/.github/dependabot.yaml" ]]; then
            rm "${repo_dir}/.github/dependabot.yaml"
            normalized_yaml="true"
            dependabot_updated="true"
        fi
        cp "$generated_dependabot" "${repo_dir}/.github/dependabot.yml"
    fi

    if git -C "$repo_dir" diff --quiet --exit-code; then
        echo "No changes required for ${full_repo}; skipping PR."
        return
    fi

    julia_directories="$(setting_value "$short_repo" julia_directories)"
    julia_group_all="$(setting_value "$short_repo" julia_group_all)"
    npm_directories="$(setting_value "$short_repo" npm_directories)"
    npm_enabled="$(setting_value "$short_repo" npm_enabled)"
    npm_group_all="$(setting_value "$short_repo" npm_group_all)"
    cargo_directories="$(setting_value "$short_repo" cargo_directories)"
    cargo_enabled="$(setting_value "$short_repo" cargo_enabled)"
    cargo_group_all="$(setting_value "$short_repo" cargo_group_all)"
    title="$(pr_title "$compat_removed" "$dependabot_added" "$dependabot_updated")"
    body_file="${WORKDIR}/${short_repo}-pr-body.md"
    write_pr_body "$body_file" "$compat_removed" "$dependabot_added" "$dependabot_updated" "$normalized_yaml" "$julia_directories" "$julia_group_all" "$npm_directories" "$npm_enabled" "$npm_group_all" "$cargo_directories" "$cargo_enabled" "$cargo_group_all"

    git -C "$repo_dir" add .github
    git -C "$repo_dir" commit -m "$title"
    git -C "$repo_dir" remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${full_repo}.git"
    git -C "$repo_dir" push --force-with-lease origin "$BRANCH"

    existing_pr="$(gh pr list --repo "$full_repo" --head "$BRANCH" --state open --json url -q '.[0].url')"
    if [[ -n "$existing_pr" ]]; then
        echo "PR already exists: ${existing_pr}"
    else
        gh pr create \
            --repo "$full_repo" \
            --base "$default_branch" \
            --head "$BRANCH" \
            --title "$title" \
            --body-file "$body_file"
    fi
}

main() {
    local repos

    if [[ "$TARGET" == "all" ]]; then
        echo "error: TARGET=all is not supported. Use TARGET=inventory or a single repo name." >&2
        exit 2
    fi

    mapfile -t repos < <(target_repos)

    if [[ "${#repos[@]}" -eq 0 ]]; then
        echo "No target repositories found for TARGET=${TARGET}."
        exit 0
    fi

    echo "Target mode: ${TARGET}"
    echo "Repositories: ${repos[*]}"

    if bool_is_true "$DRY_RUN"; then
        for repo in "${repos[@]}"; do
            dry_run_repo "$repo"
        done
        exit 0
    fi

    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT

    for repo in "${repos[@]}"; do
        process_repo "$repo"
    done
}

main "$@"
