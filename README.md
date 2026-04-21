# GitHub actions for TuringLang

This repository contains a collection of GitHub actions to be used across different TuringLang repositories.

Namely, these are:

- [DocsDocumenter](#docsdocumenter)
- [DocsNav](#docsnav)
- [Format](#format)
- [PRAssign](#prassign)
- [SyncPRSummary](#syncprsummary)

----------

## DocsDocumenter

This action performs a complete build and deploy of Documenter.jl documentation, inserting a navbar in the process.

**Note**: _Unless_ the `deploy` setting is explicitly set to `false`, this action takes care of calling `deploydocs()`, so your `docs/make.jl` file does not need to contain a call to `deploydocs()`.

If your `docs/make.jl` file contains a call to `deploydocs()`, it is not a big deal, it just means that the docs will be deployed twice in quick succession.

### Parameters

| Parameter              | Description                                                                                                    | Default                                              |
| ---------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `pkg_path`             | Path to the package root. If empty, defaults to the current working directory.                                 | `""`                                                 |
| `additional_pkg_paths` | Additional package paths to be dev-ed alongside the main package (one path per line). For multi-package repos. | `""`                                                 |
| `doc-path`             | Path to the documentation root                                                                                 | `docs` (following Documenter.jl conventions)         |
| `add-navbar`           | Whether to include the TuringLang navbar                                                                       | `true`                                               |
| `doc-make-path`        | Path to the `make.jl` file                                                                                     | `docs/make.jl` (following Documenter.jl conventions) |
| `doc-build-path`       | Path to the built HTML documentation                                                                           | `docs/build` (following Documenter.jl conventions)   |
| `dirname`              | Subdirectory in gh-pages where the documentation should be deployed                                            | `""`                                                 |
| `tag_prefix`           | Prefix for the git tag used for versioning, useful for monorepo packages                                       | `""`                                                 |
| `navbar-url`           | URL or local path of the navbar HTML to insert                                                                 | `""`                                                 |
| `julia-version`        | Julia version to use                                                                                           | `'1'`                                                |
| `exclude-paths`        | JSON array of filepath patterns to exclude from navbar insertion                                               | `"[]"`                                               |
| `deploy`               | Whether to deploy to the `gh-pages` branch or not                                                              | `true`                                               |
| `post-preview-comment` | Whether to post the sticky pull request preview comment after deployment                                       | `true`                                               |

### Outputs

| Output | Description |
| --- | --- |
| `preview_url` | Preview URL for pull request docs previews |
| `preview_comment_body` | Comment body used for the pull request docs preview |

### Example usage

See [`example_workflows/Docs.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/Docs.yml) for an example workflow.

----------------

## DocsNav

This action inserts a MultiDocumenter-style top navigation bar to `Documenter.jl` generated sites.

`TuringNavbar.html` in `DocsNav/scripts` directory contains code for building navigation bar for Turing language satellite packages' documentation but you can use your own navigation bar for your project!

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `doc-path` | Path to the built HTML documentation | None, **must be provided** |
| `navbar-url` | Path to, or URL of, the navbar HTML to be inserted | `DocsNav/scripts/TuringNavbar.html` in this repository |
| `exclude-paths` | JSON array of filepath patterns to exclude from navbar insertion | `"[]"` |
| `julia-version` | Julia version to use | `'1'` |

### Example usage

In TuringLang, we make this action run once every week so that if the navbar HTML file is updated, all our documentation will use it.
We also have a `workflow_dispatch` trigger so that we can manually run this action whenever we want.

See [`example_workflows/DocsNav.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/DocsNav.yml) for an example workflow.

----------------

## Format

Run a Julia code formatter on the content in the repository. Supports [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl) and [Runic.jl](https://github.com/fredrikekre/Runic.jl).

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `formatter` | Formatter to use: `juliaformatter` or `runic` | `"juliaformatter"` |
| `version` | Version of the formatter | `"1"` |
| `paths` | Comma-separated list of paths to format (JuliaFormatter only) | `"."` |
| `suggest-changes` | Whether to comment on PRs with suggested changes | `"false"` |

### Example usage

See [`example_workflows/Format.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/Format.yml) for an example workflow.

## PRAssign

Automatically add PR authors as an assignee.

### Parameters

None.

### Example usage

See [`example_workflows/PRAssign.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/PRAssign.yml) for an example workflow.

## Search

Build a combined Quarto search index that includes entries both from the main TuringLang docs site, as well as the docs of individual packages.

### Parameters

None.

### Example usage

This action is only meant for two repos: `TuringLang/docs` and `TuringLang/turinglang.github.io`.
Please see the publish workflow files in those repos for example usage.

Note that this action assumes that Julia has been installed in an earlier step of the workflow.

----------------

## SyncPRSummary

Maintains a single managed block in the PR body that consolidates CI outputs — currently **Documentation Preview** and **Performance** sections. Each section is populated from an explicit input, or falls back to scanning existing bot comments for a matching marker, or shows a "pending" placeholder while CI is still running.

Works in combination with `DocsDocumenter` (set `post-preview-comment: 'false'` and pass its `preview_url` output as `docs-content`) and any benchmarking step that writes results to a file (pass the file content as `perf-content`).

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `docs-content` | Documentation preview content to inject into the PR summary | `""` |
| `perf-content` | Performance summary content to inject into the PR summary | `""` |

Both inputs are optional. Any section whose input is empty falls back to the latest matching bot comment already on the PR, then to a "Pending" placeholder.

### Example usage

```yaml
- name: Build and deploy docs
  id: docsdocumenter
  uses: TuringLang/actions/DocsDocumenter@main
  with:
    julia-version: '1.11'
    post-preview-comment: 'false'   # let SyncPRSummary handle the PR body instead

- name: Sync PR summary
  if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository
  uses: TuringLang/actions/SyncPRSummary@main
  with:
    docs-content: |
      MyPackage.jl docs for PR #${{ github.event.pull_request.number }}:
      ${{ steps.docsdocumenter.outputs.preview_url }}
```

For a benchmarking workflow that also updates the Performance section:

```yaml
- name: Sync PR summary
  uses: TuringLang/actions/SyncPRSummary@main
  with:
    perf-content: |
      ```
      ${{ steps.read-results.outputs.table }}
      ```
```
