/// Interfaces for RDF/XML serialization
///
/// This file provides interfaces for RDF/XML serialization operations,
/// enabling dependency injection and better testability.
library rdfxml.interfaces.serialization;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

/// Contract for RDF/XML serialization functionality
abstract interface class IRdfXmlSerializer {
  /// Serializes an RDF graph to RDF/XML format
  ///
  /// Parameters:
  /// - [graph] The RDF graph to serialize
  /// - [baseUri] Optional base URI for the document
  /// - [customPrefixes] Custom namespace prefix mappings
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes,
  });
}

/// Provides namespace management functionality
///
/// Handles extraction, resolution and management of namespaces
/// used in RDF/XML serialization.
abstract interface class INamespaceManager {
  /// Builds namespace declarations for the RDF/XML document
  ///
  /// Combines standard RDF namespaces, custom prefixes, and extracts
  /// namespaces used in the graph triples.
  Map<String, String> buildNamespaceDeclarations(
    RdfGraph graph,
    Map<String, String> customPrefixes,
  );

  /// Converts an IRI to a QName using the namespace mappings
  ///
  /// Returns a prefixed name (e.g., "dc:title") if a matching prefix is found,
  /// or null if no prefix matches.
  String? iriToQName(String iri, Map<String, String> namespaces);
}

/// Provides XML building functionality for RDF/XML serialization
///
/// Abstracts the XML building process to enable better testability
/// and separation of concerns during serialization.
abstract interface class IRdfXmlBuilder {
  /// Builds an XML document representing the serialized RDF graph
  ///
  /// Returns a complete XML document with all required namespace declarations
  /// and serialized RDF content.
  XmlDocument buildDocument(
    RdfGraph graph,
    String? baseUri,
    Map<String, String> namespaces,
  );
}
