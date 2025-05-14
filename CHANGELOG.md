# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2025-05-14

### Changed

- Updated to support rdf_core 0.9.0, which comes with breaking changes

## [0.3.0] - 2025-05-13

### Changed

- Updated to support breaking changes in rdf_core 0.8.1:
  - Updated API from `parse`/`serialize` to `decode`/`encode`
  - Updated from `RdfFormat` to `RdfGraphCodec`
  - Changed from `withStandardFormats` to `withStandardCodecs`
  - Updated from `withFormats` to `withCodecs`
- Added global `rdfxml` codec instance for easier access (following dart:convert pattern)
- Simplified API in examples and documentation to use direct `rdfxml.encode()` and `rdfxml.decode()` calls
- Restructured example files to demonstrate both direct usage and RdfCore integration

## [0.2.4] - 2025-05-07

### Changed

- Use prefix generation from rdf_core instead of our own algorithm

## [0.2.3] - 2025-05-07

### Fixed

- Improved handling of objects that are also subjects in RDF/XML parsing
- Fixed parsing issue identified through new test case


## [0.2.2] - 2025-05-06

### Fixed

- added linter and fixed linter warnings


## [0.2.1] - 2025-05-06

### Changed

- rdf_core arrived at 0.7.x, make rdf_xml depend on the current minor version.

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
