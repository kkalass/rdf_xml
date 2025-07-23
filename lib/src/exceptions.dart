/// Exception classes for RDF/XML processing
///
/// Provides specialized exception classes for different error scenarios
/// in RDF/XML decoding and encoding.
library rdfxml.exceptions;

import 'package:rdf_core/rdf_core.dart';

/// Base class for RDF/XML-specific exceptions
///
/// Extends RdfDecoderException with additional context specific
/// to RDF/XML processing errors.
sealed class RdfXmlDecoderException extends RdfDecoderException {
  /// Creates a new RDF/XML exception
  ///
  /// Parameters:
  /// - [message] Detailed error message
  /// - [sourceContext] Optional source context where the error occurred
  const RdfXmlDecoderException(super.message, {this.sourceContext})
    : super(format: 'application/rdf+xml');

  /// Source context where the error occurred
  ///
  /// Could be an element name, document section, etc.
  final String? sourceContext;

  @override
  String toString() {
    if (sourceContext != null) {
      return 'RDF/XML Error in $sourceContext: $message';
    }
    return 'RDF/XML Error: $message';
  }
}

/// Exception for XML parsing errors
///
/// Thrown when the input document is not valid XML.
final class XmlParseException extends RdfXmlDecoderException {
  /// Creates a new XML parse exception
  ///
  /// Parameters:
  /// - [message] Detailed error message
  /// - [line] Optional line number where the error occurred
  /// - [column] Optional column number where the error occurred
  /// - [sourceContext] Optional source context where the error occurred
  const XmlParseException(
    super.message, {
    this.line,
    this.column,
    super.sourceContext,
  });

  /// Line number where the error occurred
  final int? line;

  /// Column number where the error occurred
  final int? column;

  @override
  String toString() {
    final location =
        line != null
            ? ' at line $line${column != null ? ', column $column' : ''}'
            : '';
    if (sourceContext != null) {
      return 'XML Parse Error in $sourceContext$location: $message';
    }
    return 'XML Parse Error$location: $message';
  }
}

/// Exception for RDF structure errors
///
/// Thrown when the document is valid XML but has invalid RDF structure.
final class RdfStructureException extends RdfXmlDecoderException {
  /// Creates a new RDF structure exception
  ///
  /// Parameters:
  /// - [message] Detailed error message
  /// - [elementName] Optional name of the problematic element
  /// - [sourceContext] Optional source context where the error occurred
  /// - [cause] Optional underlying exception that caused this error
  const RdfStructureException(
    super.message, {
    this.elementName,
    super.sourceContext,
    this.cause,
  });

  /// Name of the problematic element
  final String? elementName;

  /// The underlying exception that caused this error
  final Object? cause;

  @override
  String toString() {
    final element = elementName != null ? ' in element <$elementName>' : '';
    final causeInfo = cause != null ? ' (Caused by: ${cause.toString()})' : '';

    if (sourceContext != null) {
      return 'RDF Structure Error in $sourceContext$element: $message$causeInfo';
    }
    return 'RDF Structure Error$element: $message$causeInfo';
  }
}

/// Exception for URI resolution errors
///
/// Thrown when a URI cannot be resolved properly.
final class UriResolutionException extends RdfXmlDecoderException {
  /// Creates a new URI resolution exception
  ///
  /// Parameters:
  /// - [message] Detailed error message
  /// - [uri] The URI that could not be resolved
  /// - [baseUri] The base URI used for resolution
  /// - [sourceContext] Optional source context where the error occurred
  const UriResolutionException(
    super.message, {
    required this.uri,
    required this.baseUri,
    super.sourceContext,
  });

  /// The URI that could not be resolved
  final String uri;

  /// The base URI used for resolution
  final String baseUri;

  @override
  String toString() {
    return 'URI Resolution Error: Cannot resolve "$uri" against base "$baseUri"${sourceContext != null ? ' in $sourceContext' : ''}: $message';
  }
}

/// Exception for cases where a base URI is required but not available
///
/// Thrown when attempting to resolve relative URIs without a base URI.
/// This happens when the RDF/XML document has no xml:base attribute
/// and no documentUrl was provided to the parser.
final class RdfXmlBaseUriRequiredException extends RdfXmlDecoderException {
  /// Creates a new base URI required exception
  ///
  /// Parameters:
  /// - [relativeUri] The relative URI that could not be resolved
  /// - [sourceContext] Optional source context where the error occurred
  const RdfXmlBaseUriRequiredException({
    required this.relativeUri,
    super.sourceContext,
  }) : super("""\n
Cannot resolve relative URI '$relativeUri' because no base URI is available. 
This can happen when: 

(1) The RDF/XML document has no xml:base attribute, and 
(2) No documentUrl was provided to the parser. 

To fix this, either add an xml:base attribute to your RDF/XML document or 
provide a documentUrl parameter when calling the decoder: 

rdfxml.decode(xmlString, documentUrl: 'https://example.org/base/')

Tip: To encode documents like this (with relative URIs but without xml:base declaration), 
use the includeBaseDeclaration option and provide a baseUri parameter:

RdfXmlCodec(encoderOptions: RdfXmlEncoderOptions(includeBaseDeclaration: false))
  .encode(graph, baseUri: 'https://example.org/base/')

""");

  /// The relative URI that could not be resolved
  final String relativeUri;
}

/// Exception for encoding errors
///
/// Thrown when an RDF graph cannot be encoded to RDF/XML.
final class RdfXmlEncoderException extends RdfEncoderException {
  /// Creates a new encoding exception
  ///
  /// Parameters:
  /// - [message] Detailed error message
  /// - [subjectContext] Optional subject context where the error occurred
  const RdfXmlEncoderException(
    super.message, {
    this.subjectContext,
    super.cause,
  }) : super(format: 'application/rdf+xml');

  /// Subject context where the error occurred
  final String? subjectContext;

  @override
  String toString() {
    if (subjectContext != null) {
      return 'RDF/XML Encoding Error for subject $subjectContext: $message';
    }
    return 'RDF/XML Encoding Error: $message';
  }
}
