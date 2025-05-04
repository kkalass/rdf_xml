/// RDF/XML Parser Implementation
///
/// Parses RDF/XML syntax into RDF triples according to the W3C RDF/XML specification.
///
/// Example usage:
/// ```dart
/// final parser = RdfXmlParser(xmlDocument, baseUri: 'http://example.org/');
/// final triples = parser.parse();
/// ```
library rdfxml_parser;

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import 'rdfxml_constants.dart';

/// Represents the XML literal datatype from the RDF Vocabulary
final _xmlLiteral = IriTerm.prevalidated(
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral',
);

/// Parser for RDF/XML format
///
/// Implements the RDF/XML parsing algorithm according to the W3C specification.
/// This parser converts XML-encoded RDF data into triples.
///
/// The parser handles:
/// - Resource descriptions with rdf:about, rdf:ID, and rdf:resource
/// - Literal properties with language tags and datatypes
/// - Container elements (rdf:Bag, rdf:Seq, rdf:Alt)
/// - Collection elements (rdf:List)
/// - Reification
/// - XML Base and namespace resolution
final class RdfXmlParser {
  static final _logger = Logger('rdf.parser.rdfxml');

  /// The RDF/XML document to parse
  final String _input;

  /// Base URI for resolving relative URIs
  final String? _baseUri;

  /// Map of blank node IDs to actual blank node terms
  final Map<String, BlankNodeTerm> _blankNodes = {};

  /// XML document parsed from input
  late final XmlDocument _document;

  /// Base URI resolved from document and constructor parameter
  late final String _resolvedBaseUri;

  /// Constant for the RDF namespace
  static const rdfNamespace = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';

  /// Creates a new RDF/XML parser
  ///
  /// Parameters:
  /// - [input] The RDF/XML document to parse as a string
  /// - [baseUri] Optional base URI for resolving relative references
  RdfXmlParser(this._input, {String? baseUri}) : _baseUri = baseUri {
    try {
      _document = XmlDocument.parse(_input);
      _resolvedBaseUri = _resolveBaseUri();
    } catch (e) {
      throw RdfParserException(
        'Failed to parse XML document: ${e.toString()}',
        format: 'application/rdf+xml',
      );
    }
  }

  /// Parses the RDF/XML document and returns a list of triples
  ///
  /// This is the main entry point for parsing RDF/XML data.
  List<Triple> parse() {
    _logger.fine('Parsing RDF/XML document');

    final triples = <Triple>[];

    try {
      // Find the root RDF element
      final rdfElement = _findRdfRootElement();

      // Process all child nodes of the RDF element
      for (final node in rdfElement.childElements) {
        _processNode(node, triples);
      }

      _logger.fine('Parsed ${triples.length} triples');
      return triples;
    } catch (e) {
      _logger.severe('Error parsing RDF/XML: $e');
      if (e is RdfParserException) {
        rethrow;
      }
      throw RdfParserException(
        'Error parsing RDF/XML: $e',
        format: 'application/rdf+xml',
      );
    }
  }

  /// Finds the root RDF element in the document
  ///
  /// According to the spec, this should be an element named rdf:RDF,
  /// but some documents omit this and start directly with RDF content.
  XmlElement _findRdfRootElement() {
    // Try to find rdf:RDF element
    final rdfElements = _document.findAllElements(
      'RDF',
      namespace: rdfNamespace,
    );

    if (rdfElements.isNotEmpty) {
      return rdfElements.first;
    }

    // If no rdf:RDF element found, use the document element if it has RDF namespace
    final rootElement = _document.rootElement;
    if (rootElement.namespaceUri == rdfNamespace) {
      return rootElement;
    }

    // Look for any element with RDF namespace declarations
    for (final element in _document.findAllElements('*')) {
      final hasRdfNs = element.attributes.any(
        (attr) =>
            attr.name.qualified == 'xmlns:rdf' && attr.value == rdfNamespace,
      );

      if (hasRdfNs) {
        return element;
      }
    }

    throw RdfParserException(
      'No RDF/XML root element found. Document should contain an rdf:RDF element or use RDF namespace.',
      format: 'application/rdf+xml',
    );
  }

  /// Processes an XML node and extracts triples
  ///
  /// This is the core parsing function that handles different node types
  /// according to the RDF/XML syntax rules.
  void _processNode(
    XmlElement element,
    List<Triple> triples, {
    RdfSubject? subject,
  }) {
    _logger.fine('Processing element: ${element.name.qualified}');

    // Check if this is an rdf:Description or a typed resource
    final isDescription =
        element.name.local == 'Description' &&
        element.name.namespaceUri == rdfNamespace;

    // Get the subject of this element
    final currentSubject = subject ?? _getSubject(element);

    // If this is a typed resource (not rdf:Description), add a type triple
    if (!isDescription && element.name.namespaceUri != rdfNamespace) {
      final typeIri = IriTerm(
        '${element.name.namespaceUri}${element.name.local}',
      );
      triples.add(Triple(currentSubject, RdfTerms.type, typeIri));
    }

    // Process all attributes that aren't rdf: or xmlns: as properties
    for (final attr in element.attributes) {
      if (attr.name.prefix != 'rdf' &&
          attr.name.prefix != 'xmlns' &&
          attr.name.prefix?.isNotEmpty == true) {
        final predicate = IriTerm(
          '${attr.name.namespaceUri}${attr.name.local}',
        );
        final object = LiteralTerm.string(attr.value);
        triples.add(Triple(currentSubject, predicate, object));
      }
    }

    // Process child elements as properties
    for (final childElement in element.childElements) {
      _processProperty(currentSubject, childElement, triples);
    }
  }

