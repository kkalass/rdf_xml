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

import 'configuration.dart';
import 'exceptions.dart';
import 'implementations/parsing_impl.dart';
import 'interfaces/xml_parsing.dart';
import 'rdfxml_constants.dart';

/// Parser for RDF/XML format
///
/// Implements the RDF/XML parsing algorithm according to the W3C specification.
/// This parser converts XML-encoded RDF data into triples.
///
/// Features:
/// - Resource descriptions with rdf:about, rdf:ID, and rdf:resource
/// - Literal properties with language tags and datatypes
/// - Container elements (rdf:Bag, rdf:Seq, rdf:Alt)
/// - Collection elements (rdf:List)
/// - Reification
/// - XML Base and namespace resolution
final class RdfXmlParser implements IRdfXmlParser {
  static final _logger = Logger('rdf.parser.rdfxml');

  /// The RDF/XML document to parse
  final String _input;

  /// Base URI for resolving relative URIs
  final String? _baseUri;

  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Blank node manager for handling blank nodes
  final FunctionalBlankNodeManager _blankNodeManager;

  /// Parser options for configuring behavior
  final RdfXmlParserOptions _options;

  /// XML document parsed from input
  late final XmlDocument _document;

  /// Base URI resolved from document and constructor parameter
  late final String _resolvedBaseUri;

  /// Current parsing depth for nested elements
  int _currentDepth = 0;

  /// Creates a new RDF/XML parser
  ///
  /// Parameters:
  /// - [input] The RDF/XML document to parse as a string
  /// - [baseUri] Optional base URI for resolving relative references
  /// - [xmlDocumentProvider] Optional XML document provider
  /// - [uriResolver] Optional URI resolver
  /// - [blankNodeManager] Optional blank node manager
  /// - [options] Optional parser options
  RdfXmlParser(
    this._input, {
    String? baseUri,
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    FunctionalBlankNodeManager? blankNodeManager,
    RdfXmlParserOptions? options,
  }) : _baseUri = baseUri,
       _xmlDocumentProvider =
           xmlDocumentProvider ?? const DefaultXmlDocumentProvider(),
       _uriResolver = uriResolver ?? const DefaultUriResolver(),
       _blankNodeManager = blankNodeManager ?? FunctionalBlankNodeManager(),
       _options = options ?? const RdfXmlParserOptions() {
    try {
      _document = _xmlDocumentProvider.parseXml(_input);
      _resolvedBaseUri = _uriResolver.resolveBaseUri(_document, _baseUri);
    } catch (e) {
      if (e is XmlParseException) rethrow;
      throw XmlParseException('Failed to parse XML document: ${e.toString()}');
    }
  }

  /// Parses the RDF/XML document and returns a list of triples
  ///
  /// This is the main entry point for parsing RDF/XML data.
  @override
  List<Triple> parse() {
    _logger.fine('Parsing RDF/XML document');

    final triples = <Triple>[];
    _currentDepth = 0;

    try {
      // Find the root RDF element
      final rdfElement = _findRdfRootElement();

      // Process all child nodes of the RDF element
      for (final node in rdfElement.childElements) {
        _processNode(node, triples);
      }

      // Validate output if required
      if (_options.validateOutput) {
        _validateTriples(triples);
      }

      _logger.fine('Parsed ${triples.length} triples');
      return triples;
    } catch (e) {
      _logger.severe('Error parsing RDF/XML: $e');
      if (e is RdfXmlException) {
        rethrow;
      }
      throw RdfStructureException('Error parsing RDF/XML: $e');
    }
  }

