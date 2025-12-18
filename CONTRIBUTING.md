# Contributing

Bug reports and pull requests are welcome on [CodeBerg][📜src-cb], [GitLab][📜src-gl], or [GitHub][📜src-gh].
This project should be a safe, welcoming space for collaboration, so contributors agree to adhere to
the [code of conduct][🤝conduct].

To submit a patch, please fork the project, create a patch with tests, and send a pull request.

Remember to [![Keep A Changelog][📗keep-changelog-img]][📗keep-changelog] if you make changes.

## Help out!

Take a look at the `reek` list which is the file called `REEK` and find something to improve.

Follow these instructions:

1. Fork the repository
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Make some fixes.
4. Commit changes (`git commit -am 'Added some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Make sure to add tests for it. This is important, so it doesn't break in a future release.
7. Create new Pull Request.

## Executables vs Rake tasks

Executables shipped by dependencies, such as kettle-dev, and stone_checksums, are available
after running `bin/setup`. These include:

- gem_checksums
- kettle-changelog
- kettle-commit-msg
- kettle-dev-setup
- kettle-dvcs
- kettle-pre-release
- kettle-readme-backers
- kettle-release

There are many Rake tasks available as well. You can see them by running:

```shell
bin/rake -T
```

## Backend Compatibility Testing

TreeHaver supports multiple backends with different characteristics:

- **MRI**: ruby_tree_sitter (C extension, tree-sitter grammars)
- **FFI**: Pure Ruby FFI bindings (tree-sitter grammars)
- **Rust**: tree_stump (Rust extension, tree-sitter grammars)
- **Citrus**: Pure Ruby parser (TOML only via toml-rb grammar)

Not all backends can coexist in the same Ruby process. Notably, **FFI and MRI backends conflict**
at the libtree-sitter runtime level—using both in the same process will cause segfaults.

The **Citrus backend** works differently:
- Uses pure Ruby parsing (no .so files)
- Currently only supports TOML via toml-rb grammar
- Can coexist with tree-sitter backends
- Useful for testing multi-backend scenarios

The `bin/backend-matrix` script helps test and document backend compatibility by running tests
in isolated subprocesses.

### Basic Usage

```shell
# Test all backends with TOML grammar (default)
bin/backend-matrix

# Test specific backend order (including Citrus)
bin/backend-matrix ffi mri rust citrus

# Test Citrus with tree-sitter backends
bin/backend-matrix citrus mri ffi    # Citrus before tree-sitter
bin/backend-matrix mri citrus ffi    # Citrus between tree-sitter

# Test with a different grammar
bin/backend-matrix --grammar=json

# Test multiple grammars
bin/backend-matrix --grammars=json,toml,bash

# Citrus only supports TOML
bin/backend-matrix --grammar=toml citrus
```

### All Permutations Mode

Test all possible backend combinations by spawning fresh subprocesses for each:

```shell
# Test all 64 backend combinations (4 backends: 4 1-backend + 12 2-backend + 24 3-backend + 24 4-backend)
bin/backend-matrix --all-permutations

# With multiple grammars
bin/backend-matrix --all-permutations --grammars=json,toml

# Note: Citrus only supports TOML, so JSON/Bash tests will skip for Citrus
```

### Cross-Grammar Testing

The most interesting test: can different backends coexist if they use *different* grammar files?

```shell
# Test: FFI+json then MRI+toml, MRI+json then FFI+toml, etc.
bin/backend-matrix --cross-grammar --grammars=json,toml

# Full cross-grammar matrix
bin/backend-matrix --all-permutations --cross-grammar --grammars=json,toml
```

### Custom Source Files

Provide your own source files for parsing:

```shell
bin/backend-matrix --toml-source=my_config.toml --json-source=data.json
```

### List Available Grammars

Check which grammars are configured and available:

```shell
bin/backend-matrix --list-grammars
```

### Understanding the Output

The script produces tables showing:

1. **1-Backend Tests**: Each backend tested in isolation with all grammars
2. **2-Backend Tests**: Pairs of backends tested in sequence (A → B)
3. **3-Backend Tests**: Triples tested in sequence (A → B → C)
4. **Backend Pair Compatibility**: Data-driven analysis of which backends can coexist
5. **Statistics**: Success rates and combination counts

Example findings:

```
Backend Pair Compatibility:
╭───────────────┬────────────────────┬─────────┬────────╮
│ Backend Pair  │ Compatibility      │ Working │ Failed │
├───────────────┼────────────────────┼─────────┼────────┤
│ ffi+mri       │ ✗ Incompatible     │       0 │      8 │
│ mri+rust      │ ✓ Fully compatible │       8 │      0 │
│ ffi+rust      │ ✓ Fully compatible │       8 │      0 │
│ citrus+mri    │ ✓ Fully compatible │       2 │      0 │
│ citrus+ffi    │ ✓ Fully compatible │       2 │      0 │
│ citrus+rust   │ ✓ Fully compatible │       2 │      0 │
╰───────────────┴────────────────────┴─────────┴────────╯

Note: Citrus only supports TOML, so it has fewer total combinations.
```

### Required Environment Variables

The script requires grammar paths to be set for tree-sitter backends:

```shell
export TREE_SITTER_TOML_PATH=/path/to/libtree-sitter-toml.so
export TREE_SITTER_JSON_PATH=/path/to/libtree-sitter-json.so
export TREE_SITTER_BASH_PATH=/path/to/libtree-sitter-bash.so
```

See `.envrc` for examples of how these are typically configured.

**For Citrus backend:**
- Requires the `toml-rb` gem (pure Ruby TOML parser)
  - **Auto-installs**: Script uses bundler inline to install `toml-rb` automatically if missing
- No environment variables needed (doesn't use .so files)
- Only supports TOML grammar

## Environment Variables for Local Development

Below are the primary environment variables recognized by stone_checksums (and its integrated tools). Unless otherwise noted, set boolean values to the string "true" to enable.

General/runtime
- DEBUG: Enable extra internal logging for this library (default: false)
- REQUIRE_BENCH: Enable `require_bench` to profile requires (default: false)
- CI: When set to true, adjusts default rake tasks toward CI behavior

Coverage (kettle-soup-cover / SimpleCov)
- K_SOUP_COV_DO: Enable coverage collection (default: true in .envrc)
- K_SOUP_COV_FORMATTERS: Comma-separated list of formatters (html, xml, rcov, lcov, json, tty)
- K_SOUP_COV_MIN_LINE: Minimum line coverage threshold (integer, e.g., 100)
- K_SOUP_COV_MIN_BRANCH: Minimum branch coverage threshold (integer, e.g., 100)
- K_SOUP_COV_MIN_HARD: Fail the run if thresholds are not met (true/false)
- K_SOUP_COV_MULTI_FORMATTERS: Enable multiple formatters at once (true/false)
- K_SOUP_COV_OPEN_BIN: Path to browser opener for HTML (empty disables auto-open)
- MAX_ROWS: Limit console output rows for simplecov-console (e.g., 1)
  Tip: When running a single spec file locally, you may want `K_SOUP_COV_MIN_HARD=false` to avoid failing thresholds for a partial run.

GitHub API and CI helpers
- GITHUB_TOKEN or GH_TOKEN: Token used by `ci:act` and release workflow checks to query GitHub Actions status at higher rate limits

Releasing and signing
- SKIP_GEM_SIGNING: If set, skip gem signing during build/release
- GEM_CERT_USER: Username for selecting your public cert in `certs/<USER>.pem` (defaults to $USER)
- SOURCE_DATE_EPOCH: Reproducible build timestamp.
  - `kettle-release` will set this automatically for the session.
  - Not needed on bundler >= 2.7.0, as reproducible builds have become the default.

Git hooks and commit message helpers (exe/kettle-commit-msg)
- GIT_HOOK_BRANCH_VALIDATE: Branch name validation mode (e.g., `jira`) or `false` to disable
- GIT_HOOK_FOOTER_APPEND: Append a footer to commit messages when goalie allows (true/false)
- GIT_HOOK_FOOTER_SENTINEL: Required when footer append is enabled — a unique first-line sentinel to prevent duplicates
- GIT_HOOK_FOOTER_APPEND_DEBUG: Extra debug output in the footer template (true/false)

For a quick starting point, this repository’s `.envrc` shows sane defaults, and `.env.local` can override them locally.

## Appraisals

From time to time the [appraisal2][🚎appraisal2] gemfiles in `gemfiles/` will need to be updated.
They are created and updated with the commands:

```console
bin/rake appraisal:update
```

If you need to reset all gemfiles/*.gemfile.lock files:

```console
bin/rake appraisal:reset
```

When adding an appraisal to CI, check the [runner tool cache][🏃‍♂️runner-tool-cache] to see which runner to use.

## The Reek List

Take a look at the `reek` list which is the file called `REEK` and find something to improve.

To refresh the `reek` list:

```console
bundle exec reek > REEK
```

## Run Tests

To run all tests

```console
bundle exec rake test
```

### Spec organization (required)

- One spec file per class/module. For each class or module under `lib/`, keep all of its unit tests in a single spec file under `spec/` that mirrors the path and file name exactly: `lib/tree_haver/my_class.rb` -> `spec/tree_haver/my_class_spec.rb`.
- Exception: Integration specs that intentionally span multiple classes. Place these under `spec/integration/` (or a clearly named integration folder), and do not directly mirror a single class. Name them after the scenario, not a class.

## Lint It

Run all the default tasks, which includes running the gradually autocorrecting linter, `rubocop-gradual`.

```console
bundle exec rake
```

Or just run the linter.

```console
bundle exec rake rubocop_gradual:autocorrect
```

For more detailed information about using RuboCop in this project, please see the [RUBOCOP.md](RUBOCOP.md) guide. This project uses `rubocop_gradual` instead of vanilla RuboCop, which requires specific commands for checking violations.

### Important: Do not add inline RuboCop disables

Never add `# rubocop:disable ...` / `# rubocop:enable ...` comments to code or specs (except when following the few existing `rubocop:disable` patterns for a rule already being disabled elsewhere in the code). Instead:

- Prefer configuration-based exclusions when a rule should not apply to certain paths or files (e.g., via `.rubocop.yml`).
- When a violation is temporary, and you plan to fix it later, record it in `.rubocop_gradual.lock` using the gradual workflow:
  - `bundle exec rake rubocop_gradual:autocorrect` (preferred)
  - `bundle exec rake rubocop_gradual:force_update` (only when you cannot fix the violations immediately)

As a general rule, fix style issues rather than ignoring them. For example, our specs should follow RSpec conventions like using `described_class` for the class under test.

## Contributors

Your picture could be here!

[![Contributors][🖐contributors-img]][🖐contributors]

Made with [contributors-img][🖐contrib-rocks].

Also see GitLab Contributors: [https://gitlab.com/kettle-rb/tree_haver/-/graphs/main][🚎contributors-gl]

## For Maintainers

### One-time, Per-maintainer, Setup

**IMPORTANT**: To sign a build,
a public key for signing gems will need to be picked up by the line in the
`gemspec` defining the `spec.cert_chain` (check the relevant ENV variables there).
All releases are signed releases.
See: [RubyGems Security Guide][🔒️rubygems-security-guide]

NOTE: To build without signing the gem set `SKIP_GEM_SIGNING` to any value in the environment.

### To release a new version:

#### Automated process

1. Update version.rb to contain the correct version-to-be-released.
2. Run `bundle exec kettle-changelog`.
3. Run `bundle exec kettle-release`.
4. Stay awake and monitor the release process for any errors, and answer any prompts.

#### Manual process

1. Run `bin/setup && bin/rake` as a "test, coverage, & linting" sanity check
2. Update the version number in `version.rb`, and ensure `CHANGELOG.md` reflects changes
3. Run `bin/setup && bin/rake` again as a secondary check, and to update `Gemfile.lock`
4. Run `git commit -am "🔖 Prepare release v<VERSION>"` to commit the changes
5. Run `git push` to trigger the final CI pipeline before release, and merge PRs
    - NOTE: Remember to [check the build][🧪build].
6. Run `export GIT_TRUNK_BRANCH_NAME="$(git remote show origin | grep 'HEAD branch' | cut -d ' ' -f5)" && echo $GIT_TRUNK_BRANCH_NAME`
7. Run `git checkout $GIT_TRUNK_BRANCH_NAME`
8. Run `git pull origin $GIT_TRUNK_BRANCH_NAME` to ensure latest trunk code
9. Optional for older Bundler (< 2.7.0): Set `SOURCE_DATE_EPOCH` so `rake build` and `rake release` use the same timestamp and generate the same checksums
    - If your Bundler is >= 2.7.0, you can skip this; builds are reproducible by default.
    - Run `export SOURCE_DATE_EPOCH=$EPOCHSECONDS && echo $SOURCE_DATE_EPOCH`
    - If the echo above has no output, then it didn't work.
    - Note: `zsh/datetime` module is needed, if running `zsh`.
    - In older versions of `bash` you can use `date +%s` instead, i.e. `export SOURCE_DATE_EPOCH=$(date +%s) && echo $SOURCE_DATE_EPOCH`
10. Run `bundle exec rake build`
11. Run `bin/gem_checksums` (more context [1][🔒️rubygems-checksums-pr], [2][🔒️rubygems-guides-pr])
    to create SHA-256 and SHA-512 checksums. This functionality is provided by the `stone_checksums`
    [gem][💎stone_checksums].
    - The script automatically commits but does not push the checksums
12. Sanity check the SHA256, comparing with the output from the `bin/gem_checksums` command:
    - `sha256sum pkg/<gem name>-<version>.gem`
13. Run `bundle exec rake release` which will create a git tag for the version,
    push git commits and tags, and push the `.gem` file to the gem host configured in the gemspec.

[📜src-gl]: https://gitlab.com/kettle-rb/tree_haver/
[📜src-cb]: https://codeberg.org/kettle-rb/tree_haver
[📜src-gh]: https://github.com/kettle-rb/tree_haver
[🧪build]: https://github.com/kettle-rb/tree_haver/actions
[🤝conduct]: https://gitlab.com/kettle-rb/tree_haver/-/blob/main/CODE_OF_CONDUCT.md
[🖐contrib-rocks]: https://contrib.rocks
[🖐contributors]: https://github.com/kettle-rb/tree_haver/graphs/contributors
[🚎contributors-gl]: https://gitlab.com/kettle-rb/tree_haver/-/graphs/main
[🖐contributors-img]: https://contrib.rocks/image?repo=kettle-rb/tree_haver
[💎gem-coop]: https://gem.coop
[🔒️rubygems-security-guide]: https://guides.rubygems.org/security/#building-gems
[🔒️rubygems-checksums-pr]: https://github.com/rubygems/rubygems/pull/6022
[🔒️rubygems-guides-pr]: https://github.com/rubygems/guides/pull/325
[💎stone_checksums]: https://github.com/galtzo-floss/stone_checksums
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[🚎appraisal2]: https://github.com/appraisal-rb/appraisal2
[🏃‍♂️runner-tool-cache]: https://github.com/ruby/ruby-builder/releases/tag/toolcache
