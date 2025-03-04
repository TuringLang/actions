# GitHub actions for TuringLang

This repository contains a collection of GitHub actions to be used across different TuringLang repositories.

----------

## DocsDocumenter

This action performs a complete build and deploy of Documenter.jl documentation, inserting the above navbar in the process.

**Note**: _Unless_ the `deploy` setting is explicitly set to `false`, this action takes care of calling `deploydocs()`, so your `docs/make.jl` file does not need to contain a call to `deploydocs()`.

If your `docs/make.jl` file contains a call to `deploydocs()`, it is not a big deal, it just means that the docs will be deployed twice in quick succession.

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `doc-path` | Path to the documentation root | `docs` (following Documenter.jl conventions) |
| `doc-make-path` | Path to the `make.jl` file | `docs/make.jl` (following Documenter.jl conventions) |
| `doc-build-path` | Path to the built HTML documentation | `docs/build` (following Documenter.jl conventions) |
| `dirname` | Subdirectory in gh-pages where the documentation should be deployed | `""` |
| `julia-version` | Julia version to use | `'1'` |
| `exclude-paths` | JSON array of filepath patterns to exclude from navbar insertion | `"[]"` |
| `deploy` | Whether to deploy to the `gh-pages` branch or not | `true` |

### Example usage

See `example_workflows/Docs.yml` for an example workflow.

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

See `example_workflows/DocsNav.yml` for an example workflow.

----------------

## Format

Run JuliaFormatter on the content in the repository.

### Example usage

```yaml
name: Format

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

concurrency:
  # Skip intermediate builds: always.
  # Cancel intermediate builds: only if it is a pull request build.
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ startsWith(github.ref, 'refs/pull/') }}

jobs:
  format:
    runs-on: ubuntu-latest

    steps:
      - name: Format code
        uses: TuringLang/actions/Format@v2
```

### Parameters

| Parameter | Description | Default |
| --- | --- | --- |
| `suggest-changes` | Whether to comment on PRs with suggested changes | `"true"` |
