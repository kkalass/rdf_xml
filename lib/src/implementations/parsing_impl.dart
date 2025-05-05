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
/// Uses efficient caching for improved performance with large documents.
final class DefaultUriResolver implements IUriResolver {
  /// Creates a new DefaultUriResolver
  const DefaultUriResolver();

  // FIXME: memleak?
  /// Cache for document base URIs
  static final Map<XmlDocument, String> _baseUriCache = {};

  @override
  String resolveBaseUri(XmlDocument document, String? providedBaseUri) {
    // Check cache first for better performance
    if (_baseUriCache.containsKey(document)) {
      return _baseUriCache[document]!;
    }

    // Check for xml:base attribute on the document element
    final xmlBase = document.rootElement.getAttribute(
      'base',
      namespace: 'http://www.w3.org/XML/1998/namespace',
    );

    // FIXME: do we have a test for this?
    // According to W3C specs, xml:base takes precedence over provided base URI
    final result = xmlBase ?? providedBaseUri ?? '';

    // Cache the result for future lookups
    _baseUriCache[document] = result;
    return result;
  }

  @override
  String resolveUri(String uri, String baseUri) {
    // FIXME: why don't we use nullable baseUri
    // FIXME: is it really the expected behavior to expect the baseUri to
    // FIXME: be provided? Wouldn't it be better to use the default base URI from the resolveBaseUri?
    // Handle empty base URI cases
    if (baseUri.isEmpty) {
      return uri;
    }

    // Return absolute URIs immediately
    if (_isAbsoluteUri(uri)) {
      return uri;
    }

    // Handle standard cases using Uri class when possible for robustness
    try {
      // For relative URIs, use the Dart URI resolution
      final base = Uri.parse(baseUri);
      final resolved = base.resolveUri(Uri.parse(uri));
      return resolved.toString();
    } catch (e) {
      // Fall back to manual resolution if URI parsing fails
      return _manualResolveUri(uri, baseUri);
    }
  }

  /// Determines if a URI is absolute (has a scheme)
  bool _isAbsoluteUri(String uri) {
    // Check for URI scheme (e.g., http:, https:, file:)
    // More efficient than regex for this simple case
    final colonPos = uri.indexOf(':');
    if (colonPos <= 0) return false;

    // Check that characters before colon are valid scheme characters
    for (int i = 0; i < colonPos; i++) {
      final char = uri.codeUnitAt(i);
      // Valid scheme chars are a-z, A-Z, 0-9, +, -, .
      final isValidSchemeChar =
          (char >= 97 && char <= 122) || // a-z
          (char >= 65 && char <= 90) || // A-Z
          (char >= 48 && char <= 57) || // 0-9
          char == 43 || // +
          char == 45 || // -
          char == 46; // .

      if (!isValidSchemeChar) return false;
    }

    return true;
  }

  /// Manual URI resolution logic for cases where Uri.resolveUri fails
  String _manualResolveUri(String uri, String baseUri) {
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
      final schemeEnd = baseUri.indexOf('://');
      if (schemeEnd >= 0) {
        final pathStart = baseUri.indexOf('/', schemeEnd + 3);
        if (pathStart >= 0) {
          return '${baseUri.substring(0, pathStart)}$uri';
        }
      }
      // If we can't parse the base URI properly, concat with care
      return baseUri.endsWith('/')
          ? '${baseUri.substring(0, baseUri.length - 1)}$uri'
          : '$baseUri$uri';
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
  // FIXME: is it clear and documented that this is mutable and not thread-safe? Additionally, it is only legal for one document.
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
