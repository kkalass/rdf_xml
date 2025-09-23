# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.4.6] - 2025-09-23

### Changed

- **Dependencies**: Updated rdf_core dependency from ^0.9.14 to ^0.9.15 for improved IRI term factory support

### Added

- **IRI Term Factory Support**: Added configurable `IriTermFactory` parameter to `RdfXmlCodec`, `RdfXmlDecoder`, and `RdfXmlParser` constructors for custom IRI term creation
- **Factory Methods**: Updated all factory methods (`strict()`, `lenient()`, `readable()`, `compact()`) to accept optional `iriTermFactory` parameter

### Improved

- **Performance**: Updated IRI term creation to use const constructors where possible for better performance
- **API Consistency**: Updated internal usage from `IriTerm.iri` to `IriTerm.value` to match rdf_core API changes
- **Code Examples**: Updated all example files to use const constructors for IRI terms

## [0.4.5] - 2025-08-01

### Fixed

- **URI Relativization**: Correctly passing on iri relativization settings now
- **URI Relativization Tests**: Tests do not expect absolute relative paths (like `/other`), use the appropriate setting to change back from new behaviour to old default

## [0.4.4] - 2025-07-29

### Changed

- **Dependencies**: Updated rdf_core dependency from ^0.9.11 to ^0.9.12 for improved encoder options and IRI relativization features

### Improved

- **Encoder Options**: Enhanced `RdfXmlEncoderOptions` to properly inherit from `RdfGraphEncoderOptions` using super parameters for better compatibility and consistency
- **IRI Relativization**: Added support for configurable IRI relativization options through the new `iriRelativization` parameter

### Fixed

- **URI Relativization Tests**: Corrected test expectations to match proper RFC 3986 compliant URI relativization behavior

## [0.4.3] - 2025-07-24

### Changed

- **Dependencies**: Updated rdf_core dependency from ^0.9.9 to ^0.9.11 to avoid potential issues during serialization and improve compatibility

## [0.4.2] - 2025-07-23

### Breaking Changes

- **Namespace Management**: Replaced `INamespaceManager` interface and `DefaultNamespaceManager` with rdf_core's standardized IRI compaction system for better consistency across RDF libraries
- **Dependency**: Updated rdf_core dependency from 0.9.7 to 0.9.9

### Fixed

- **xml:base Attribute Handling**: Fixed hierarchical xml:base resolution where relative xml:base values are now properly resolved against their parent element's base URI
- **xml:base Parsing**: Fixed issue where xml:base attributes were incorrectly parsed as RDF property triples instead of being used solely for URI resolution
- **URI Resolution**: Improved RFC 3986 compliance for URI resolution, particularly edge cases involving base URIs with fragment identifiers
- **URI Relativization**: Fixed roundtrip consistency issues where relativized URIs could not be correctly resolved back to their original form
- **Fragment URI Handling**: Better handling of URIs that differ only by fragment from the base URI
- **Error Handling**: Enhanced `RdfXmlEncoderException` with `cause` parameter for better error tracking

### Improved

- **IRI Compaction**: More sophisticated IRI compaction with role-based settings for predicates, types, subjects, and objects
- **XML Serialization**: Better QName generation with proper validation for XML local names
- **Serialization Performance**: More efficient URI relativization with optimized checks for common cases
- **URI Resolution**: Enhanced handling of nested xml:base attributes in complex RDF/XML documents

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