  /// Processes a property element
  ///
  /// Handles various forms of property elements, including:
  /// - Simple literals
  /// - Resource references
  /// - Nested resource descriptions
  /// - RDF containers and collections
  void _processProperty(
    RdfSubject subject,
    XmlElement propertyElement,
    List<Triple> triples,
  ) {
    final predicate = _getPredicateFromElement(propertyElement);

    // Check for rdf:resource attribute (simple resource reference)
    final resourceAttr = propertyElement.getAttribute(
      'resource',
      namespace: rdfNamespace,
    );
    if (resourceAttr != null) {
      final objectIri = _resolveUri(resourceAttr);
      triples.add(Triple(subject, predicate, IriTerm(objectIri)));
      return;
    }

    // Check for rdf:nodeID attribute (blank node reference)
    final nodeIdAttr = propertyElement.getAttribute(
      'nodeID',
      namespace: rdfNamespace,
    );
    if (nodeIdAttr != null) {
      final blankNode = _getBlankNode(nodeIdAttr);
      triples.add(Triple(subject, predicate, blankNode));
      return;
    }

    // Check for rdf:parseType attribute
    final parseTypeAttr = propertyElement.getAttribute(
      'parseType',
      namespace: rdfNamespace,
    );
    if (parseTypeAttr != null) {
      _handleParseType(
        subject,
        predicate,
        propertyElement,
        parseTypeAttr,
        triples,
      );
      return;
    }

    // Check for nested elements
    if (propertyElement.childElements.isNotEmpty) {
      // If there are child elements, this is a nested resource description
      final nestedSubject = BlankNodeTerm();
      triples.add(Triple(subject, predicate, nestedSubject));

      // Process each child element as part of the nested resource
      for (final childElement in propertyElement.childElements) {
        // For a nested resource, we pass the blank node as the new subject
        _processNode(childElement, triples, subject: nestedSubject);
      }
      return;
    }

    // Check for rdf:datatype attribute
    final datatypeAttr = propertyElement.getAttribute(
      'datatype',
      namespace: rdfNamespace,
    );

    // If we get here, this is a literal property
    final literalValue = propertyElement.innerText;

    // Check for XML language attribute (xml:lang)
    final langAttr = propertyElement.getAttribute(
      'lang',
      namespace: 'http://www.w3.org/XML/1998/namespace',
    );

    if (datatypeAttr != null) {
      // Typed literal
      final datatype = IriTerm(_resolveUri(datatypeAttr));
      triples.add(
        Triple(
          subject,
          predicate,
          LiteralTerm(literalValue, datatype: datatype),
        ),
      );
    } else if (langAttr != null) {
      // Language-tagged literal
      triples.add(
        Triple(
          subject,
          predicate,
          LiteralTerm.withLanguage(literalValue, langAttr),
        ),
      );
    } else {
      // Plain literal (string)
      triples.add(Triple(subject, predicate, LiteralTerm.string(literalValue)));
    }
  }

  /// Handles elements with rdf:parseType attribute
  ///
  /// Processes special parsing modes like:
  /// - parseType="Resource" - Treats content as a nested resource
  /// - parseType="Literal" - Treats content as an XML literal
  /// - parseType="Collection" - Treats content as an RDF collection (list)
  void _handleParseType(
    RdfSubject subject,
    RdfPredicate predicate,
    XmlElement element,
    String parseType,
    List<Triple> triples,
  ) {
    switch (parseType) {
      case 'Resource':
        // Create a blank node and treat content as a nested resource
        final nestedSubject = BlankNodeTerm();
        triples.add(Triple(subject, predicate, nestedSubject));

        // Process each child element
        for (final childElement in element.childElements) {
          _processNode(childElement, triples, subject: nestedSubject);
        }
        break;

      case 'Literal':
        // Treat content as an XML literal
        final xmlContent = element.innerXml;
        triples.add(
          Triple(
            subject,
            predicate,
            LiteralTerm(xmlContent, datatype: _xmlLiteral),
          ),
        );
        break;

      case 'Collection':
        // Treat content as an RDF collection (list)
        _processCollection(subject, predicate, element.childElements, triples);
        break;

      default:
        // Unknown parseType, treat as a resource
        _logger.warning(
          'Unknown rdf:parseType "$parseType", treating as "Resource"',
        );
        final nestedSubject = BlankNodeTerm();
        triples.add(Triple(subject, predicate, nestedSubject));

        for (final childElement in element.childElements) {
          _processNode(childElement, triples, subject: nestedSubject);
        }
    }
  }

