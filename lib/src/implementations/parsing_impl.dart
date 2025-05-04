/// Default implementations of XML parsing interfaces
///
/// Provides concrete implementations of the XML parsing interfaces
/// defined in the interfaces directory.
library rdfxml.parsing.implementations;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

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
final class DefaultUriResolver implements IUriResolver {
  /// Creates a new DefaultUriResolver
  const DefaultUriResolver();

  @override
  String resolveBaseUri(XmlDocument document, String? providedBaseUri) {
    // Check for xml:base attribute on the document element
    final xmlBase = document.rootElement.getAttribute(
      'base',
      namespace: 'http://www.w3.org/XML/1998/namespace',
    );

    if (xmlBase != null) {
      return xmlBase;
    }

    // Fall back to the provided base URI
    return providedBaseUri ?? '';
  }

  @override
  String resolveUri(String uri, String baseUri) {
    // If URI is already absolute, return it as is
    if (uri.contains(':')) {
      return uri;
    }

    // If base URI is empty, can't resolve
    if (baseUri.isEmpty) {
      return uri;
    }

    // Fragment identifier
    if (uri.startsWith('#')) {
      final baseWithoutFragment =
          baseUri.contains('#')
              ? baseUri.substring(0, baseUri.indexOf('#'))
              : baseUri;
      return '$baseWithoutFragment$uri';
    }

    // Absolute path
    if (uri.startsWith('/')) {
      final protocol =
          baseUri.contains('://')
              ? baseUri.substring(0, baseUri.indexOf('://') + 3)
              : '';
      final authority =
          baseUri.contains('://')
              ? baseUri.substring(
                baseUri.indexOf('://') + 3,
                baseUri.indexOf('/', baseUri.indexOf('://') + 3),
              )
              : '';
      return '$protocol$authority$uri';
    }

    // Relative path
    final lastSlashPos = baseUri.lastIndexOf('/');
    if (lastSlashPos >= 0) {
      return '${baseUri.substring(0, lastSlashPos + 1)}$uri';
    } else {
      return '$baseUri/$uri';
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