  /// Validates the parsed triples for RDF conformance
  ///
  /// Checks for common issues in the generated triples.
  void _validateTriples(List<Triple> triples) {
    for (final triple in triples) {
      // Validate subject
      if (triple.subject is! IriTerm && triple.subject is! BlankNodeTerm) {
        throw RdfStructureException(
          'Invalid subject type: ${triple.subject.runtimeType}',
        );
      }

      // Validate predicate
      if (triple.predicate is! IriTerm) {
        throw RdfStructureException(
          'Invalid predicate type: ${triple.predicate.runtimeType}',
        );
      }

      // Validate object (can be any RDF term)
      if (triple.object is! IriTerm &&
          triple.object is! BlankNodeTerm &&
          triple.object is! LiteralTerm) {
        throw RdfStructureException(
          'Invalid object type: ${triple.object.runtimeType}',
        );
      }
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
      namespace: RdfTerms.rdfNamespace,
    );

    if (rdfElements.isNotEmpty) {
      return rdfElements.first;
    }

    // If no rdf:RDF element found, use the document element if it has RDF namespace
    final rootElement = _document.rootElement;
    if (rootElement.namespaceUri == RdfTerms.rdfNamespace) {
      return rootElement;
    }

    // Look for any element with RDF namespace declarations
    for (final element in _document.findAllElements('*')) {
      final hasRdfNs = element.attributes.any(
        (attr) =>
            attr.name.qualified == 'xmlns:rdf' &&
            attr.value == RdfTerms.rdfNamespace,
      );

      if (hasRdfNs) {
        return element;
      }
    }

    throw RdfStructureException(
      'No RDF/XML root element found. Document should contain an rdf:RDF element or use RDF namespace.',
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
    // Check nesting depth if limit is set
    if (_options.maxNestingDepth > 0) {
      _currentDepth++;
      if (_currentDepth > _options.maxNestingDepth) {
        _currentDepth--;
        throw RdfStructureException(
          'Maximum nesting depth exceeded: $_currentDepth > ${_options.maxNestingDepth}',
          elementName: element.name.qualified,
        );
      }
    }

    try {
      _logger.fine('Processing element: ${element.name.qualified}');

      // Check if this is an rdf:Description or a typed resource
      final isDescription =
          element.name.local == 'Description' &&
          element.name.namespaceUri == RdfTerms.rdfNamespace;

      // Get the subject of this element
      final currentSubject = subject ?? _getSubject(element);

      // If this is a typed resource (not rdf:Description), add a type triple
      if (!isDescription &&
          element.name.namespaceUri != RdfTerms.rdfNamespace) {
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
    } finally {
      // Always decrement depth counter when done with this node
      if (_options.maxNestingDepth > 0) {
        _currentDepth--;
      }
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
      namespace: RdfTerms.rdfNamespace,
    );
    if (resourceAttr != null) {
      final objectIri = _uriResolver.resolveUri(resourceAttr, _resolvedBaseUri);
      triples.add(Triple(subject, predicate, IriTerm(objectIri)));
      return;
    }

    // Check for rdf:nodeID attribute (blank node reference)
    final nodeIdAttr = propertyElement.getAttribute(
      'nodeID',
      namespace: RdfTerms.rdfNamespace,
    );
    if (nodeIdAttr != null) {
      final blankNode = _blankNodeManager.getBlankNode(nodeIdAttr);
      triples.add(Triple(subject, predicate, blankNode));
      return;
    }

    // Check for rdf:parseType attribute
    final parseTypeAttr = propertyElement.getAttribute(
      'parseType',
      namespace: RdfTerms.rdfNamespace,
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
      namespace: RdfTerms.rdfNamespace,
    );

    // If we get here, this is a literal property
    String literalValue = propertyElement.innerText;

    // Apply whitespace normalization if configured
    if (_options.normalizeWhitespace) {
      literalValue = _normalizeWhitespace(literalValue);
    }

    // Check for XML language attribute (xml:lang)
    final langAttr = propertyElement.getAttribute(
      'lang',
      namespace: 'http://www.w3.org/XML/1998/namespace',
    );

    if (datatypeAttr != null) {
      // Typed literal
      final datatype = IriTerm(
        _uriResolver.resolveUri(datatypeAttr, _resolvedBaseUri),
      );
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

  /// Normalizes whitespace according to XML rules
  ///
  /// Replaces sequences of whitespace with a single space,
  /// and trims leading and trailing whitespace.
  String _normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
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
            LiteralTerm(xmlContent, datatype: RdfTerms.xmlLiteral),
          ),
        );
        break;

      case 'Collection':
        // Treat content as an RDF collection (list)
        _processCollection(subject, predicate, element.childElements, triples);
        break;

      default:
        if (_options.strictMode) {
          throw RdfStructureException(
            'Unknown rdf:parseType "$parseType"',
            elementName: element.name.qualified,
          );
        } else {
          // In non-strict mode, treat as a resource (like specified in the spec)
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

  /// Gets the subject term for an element
  ///
  /// Extracts the subject IRI or blank node from element attributes
  /// according to RDF/XML rules (rdf:about, rdf:ID, or blank node).
  RdfSubject _getSubject(XmlElement element) {
    // Check for rdf:about attribute
    final aboutAttr = element.getAttribute(
      'about',
      namespace: RdfTerms.rdfNamespace,
    );
    if (aboutAttr != null) {
      try {
        final iri = _uriResolver.resolveUri(aboutAttr, _resolvedBaseUri);
        return IriTerm(iri);
      } catch (e) {
        throw UriResolutionException(
          'Failed to resolve rdf:about URI',
          uri: aboutAttr,
          baseUri: _resolvedBaseUri,
          sourceContext: element.name.qualified,
        );
      }
    }

    // Check for rdf:ID attribute
    final idAttr = element.getAttribute('ID', namespace: RdfTerms.rdfNamespace);
    if (idAttr != null) {
      try {
        // rdf:ID creates a URI relative to the document base URI
        final iri = '${_resolvedBaseUri}#$idAttr';
        return IriTerm(iri);
      } catch (e) {
        throw UriResolutionException(
          'Failed to create IRI from rdf:ID',
          uri: '#$idAttr',
          baseUri: _resolvedBaseUri,
          sourceContext: element.name.qualified,
        );
      }
    }

    // Check for rdf:nodeID attribute
    final nodeIdAttr = element.getAttribute(
      'nodeID',
      namespace: RdfTerms.rdfNamespace,
    );
    if (nodeIdAttr != null) {
      return _blankNodeManager.getBlankNode(nodeIdAttr);
    }

    // No identifier, create a blank node
    return BlankNodeTerm();
  }
}