  /// Processes an RDF collection (list)
  ///
  /// Handles parseType="Collection" by creating the RDF list structure.
  void _processCollection(
    RdfSubject subject,
    RdfPredicate predicate,
    Iterable<XmlElement> items,
    List<Triple> triples,
  ) {
    if (items.isEmpty) {
      // Empty collection, link to rdf:nil
      triples.add(Triple(subject, predicate, RdfTerms.nil));
      return;
    }

    // Start with a blank node for the first list item
    var listNode = BlankNodeTerm();

    // Link the subject to the first list node
    triples.add(Triple(subject, predicate, listNode));

    for (final item in items) {
      // Create a new blank node for the item
      final itemSubject = _getSubject(item);

      // Add the item to the list
      triples.add(Triple(listNode, RdfTerms.first, itemSubject));

      // Process the item element
      _processNode(item, triples);

      // Is this the last item?
      final isLastItem = item == items.last;

      if (isLastItem) {
        // Last item points to nil
        triples.add(Triple(listNode, RdfTerms.rest, RdfTerms.nil));
      } else {
        // Create next list node
        final nextNode = BlankNodeTerm();
        triples.add(Triple(listNode, RdfTerms.rest, nextNode));
        listNode = nextNode;
      }
    }
  }

  /// Gets a predicate IRI from a property element
  ///
  /// Extracts the predicate IRI using the element's namespace and local name.
  RdfPredicate _getPredicateFromElement(XmlElement element) {
    final namespaceUri = element.name.namespaceUri ?? '';
    final localName = element.name.local;

    return IriTerm('$namespaceUri$localName');
  }

  /// Gets or creates a blank node for a given ID
  ///
  /// Ensures that the same blank node ID always maps to the same blank node term.
  BlankNodeTerm _getBlankNode(String nodeId) {
    return _blankNodes.putIfAbsent(nodeId, () => BlankNodeTerm());
  }

  /// Resolves the base URI for the document
  ///
  /// Determines the base URI by checking for xml:base attributes and
  /// falling back to the constructor parameter if needed.
  String _resolveBaseUri() {
    // Check for xml:base attribute on the document element
    final xmlBase = _document.rootElement.getAttribute(
      'base',
      namespace: 'http://www.w3.org/XML/1998/namespace',
    );

    if (xmlBase != null) {
      return xmlBase;
    }

    // Fall back to the provided base URI
    return _baseUri ?? '';
  }

  /// Resolves a potentially relative URI against the base URI
  ///
  /// Returns an absolute URI by combining the base URI with the relative reference.
  String _resolveUri(String uri) {
    // If URI is already absolute, return it as is
    if (uri.contains(':')) {
      return uri;
    }

    // If base URI is empty, can't resolve
    if (_resolvedBaseUri.isEmpty) {
      return uri;
    }

    // Simple URI resolution - this could be improved with a more robust URL resolver
    if (uri.startsWith('#')) {
      // Fragment identifier
      final baseWithoutFragment =
          _resolvedBaseUri.contains('#')
              ? _resolvedBaseUri.substring(0, _resolvedBaseUri.indexOf('#'))
              : _resolvedBaseUri;
      return '$baseWithoutFragment$uri';
    } else if (uri.startsWith('/')) {
      // Absolute path
      final protocol =
          _resolvedBaseUri.contains('://')
              ? _resolvedBaseUri.substring(
                0,
                _resolvedBaseUri.indexOf('://') + 3,
              )
              : '';
      final authority =
          _resolvedBaseUri.contains('://')
              ? _resolvedBaseUri.substring(
                _resolvedBaseUri.indexOf('://') + 3,
                _resolvedBaseUri.indexOf(
                  '/',
                  _resolvedBaseUri.indexOf('://') + 3,
                ),
              )
              : '';
      return '$protocol$authority$uri';
    } else {
      // Relative path
      final lastSlashPos = _resolvedBaseUri.lastIndexOf('/');
      if (lastSlashPos >= 0) {
        return '${_resolvedBaseUri.substring(0, lastSlashPos + 1)}$uri';
      } else {
        return '$_resolvedBaseUri/$uri';
      }
    }
  }

  /// Gets the subject term for an element
  ///
  /// Extracts the subject IRI or blank node from element attributes
  /// according to RDF/XML rules (rdf:about, rdf:ID, or blank node).
  RdfSubject _getSubject(XmlElement element) {
    // Check for rdf:about attribute
    final aboutAttr = element.getAttribute('about', namespace: rdfNamespace);
    if (aboutAttr != null) {
      final iri = _resolveUri(aboutAttr);
      return IriTerm(iri);
    }

    // Check for rdf:ID attribute
    final idAttr = element.getAttribute('ID', namespace: rdfNamespace);
    if (idAttr != null) {
      // rdf:ID creates a URI relative to the document base URI
      final iri = '${_resolvedBaseUri}#$idAttr';
      return IriTerm(iri);
    }

    // Check for rdf:nodeID attribute
    final nodeIdAttr = element.getAttribute('nodeID', namespace: rdfNamespace);
    if (nodeIdAttr != null) {
      return _getBlankNode(nodeIdAttr);
    }

    // No identifier, create a blank node
    return BlankNodeTerm();
  }
}
