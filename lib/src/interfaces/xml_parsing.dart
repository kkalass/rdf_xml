/// Interfaces for XML parsing and related operations
///
/// This file provides abstractions for XML document parsing and processing,
/// enabling dependency injection and better testability of the RDF/XML parser.
///
/// These interfaces decouple the RDF/XML parser from specific implementations of:
/// - XML document parsing and processing
/// - URI resolution strategies
/// - Blank node management
/// - Stream-based processing for large documents
///
/// The use of these interfaces follows the Dependency Inversion Principle,
/// making the parser more maintainable, testable, and adaptable to different
/// environments and requirements.
library rdfxml.interfaces.xml_parsing;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart'; // Added import for XML events

/// Contract for RDF/XML parsing functionality
abstract interface class IRdfXmlParser {
  /// Parses the RDF/XML document and returns a list of triples
  ///
  /// This is the main entry point for parsing RDF/XML data.
  List<Triple> parse();

  /// Parses the RDF/XML document as a stream of triples
  ///
  /// Provides a more memory-efficient way to process large documents
  /// by yielding triples incrementally.
  Stream<Triple> parseAsStream();
}

/// Provides XML document parsing functionality
///
/// This interface abstracts XML parsing operations to enable
/// mocking and testing with different XML implementations.
abstract interface class IXmlDocumentProvider {
  /// Parses an XML string into an XmlDocument
  ///
  /// May throw exceptions for malformed XML input
  XmlDocument parseXml(String input);

  /// Parses an XML string as a stream of events
  ///
  /// Provides more memory-efficient processing for large documents
  Stream<XmlEvent> parseXmlEvents(String input);
}

/// Handles URI resolution for RDF/XML processing
///
/// Responsible for resolving relative URIs against base URIs
/// and extracting base URIs from XML documents.
abstract interface class IUriResolver {
  /// Resolves a potentially relative URI against the base URI
  ///
  /// Returns an absolute URI by combining the base URI with the relative reference.
  String resolveUri(String uri, String baseUri);

  /// Resolves the base URI for a document
  ///
  /// Determines the base URI by checking for xml:base attributes and
  /// falling back to the provided parameter if needed.
  String resolveBaseUri(XmlDocument document, String? providedBaseUri);
}

/// Manages blank node creation and retrieval
///
/// Provides a consistent way to generate and retrieve blank nodes
/// by their identifiers during parsing.
abstract interface class IBlankNodeManager {
  /// Gets or creates a blank node for a given ID
  ///
  /// Ensures that the same blank node ID always maps to the same blank node term.
  BlankNodeTerm getBlankNode(String nodeId);
}
