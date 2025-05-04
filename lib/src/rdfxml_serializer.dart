/// RDF/XML Serializer Implementation
///
/// Serializes RDF graphs to the RDF/XML syntax format according to the W3C specification.
///
/// Example usage:
/// ```dart
/// final serializer = RdfXmlSerializer();
/// final rdfXml = serializer.write(graph, customPrefixes: {'ex': 'http://example.org/'});
/// ```
library rdfxml_serializer;

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';

import 'configuration.dart';
import 'exceptions.dart';
import 'implementations/serialization_impl.dart';
import 'interfaces/serialization.dart';

/// Serializer for RDF/XML format
///
/// Implements the RDF/XML serialization algorithm according to the W3C specification.
/// This serializer converts RDF triples into XML-encoded RDF data.
///
/// Features:
/// - Prefix handling for compact output
/// - Type consolidation (using element types instead of rdf:type triples)
/// - Support for RDF collections
/// - Blank node serialization
/// - Datatype and language tag handling
final class RdfXmlSerializer implements IRdfXmlSerializer {
  static final _logger = Logger('rdf.serializer.rdfxml');

  /// Namespace manager for handling namespace declarations
  final INamespaceManager _namespaceManager;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Serializer options for configuring behavior
  final RdfXmlSerializerOptions _options;

  /// Creates a new RDF/XML serializer
  ///
  /// Parameters:
  /// - [namespaceManager] Optional namespace manager for handling namespace operations
  /// - [xmlBuilder] Optional XML builder for creating XML documents
  /// - [options] Optional serializer options
  RdfXmlSerializer({
    INamespaceManager? namespaceManager,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlSerializerOptions? options,
  }) : _namespaceManager = namespaceManager ?? const DefaultNamespaceManager(),
       _xmlBuilder = xmlBuilder ?? const DefaultRdfXmlBuilder(),
       _options = options ?? const RdfXmlSerializerOptions();

  /// Writes an RDF graph to RDF/XML format
  ///
  /// Parameters:
  /// - [graph] The RDF graph to serialize
  /// - [baseUri] Optional base URI for the document
  /// - [customPrefixes] Custom namespace prefix mappings
  @override
  String write(
    RdfGraph graph, {
    String? baseUri,
    Map<String, String> customPrefixes = const {},
  }) {
    _logger.fine('Serializing graph to RDF/XML');

    try {
      // Validate graph if empty
      if (graph.isEmpty) {
        _logger.warning('Serializing empty graph to RDF/XML');
      }

      // Build namespace declarations based on options
      final namespaces =
          _options.useNamespaces
              ? _namespaceManager.buildNamespaceDeclarations(
                graph,
                customPrefixes,
              )
              : <String, String>{};

      // Build XML document
      final document = _xmlBuilder.buildDocument(graph, baseUri, namespaces);

      // Generate XML string with configured formatting options
      return document.toXmlString(
        pretty: _options.prettyPrint,
        indent: ' ' * _options.indentSpaces,
      );
    } catch (e) {
      _logger.severe('Error serializing to RDF/XML: $e');
      if (e is RdfXmlSerializationException) {
        rethrow;
      }
      throw RdfXmlSerializationException('Error serializing to RDF/XML: $e');
    }
  }
}
