# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-01-27

### Added

- Dry run mode (`DRY_RUN=true`) to preview commands without executing them
- Test name announcements at start of each test
- 💻 emoji prefix for Just informational messages
- Dry run documentation in README

### Changed

- Simplified all Just scripts, reducing code size by ~50%
- Refactored commands to use variables, eliminating parameter duplication
- Made error messages more concise and actionable
- Improved test output readability

### Removed

- Banner separators, color variables, and verbose comments
- `run_cmd()` wrapper functions and output filters
- Time duration annotations from sleep messages

## [1.1.0] - 2025-11-24

### Added

- Special test for single polarization scenarios
- Debug mode for enhanced troubleshooting

### Changed

- Updated test execution order in justfile to run single-polarization before polarization-switch-for-a-track
- Reorganized top-level 'all' target to call dist-s1::all for better organization
- Updated README with new test information

### Fixed

- Better debug messages when no products are found

### Removed

- Integration helper files (INTEGRATION.md and integrate.sh) no longer needed

## [1.0.0] - 2025-11-03

### Added

- Initial release of OPERA DIST-S1 Test Automation framework
- End-to-end testing for DIST-S1 product generation and delivery pipeline
- Modular `just` command runner architecture
- Support for parameterized testing with custom tiles and timestamps
- Prerequisites workflow for test parameter discovery
- Automated validation with product count verification
- Environment variable configuration for security
- Comprehensive documentation and GitHub templates
- SLIM best practices compliance

### Security

- Replaced hardcoded internal JPL URLs with configurable environment variables
- Added environment variable validation and error handling
- Created .env.example template for secure configuration
- Added .gitignore to prevent credential exposure