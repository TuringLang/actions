# GitHub actions for TuringLang

This repository contains a collection of GitHub actions to be used across different TuringLang repositories.

Namely, these are:

- [DocsDocumenter](#docsdocumenter)
- [DocsNav](#docsnav)
- [Format](#format)
- [PRAssign](#prassign)

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
| `doc-make-path`        | Path to the `make.jl` file                                                                                     | `docs/make.jl` (following Documenter.jl conventions) |
| `doc-build-path`       | Path to the built HTML documentation                                                                           | `docs/build` (following Documenter.jl conventions)   |
| `dirname`              | Subdirectory in gh-pages where the documentation should be deployed                                            | `""`                                                 |
| `julia-version`        | Julia version to use                                                                                           | `'1'`                                                |
| `exclude-paths`        | JSON array of filepath patterns to exclude from navbar insertion                                               | `"[]"`                                               |
| `deploy`               | Whether to deploy to the `gh-pages` branch or not                                                              | `true`                                               |

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

Run JuliaFormatter on the content in the repository.

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `suggest-changes` | Whether to comment on PRs with suggested changes | `"true"` |

### Example usage

See [`example_workflows/Format.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/Format.yml) for an example workflow.

## PRAssign

Automatically add PR authors as an assignee.

### Parameters

None.

### Example usage

See [`example_workflows/PRAssign.yml`](https://github.com/TuringLang/actions/blob/main/example_workflows/PRAssign.yml) for an example workflow.
