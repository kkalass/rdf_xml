/// Interfaces for RDF/XML serialization
///
/// This file provides interfaces for RDF/XML serialization operations,
/// enabling dependency injection and better testability.
library rdfxml.interfaces.serialization;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import '../configuration.dart';

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
    IriCompactionResult iriCompaction,
    RdfXmlEncoderOptions options,
  );
}
