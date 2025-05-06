# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-05-06

### Added

- Comprehensive example files demonstrating basic usage, configuration options, and file handling
- Improved API documentation with more detailed explanations and usage examples
- Added robust roundtrip tests to ensure consistency between parsing and serialization

### Changed

- Updated landing page (doc/index.html) with correct code examples that match the current API
- Replaced deprecated API usage in documentation with current recommended patterns
- Regenerated API documentation to reflect the latest implementation
- Optimized namespace handling: only needed namespaces are now written in serialized output
- Improved overall code quality with various cleanups and refactorings

### Fixed

- Fixed serialization of nested BlankNodes
- Corrected literal parsing in collections
- Improved baseUri handling in the parser
- Fixed lang attribute handling when XML namespace was not properly declared
- Removed illogical serializer options that could lead to invalid output
- Various edge case fixes to improve robustness and correctness

## [0.1.1] - 2025-05-05

### Fixed

- Missing dev dependencies

## [0.1.0] - 2025-05-02

### Added

- Initial implementation of RDF/XML parser and serializer
