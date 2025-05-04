/// Interfaces for XML parsing and related operations
///
/// This file provides interfaces for XML document parsing and processing,
/// enabling dependency injection and better testability.
library rdfxml.interfaces.xml_parsing;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

/// Contract for RDF/XML parsing functionality
abstract interface class IRdfXmlParser {
  /// Parses the RDF/XML document and returns a list of triples
  ///
  /// This is the main entry point for parsing RDF/XML data.
  List<Triple> parse();
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
