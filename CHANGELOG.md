# CHANGELOG

All notable changes to this project are recorded here. Changelog has been added with version 0.1.4. The format is similar to the [Keep a Changelog]((https://keepachangelog.com/en/1.0.0/)) convention.


## [0.1.12] - 2025-11-28


### Added

- Introduced initial changelog file.
- `continue_on_error` option with the default set to `true`
- `fix` option was introduced with the default set to `false`

### Changed

- stdout was re-designed, into 3 sections: Parsed Arguments, Warning / Errors, Summary

### Removed

- License Identifier were compared against the [SPDX License List](https://spdx.org/licenses/), this was removed due to the frequent updates, what meant new versions had of spdx_checker had to be made just to add new licenses.  