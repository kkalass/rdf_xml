# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.3] - 2025-07-22

### Fixed

- **URI Relativization**: Complete rewrite of URI relativization logic in RDF/XML serialization to ensure RFC 3986 compliance
- **Roundtrip Consistency**: Fixed issue where relativized URIs could not be correctly resolved back to their original form
- **Fragment-only URI Handling**: Improved handling of URIs that differ only by fragment from the base URI
- **Empty Relative URI Generation**: Fixed generation of empty relative URIs when the target URI exactly matches the base URI

### Added

- Comprehensive RFC 3986 compliant URI relativization algorithm with proper roundtrip verification
- New test suite `uri_relativization_consistency_test.dart` for verifying URI relativization and resolution consistency
- Enhanced error handling in URI relativization with fallback to absolute URIs when safe relativization is not possible

### Improved

- **Serialization Performance**: More efficient URI relativization with optimized checks for common cases
- **URI Resolution Accuracy**: Better handling of edge cases in URI relativization including fragment-only differences and path-based relativization
- **Code Maintainability**: Extracted URI relativization logic into dedicated method with comprehensive documentation

## [0.4.2] - 2025-07-22

### Fixed

- **Base URI Resolution**: Fixed hierarchical xml:base attribute resolution to properly resolve relative xml:base values against their parent element's base URI
- **xml:base Attribute Parsing**: Fixed issue where xml:base attributes were incorrectly parsed as RDF property triples instead of being used for URI resolution only
- **RFC 3986 Compliance**: Ensured full RFC 3986 compliance for URI resolution, particularly for edge cases like base URIs ending with fragment identifiers

### Added

- Comprehensive test suite for RFC 3986 URI resolution compliance
- Integration tests for complex xml:base scenarios including nested base URI declarations
- Tests covering various URI resolution edge cases (fragments, queries, relative paths, absolute paths)

### Improved

- Enhanced URI resolution to properly handle nested xml:base attributes in RDF/XML documents
- Better separation of xml:base processing from regular RDF attribute processing
- More robust handling of relative URI resolution in complex document structures

## [0.4.1] - 2025-07-21

### Added

- New `BaseUriRequiredException` class for better error handling when base URI is missing
- Comprehensive test coverage for relative URL decoding scenarios
- Better error messages with clear instructions for fixing base URI issues
- Comprehensive test coverage for URI relativization in serialization
- New `includeBaseDeclaration` option in `RdfXmlEncoderOptions` to control xml:base attribute inclusion

### Changed

- Improved error handling for URI resolution with more specific exception types
- Enhanced error messages to include source context information
- Updated test imports to use public API instead of internal imports

### Fixed

- Better handling of relative URI resolution errors with clearer error messages
- Improved error context reporting in URI resolution failures
- Fixed URI relativization bug where IRIs equal to base URI generated "/" instead of empty string

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
