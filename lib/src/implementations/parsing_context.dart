/// Immutable context data for RDF/XML parsing
///
/// Provides context information for the parsing process, including
/// the base URI and blank node mappings.
library rdfxml.parsing.context;

import 'package:rdf_core/rdf_core.dart';

/// Immutable context for RDF/XML parsing
///
/// Holds state that needs to be accessible throughout the parsing process.
/// This class is immutable - all operations return new instances.
final class RdfXmlParsingContext {
  /// Base URI for resolving relative URIs
  final String baseUri;

  /// Map of blank node IDs to actual blank node terms
  final Map<String, BlankNodeTerm> blankNodes;

  /// Creates a new immutable parsing context
  ///
  /// Parameters:
  /// - [baseUri] Base URI for resolving relative URIs
  /// - [blankNodes] Map of blank node IDs to actual blank node terms
  RdfXmlParsingContext({
    required this.baseUri,
    Map<String, BlankNodeTerm>? blankNodes,
  }) : blankNodes =
           blankNodes != null
               ? Map.unmodifiable(blankNodes)
               : <String, BlankNodeTerm>{};

  /// Factory constructor for creating empty context
  ///
  /// Useful for initialization without any blank nodes
  factory RdfXmlParsingContext.empty({String baseUri = ''}) {
    return RdfXmlParsingContext(
      baseUri: baseUri,
      blankNodes: <String, BlankNodeTerm>{},
    );
  }

  /// Creates a new context with the given base URI
  ///
  /// Returns a new instance with the updated base URI.
  RdfXmlParsingContext withBaseUri(String newBaseUri) {
    return RdfXmlParsingContext(
      baseUri: newBaseUri,
      blankNodes: Map.of(blankNodes),
    );
  }

  /// Creates a new context with an added blank node
  ///
  /// Returns a new instance with the updated blank nodes map.
  RdfXmlParsingContext withBlankNode(String id, BlankNodeTerm node) {
    final newBlankNodes = Map<String, BlankNodeTerm>.from(blankNodes);
    newBlankNodes[id] = node;
    return RdfXmlParsingContext(baseUri: baseUri, blankNodes: newBlankNodes);
  }

  /// Gets a blank node for the given ID
  ///
  /// If the ID is not found, creates a new blank node and returns
  /// it along with a new context containing the mapping.
  (BlankNodeTerm, RdfXmlParsingContext) getOrCreateBlankNode(String id) {
    if (blankNodes.containsKey(id)) {
      return (blankNodes[id]!, this);
    }

    final newBlankNode = BlankNodeTerm();
    final newContext = withBlankNode(id, newBlankNode);
    return (newBlankNode, newContext);
  }
}
