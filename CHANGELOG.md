# Changelog

All notable changes to this project are recorded here. Changelog has been added with version 0.1.4. The format is similar to the [Keep a Changelog]((https://keepachangelog.com/en/1.0.0/)) convention.

## [0.1.16] - 2025-11-28

### Changed

- Updated README

## [0.1.15] - 2025-11-28

### Added

- Introduced initial changelog file.
- `continue_on_error` option with the default set to `true`
- `fix` option was introduced with the default set to `false`

### Changed

- stdout was re-designed, into 3 sections: Parsed Arguments, Warning / Errors, Summary

### Removed

- License Identifier were compared against the [SPDX License List](https://spdx.org/licenses/), this was removed due to the frequent updates, what meant new versions had of spdx_checker had to be made just to add new licenses.

## [0.1.14]

### Changed

- Uses the Python limited ABI now and supports python >=3.11.

## [0.1.13]

### Fixed

- Removed setuptools from runtime dependencies and added it to the project's build requirements (build-system).

## [0.1.12]

### Added

- Added IDE autocomplete support, docstrings and type hints