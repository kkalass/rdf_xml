/// Default implementations of XML parsing interfaces
///
/// Provides concrete implementations of the XML parsing interfaces
/// defined in the interfaces directory.
library rdfxml.parsing.implementations;

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_core/rdf_core_extend.dart';
import 'package:xml/xml.dart';

import '../exceptions.dart';
import '../interfaces/xml_parsing.dart';
import 'parsing_context.dart';

/// Default implementation of IXmlDocumentProvider
///
/// Uses the xml package to parse XML documents.
final class DefaultXmlDocumentProvider implements IXmlDocumentProvider {
  /// Creates a new DefaultXmlDocumentProvider
  const DefaultXmlDocumentProvider();

  @override
  XmlDocument parseXml(String input) => XmlDocument.parse(input);
}

/// Default implementation of IUriResolver
///
/// Provides URI resolution functionality for RDF/XML processing.
/// Uses efficient caching for improved performance with large documents.
final class DefaultUriResolver implements IUriResolver {
  /// Creates a new DefaultUriResolver
  const DefaultUriResolver();

  @override
  String resolveUri(String uri, String? baseUri) {
    try {
      return resolveIri(uri, baseUri);
    } on BaseIriRequiredException catch (e) {
      throw RdfXmlBaseUriRequiredException(relativeUri: e.relativeUri);
    }
  }
}

/// Functional implementation of IBlankNodeManager
///
/// Provides a functional approach to blank node management using immutable context.
final class FunctionalBlankNodeManager implements IBlankNodeManager {
  /// The current parsing context
  var _context = RdfXmlParsingContext.empty();

  /// Creates a new functional blank node manager
  FunctionalBlankNodeManager();

  /// Gets or creates a blank node for a given ID
  ///
  /// Ensures that the same blank node ID always maps to the same blank node term.
  /// Uses an immutable context to manage state.
  @override
  BlankNodeTerm getBlankNode(String nodeId) {
    final result = _context.getOrCreateBlankNode(nodeId);
    _context = result.$2; // Update the context with potential new blank node
    return result.$1; // Return the blank node
  }
}
