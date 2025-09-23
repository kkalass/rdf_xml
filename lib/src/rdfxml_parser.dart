/// RDF/XML Parser Implementation
///
/// Parses RDF/XML syntax into RDF triples according to the W3C RDF/XML specification.
/// This is a feature-complete parser that handles all aspects of the RDF/XML syntax:
///
/// - Structured parsing of RDF/XML documents
/// - Support for rdf:about, rdf:ID, and rdf:nodeID attributes
/// - XML Base and namespace resolution
/// - Typed nodes (shorthand for rdf:type)
/// - Literal properties with datatype and language tags
/// - Support for rdf:parseType="Resource", "Literal", and "Collection"
/// - Handling of rdf:Bag, rdf:Seq, and rdf:Alt containers
/// - XML language inheritance (xml:lang)
/// - Blank node generation and mapping
///
/// The parser follows the clean architecture principles with dependency injection
/// for components like XML parsing and URI resolution, making it highly testable
/// and adaptable to different environments.
///
/// Example usage:
/// ```dart
/// final parser = RdfXmlParser(xmlDocument, baseUri: 'http://example.org/');
/// final triples = parser.parse();
/// final graph = RdfGraph.fromTriples(triples);
/// ```
///
/// For configuration options, see [RdfXmlDecoderOptions].
library rdfxml_parser;

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import 'configuration.dart';
import 'exceptions.dart';
// Import the necessary parts of parsing_impl
import 'implementations/parsing_impl.dart'
    show
        DefaultXmlDocumentProvider,
        DefaultUriResolver,
        FunctionalBlankNodeManager;
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
  // Hierarchical loggers for different processing levels
  static final _logger = Logger('rdf.parser.rdfxml');
  static final _structureLogger = Logger('rdf.parser.rdfxml.structure');
  static final _nodeLogger = Logger('rdf.parser.rdfxml.node');
  static final _uriLogger = Logger('rdf.parser.rdfxml.uri');

  /// The RDF/XML document to parse
  final String _input;

  /// Base URI for resolving relative URIs
  final String? _documentUri;

  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Blank node manager for handling blank nodes
  final IBlankNodeManager _blankNodeManager;

  /// Parser options for configuring behavior
  final RdfXmlDecoderOptions _options;

  final IriTermFactory _iriTermFactory;

  /// XML document parsed from input
  late final XmlDocument _document;

  /// Current parsing depth for nested elements
  int _currentDepth = 0;

  /// Creates a new RDF/XML parser
  ///
  /// Parameters:
  /// - `input` The RDF/XML document to parse as a string
  /// - `baseUri` Optional base URI for resolving relative references
  /// - `xmlDocumentProvider` Optional XML document provider
  /// - `uriResolver` Optional URI resolver
  /// - `blankNodeManager` Optional blank node manager
  /// - `options` Optional parser options
  RdfXmlParser(
    this._input, {
    String? baseUri,
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    IBlankNodeManager? blankNodeManager,
    RdfNamespaceMappings? namespaceMappings,
    RdfXmlDecoderOptions? options,
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) : _documentUri = baseUri,
       _iriTermFactory = iriTermFactory,
       _xmlDocumentProvider =
           xmlDocumentProvider ?? const DefaultXmlDocumentProvider(),
       _uriResolver = uriResolver ?? const DefaultUriResolver(),
       _blankNodeManager = blankNodeManager ?? FunctionalBlankNodeManager(),
       _options = options ?? const RdfXmlDecoderOptions() {
    try {
      _document = _xmlDocumentProvider.parseXml(_input);
    } catch (e) {
      if (e is XmlParseException) rethrow;
      throw XmlParseException('Failed to parse XML document: ${e.toString()}');
    }
  }

  String? getBaseUri(XmlElement element) {
    // Get the base URI from the xml:base attribute

    // If xml namespace is not declared correctly, we cannot match the
    // base iri attribute with name/namespace but need to use the qualified
    // name as fallback.
    final localBase =
        element.getAttribute(
          'base',
          namespace: 'http://www.w3.org/XML/1998/namespace',
        ) ??
        element.getAttribute('xml:base');

    return localBase;
  }

  /// Resolves the base URI for an element against its parent context
  String? resolveElementBaseUri(XmlElement element, String? parentBaseUri) {
    final localBase = getBaseUri(element);
    if (localBase == null) {
      return parentBaseUri;
    }

    // Check if local base is absolute by trying to parse it as Uri
    try {
      final uri = Uri.parse(localBase);
      if (uri.isAbsolute) {
        return localBase;
      }
    } catch (e) {
      // If parsing fails, treat as relative
    }

    // Otherwise resolve against parent base URI
    if (parentBaseUri == null) {
      return localBase;
    }

    return _uriResolver.resolveUri(localBase, parentBaseUri);
  }

  /// Parses the RDF/XML document and returns a list of triples
  ///
  /// This is the main entry point for parsing RDF/XML data.
  @override
  List<Triple> parse() {
    _logger.fine('Parsing RDF/XML document');

    final triples = <Triple>[];
    _currentDepth = 0;
    var baseUri = _documentUri;
    try {
      baseUri = resolveElementBaseUri(_document.rootElement, baseUri);
      // Find the root RDF element
      final rdfElement = _findRdfRootElement();
      baseUri = resolveElementBaseUri(rdfElement, baseUri);

      // Process all child nodes of the RDF element
      for (final node in rdfElement.childElements) {
        var nodeBaseUri = resolveElementBaseUri(node, baseUri);
        _processNode(node, nodeBaseUri, triples);
      }

      // Validate output if required
      if (_options.validateOutput) {
        _validateTriples(triples);
      }

      _logger.fine('Parsed ${triples.length} triples');
      return triples;
    } catch (e, stackTrace) {
      // Enhanced error logging with context information
      _logger.severe(
        'Error parsing RDF/XML: $e\n'
        'Base URI: ${baseUri ?? "<UNKNOWN>"}\n'
        'Stack trace: $stackTrace',
      );

      // Rethrow specialized exceptions, but wrap generic ones with more context
      if (e is RdfXmlDecoderException) {
        rethrow;
      }
      throw RdfStructureException(
        'Error parsing RDF/XML: ${e.toString()}',
        cause: e,
      );
    }
  }

  /// Validates the parsed triples for RDF conformance
  ///
  /// Checks for common issues in the generated triples using a functional approach
  /// with clear separation of validation concerns.
  void _validateTriples(List<Triple> triples) {
    final invalidTriples =
        triples.where((triple) => !_isValidTriple(triple)).toList();

    if (invalidTriples.isNotEmpty) {
      final error = _buildValidationErrorMessage(invalidTriples.first);
      throw RdfStructureException(error);
    }
  }

  /// Checks if a triple conforms to RDF requirements
  bool _isValidTriple(Triple triple) {
    return _isValidSubject(triple.subject) &&
        _isValidPredicate(triple.predicate) &&
        _isValidObject(triple.object);
  }

  /// Checks if a subject term is valid according to RDF rules
  bool _isValidSubject(RdfSubject subject) =>
      subject is IriTerm || subject is BlankNodeTerm;

  /// Checks if a predicate term is valid according to RDF rules
  bool _isValidPredicate(RdfPredicate predicate) => predicate is IriTerm;

  /// Checks if an object term is valid according to RDF rules
  bool _isValidObject(RdfObject object) =>
      object is IriTerm || object is BlankNodeTerm || object is LiteralTerm;

  /// Builds a detailed error message for an invalid triple
  String _buildValidationErrorMessage(Triple triple) {
    String error = 'Invalid triple detected:';

    if (!_isValidSubject(triple.subject)) {
      error += ' Invalid subject type: ${triple.subject.runtimeType}';
    } else if (!_isValidPredicate(triple.predicate)) {
      error += ' Invalid predicate type: ${triple.predicate.runtimeType}';
    } else {
      error += ' Invalid object type: ${triple.object.runtimeType}';
    }

    return error;
  }

  /// Finds the root RDF element in the document
  ///
  /// According to the spec, this should be an element named rdf:RDF,
  /// but some documents omit this and start directly with RDF content.
  XmlElement _findRdfRootElement() {
    // Optimized search for the RDF root element
    // First look for direct rdf:RDF element (most common case)
    final rdfElements = _document.findAllElements(
      'RDF',
      namespace: RdfTerms.rdfNamespace,
    );

    if (rdfElements.isNotEmpty) {
      _structureLogger.fine('Found standard rdf:RDF root element');
      return rdfElements.first;
    }

    // If not found, check if the root element has RDF namespace
    final rootElement = _document.rootElement;
    if (rootElement.namespaceUri == RdfTerms.rdfNamespace) {
      _structureLogger.fine(
        'Using document root as RDF element (namespace match)',
      );
      return rootElement;
    }

    // Finally, search for elements with RDF namespace declaration
    // Use an efficient XPath-like approach
    _structureLogger.fine(
      'Searching for elements with RDF namespace declaration',
    );
    for (final element in _document.findAllElements('*')) {
      // Only check for "xmlns:rdf" attributes (faster)
      final hasRdfNs =
          element.getAttribute('xmlns:rdf') == RdfTerms.rdfNamespace;

      if (hasRdfNs) {
        _structureLogger.fine(
          'Found element with RDF namespace declaration: ${element.name.qualified}',
        );
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
    String? baseUri,
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
      _nodeLogger.fine('Processing element: ${element.name.qualified}');

      // Check if this is an rdf:Description or a typed resource
      final isDescription =
          element.name.local == 'Description' &&
          element.name.namespaceUri == RdfTerms.rdfNamespace;

      // Get the subject of this element
      final currentSubject = subject ?? _getSubject(element, baseUri);

      // If this is a typed resource, add a type triple
      // We explicitly handle certain elements from the RDF namespace differently
      final isRdfNamespace = element.name.namespaceUri == RdfTerms.rdfNamespace;
      final rdfElementsWithoutTypeTriples = {
        'Description',
        'RDF',
        'li',
        'Property',
      };

      if (!isDescription &&
          (!isRdfNamespace ||
              !rdfElementsWithoutTypeTriples.contains(element.name.local))) {
        if ((element.name.namespaceUri ?? '').isEmpty) {
          throw RdfStructureException(
            'Element without namespace URI: ${element.name.qualified}',
            elementName: element.name.qualified,
          );
        }
        final typeIri = _iriTermFactory(
          '${element.name.namespaceUri}${element.name.local}',
        );
        triples.add(Triple(currentSubject, RdfTerms.type, typeIri));
      }

      // Process all attributes that aren't rdf:, xmlns:, or xml:base as properties
      for (final attr in element.attributes) {
        if (attr.name.prefix != 'rdf' &&
            attr.name.prefix != 'xmlns' &&
            !(attr.name.prefix == 'xml' && attr.name.local == 'base') &&
            attr.name.prefix?.isNotEmpty == true) {
          if ((attr.name.namespaceUri ?? '').isEmpty) {
            throw RdfStructureException(
              'Attribute without namespace URI: ${attr.name.qualified}',
              elementName: element.name.qualified,
            );
          }
          final predicate = _iriTermFactory(
            '${attr.name.namespaceUri}${attr.name.local}',
          );
          final object = LiteralTerm.string(attr.value);
          triples.add(Triple(currentSubject, predicate, object));
        }
      }

      // Process child elements as properties
      for (final childElement in element.childElements) {
        var childBaseUri = resolveElementBaseUri(childElement, baseUri);
        _processProperty(currentSubject, childBaseUri, childElement, triples);
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
    String? baseUri,
    XmlElement propertyElement,
    List<Triple> triples,
  ) {
    final predicate = _getPredicateFromElement(propertyElement);
    baseUri = resolveElementBaseUri(propertyElement, baseUri);

    // Check for rdf:resource attribute (simple resource reference)
    final resourceAttr = propertyElement.getAttribute(
      'resource',
      namespace: RdfTerms.rdfNamespace,
    );
    if (resourceAttr != null) {
      final objectIri = _uriResolver.resolveUri(resourceAttr, baseUri);
      if (objectIri.isEmpty) {
        throw RdfStructureException(
          'Invalid rdf:resource URI: $resourceAttr',
          elementName: propertyElement.name.qualified,
        );
      }

      // Check for rdf:ID attribute (reification)
      final idAttr = propertyElement.getAttribute(
        'ID',
        namespace: RdfTerms.rdfNamespace,
      );

      // Create the base triple
      final triple = Triple(subject, predicate, _iriTermFactory(objectIri));
      triples.add(triple);

      // Handle reification if rdf:ID is present
      if (idAttr != null) {
        triples.addAll(_createReificationTriples(idAttr, triple, baseUri));
      }

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
        baseUri,
        propertyElement,
        parseTypeAttr,
        triples,
      );
      return;
    }

    // Check if this is an RDF container element (Bag, Seq, Alt)
    if (propertyElement.childElements.isNotEmpty &&
        propertyElement.childElements.first.name.local != 'li') {
      final containerElement = propertyElement.childElements.first;
      final containerBaseUri = resolveElementBaseUri(containerElement, baseUri);
      // Check if this is a container element
      if (_isRdfContainerElement(containerElement)) {
        _processContainer(
          subject,
          predicate,
          containerBaseUri,
          containerElement,
          triples,
        );
        return;
      }

      // Check if the single child has rdf:about - this is a special case for direct object reference
      if (propertyElement.childElements.length == 1) {
        final childElement = propertyElement.childElements.first;
        final aboutAttr = childElement.getAttribute(
          'about',
          namespace: RdfTerms.rdfNamespace,
        );

        if (aboutAttr != null) {
          // This is a direct reference to an existing resource
          final objectIri = _uriResolver.resolveUri(aboutAttr, baseUri);
          if (objectIri.isEmpty) {
            throw RdfStructureException(
              'Invalid rdf:about URI: $aboutAttr',
              elementName: childElement.name.qualified,
            );
          }

          // Add triple using the direct resource reference
          triples.add(Triple(subject, predicate, _iriTermFactory(objectIri)));

          // Also process the child element with its own subject
          _processNode(childElement, baseUri, triples);
          return;
        }
      }
    }

    // Check for nested elements
    if (propertyElement.childElements.isNotEmpty) {
      // If there are child elements, this is a nested resource description
      final nestedSubject = BlankNodeTerm();
      triples.add(Triple(subject, predicate, nestedSubject));

      // Process each child element as part of the nested resource
      for (final childElement in propertyElement.childElements) {
        // For a nested resource, we pass the blank node as the new subject
        _processNode(
          childElement,
          resolveElementBaseUri(childElement, baseUri),
          triples,
          subject: nestedSubject,
        );
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
    final langAttr = getLangAttribute(propertyElement);

    if (datatypeAttr != null) {
      // Typed literal
      var resolveUri = _uriResolver.resolveUri(datatypeAttr, baseUri);
      if (resolveUri.isEmpty) {
        throw RdfStructureException(
          'Invalid rdf:datatype URI: $datatypeAttr',
          elementName: propertyElement.name.qualified,
        );
      }
      final datatype = _iriTermFactory(resolveUri);
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

  String? getLangAttribute(XmlElement propertyElement) {
    return propertyElement.getAttribute(
          'lang',
          namespace: 'http://www.w3.org/XML/1998/namespace',
        ) ??
        propertyElement.getAttribute('xml:lang');
  }

  /// Checks if an element is an RDF container element (Bag, Seq, Alt)
  bool _isRdfContainerElement(XmlElement element) {
    final namespace = element.namespaceUri;
    if (namespace != RdfTerms.rdfNamespace) {
      return false;
    }

    final localName = element.localName;
    return localName == 'Bag' || localName == 'Seq' || localName == 'Alt';
  }

  /// Processes an RDF container element (Bag, Seq, Alt)
  ///
  /// Creates a blank node for the container and adds triples for the container type
  /// and member items, transforming rdf:li elements to rdf:_n predicates.
  void _processContainer(
    RdfSubject subject,
    RdfPredicate predicate,
    String? baseUri,
    XmlElement containerElement,
    List<Triple> triples,
  ) {
    baseUri = resolveElementBaseUri(containerElement, baseUri);
    // Create blank node for container
    final containerNode = BlankNodeTerm();
    // Link container to subject
    triples.add(Triple(subject, predicate, containerNode));

    // Add type triple
    final containerType = _iriTermFactory(
      '${RdfTerms.rdfNamespace}${containerElement.localName}',
    );
    triples.add(Triple(containerNode, RdfTerms.type, containerType));

    // Process container items
    int itemIndex = 1;
    for (final itemElement in containerElement.childElements) {
      // Check if this is an rdf:li element
      if (itemElement.localName == 'li' &&
          itemElement.namespaceUri == RdfTerms.rdfNamespace) {
        // Create predicate (rdf:_1, rdf:_2, etc.)
        final itemPredicate = _iriTermFactory(
          '${RdfTerms.rdfNamespace}_$itemIndex',
        );

        // Process item value
        final resourceAttr = itemElement.getAttribute(
          'resource',
          namespace: RdfTerms.rdfNamespace,
        );
        var itemBaseUri = resolveElementBaseUri(itemElement, baseUri);
        if (resourceAttr != null) {
          // Resource reference
          final objectIri = _uriResolver.resolveUri(resourceAttr, itemBaseUri);
          triples.add(
            Triple(containerNode, itemPredicate, _iriTermFactory(objectIri)),
          );
        } else if (itemElement.childElements.isNotEmpty) {
          // Nested resource
          final nestedNode = BlankNodeTerm();
          triples.add(Triple(containerNode, itemPredicate, nestedNode));

          for (final childElement in itemElement.childElements) {
            var childBaseUri = resolveElementBaseUri(childElement, itemBaseUri);
            _processNode(
              childElement,
              childBaseUri,
              triples,
              subject: nestedNode,
            );
          }
        } else {
          // Literal value
          String value = itemElement.innerText;
          if (_options.normalizeWhitespace) {
            value = _normalizeWhitespace(value);
          }

          // Check for datatype attribute
          final datatypeAttr = itemElement.getAttribute(
            'datatype',
            namespace: RdfTerms.rdfNamespace,
          );

          // Check for language tag
          final langAttr = getLangAttribute(itemElement);

          if (datatypeAttr != null) {
            final datatype = _iriTermFactory(
              _uriResolver.resolveUri(datatypeAttr, itemBaseUri),
            );
            triples.add(
              Triple(
                containerNode,
                itemPredicate,
                LiteralTerm(value, datatype: datatype),
              ),
            );
          } else if (langAttr != null) {
            triples.add(
              Triple(
                containerNode,
                itemPredicate,
                LiteralTerm.withLanguage(value, langAttr),
              ),
            );
          } else {
            triples.add(
              Triple(containerNode, itemPredicate, LiteralTerm.string(value)),
            );
          }
        }

        itemIndex++;
      }
    }
  }

  /// Creates reification triples for a statement
  ///
  /// Creates four triples representing the reified statement:
  /// - statement rdf:type rdf:Statement
  /// - statement rdf:subject &lt;subject&gt;
  /// - statement rdf:predicate &lt;predicate&gt;
  /// - statement rdf:object &lt;object&gt;
  List<Triple> _createReificationTriples(
    String idAttr,
    Triple baseTriple,
    String? baseUri,
  ) {
    final triples = <Triple>[];

    if (baseUri == null || baseUri.isEmpty) {
      throw RdfStructureException('Base URI is not set for rdf:ID resolution');
    }

    // Create the statement IRI
    final statementIri = _iriTermFactory('${baseUri}#$idAttr');

    // Add the reification triples
    triples.add(
      Triple(
        statementIri,
        RdfTerms.type,
        const IriTerm('${RdfTerms.rdfNamespace}Statement'),
      ),
    );

    triples.add(
      Triple(
        statementIri,
        const IriTerm('${RdfTerms.rdfNamespace}subject'),
        baseTriple.subject,
      ),
    );

    // Convert predicate to object
    final predicateIri = (baseTriple.predicate as IriTerm).value;
    triples.add(
      Triple(
        statementIri,
        _iriTermFactory('${RdfTerms.rdfNamespace}predicate'),
        _iriTermFactory(predicateIri),
      ),
    );

    triples.add(
      Triple(
        statementIri,
        const IriTerm('${RdfTerms.rdfNamespace}object'),
        baseTriple.object,
      ),
    );

    return triples;
  }

  /// Gets the subject term for an element
  ///
  /// Extracts the subject IRI or blank node from element attributes
  /// according to RDF/XML rules (rdf:about, rdf:ID, or blank node).
  RdfSubject _getSubject(XmlElement element, String? baseUri) {
    // Check for rdf:about attribute
    final aboutAttr = element.getAttribute(
      'about',
      namespace: RdfTerms.rdfNamespace,
    );
    if (aboutAttr != null) {
      try {
        final iri = _uriResolver.resolveUri(aboutAttr, baseUri);
        if (iri.isEmpty) {
          throw RdfStructureException(
            'Invalid rdf:about URI: $aboutAttr',
            elementName: element.name.qualified,
          );
        }
        return _iriTermFactory(iri);
      } catch (e) {
        _uriLogger.severe('Failed to resolve rdf:about URI', e);

        // Re-throw BaseUriRequiredException with context
        if (e is RdfXmlBaseUriRequiredException) {
          throw RdfXmlBaseUriRequiredException(
            relativeUri: e.relativeUri,
            sourceContext: element.name.qualified,
          );
        }

        throw UriResolutionException(
          'Failed to resolve rdf:about URI',
          uri: aboutAttr,
          baseUri: baseUri ?? '<UNKNOWN>',
          sourceContext: element.name.qualified,
        );
      }
    }

    // Check for rdf:ID attribute
    final idAttr = element.getAttribute('ID', namespace: RdfTerms.rdfNamespace);
    if (idAttr != null) {
      try {
        // rdf:ID creates a URI relative to the document base URI
        if (baseUri == null || baseUri.isEmpty) {
          throw RdfXmlBaseUriRequiredException(
            relativeUri: '#$idAttr',
            sourceContext: element.name.qualified,
          );
        }
        final iri = '${baseUri}#$idAttr';
        return _iriTermFactory(iri);
      } catch (e) {
        _uriLogger.severe('Failed to create IRI from rdf:ID', e);

        // Re-throw BaseUriRequiredException with context if not already set
        if (e is RdfXmlBaseUriRequiredException && e.sourceContext == null) {
          throw RdfXmlBaseUriRequiredException(
            relativeUri: e.relativeUri,
            sourceContext: element.name.qualified,
          );
        } else if (e is RdfXmlBaseUriRequiredException) {
          rethrow;
        }

        throw UriResolutionException(
          'Failed to create IRI from rdf:ID',
          uri: '#$idAttr',
          baseUri: baseUri ?? '<UNKNOWN>',
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

  /// Gets a predicate IRI from a property element
  ///
  /// Extracts the predicate IRI using the element's namespace and local name.
  RdfPredicate _getPredicateFromElement(XmlElement element) {
    final namespaceUri = element.namespaceUri ?? '';
    final localName = element.localName;
    if (namespaceUri.isEmpty) {
      throw RdfStructureException(
        'Element without namespace URI: ${element.name.qualified}',
        elementName: element.name.qualified,
      );
    }
    return _iriTermFactory('$namespaceUri$localName');
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
    String? baseUri,
    XmlElement element,
    String parseType,
    List<Triple> triples,
  ) {
    baseUri = resolveElementBaseUri(element, baseUri);
    switch (parseType) {
      case 'Resource':
        // Create a blank node and treat content as a nested resource
        final nestedSubject = BlankNodeTerm();
        triples.add(Triple(subject, predicate, nestedSubject));

        // Process each child element
        for (final childElement in element.childElements) {
          var childBaseUri = resolveElementBaseUri(childElement, baseUri);
          _processNode(
            childElement,
            childBaseUri,
            triples,
            subject: nestedSubject,
          );
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
        _processCollection(
          subject,
          predicate,
          baseUri,
          element.childElements,
          triples,
        );
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
            var childBaseUri = resolveElementBaseUri(childElement, baseUri);
            _processNode(
              childElement,
              childBaseUri,
              triples,
              subject: nestedSubject,
            );
          }
        }
    }
  }

  /// Processes an RDF collection (list)
  ///
  /// Handles parseType="Collection" by creating the RDF list structure.
  /// Uses a purely functional approach with immutable data flow.
  void _processCollection(
    RdfSubject subject,
    RdfPredicate predicate,
    String? baseUri,
    Iterable<XmlElement> items,
    List<Triple> triples,
  ) {
    if (items.isEmpty) {
      // Empty collection, connect with rdf:nil
      triples.add(Triple(subject, predicate, RdfTerms.nil));
      return;
    }

    // Convert to List for indexed access
    final itemsList = items.toList();

    // Create the list chain recursively with a functional approach
    final firstNode = BlankNodeTerm();
    triples.add(Triple(subject, predicate, firstNode));

    // Process all items by building triples
    _buildRdfList(firstNode, baseUri, itemsList, 0, triples);
  }

  /// Recursively builds an RDF list structure
  ///
  /// This helper function processes list items using a functional approach,
  /// avoiding mutable state where possible.
  void _buildRdfList(
    BlankNodeTerm currentNode,
    String? baseUri,
    List<XmlElement> items,
    int index,
    List<Triple> triples,
  ) {
    final item = items[index];
    baseUri = resolveElementBaseUri(item, baseUri);
    final isLastItem = index == items.length - 1;

    // Handle the item based on its content and structure
    RdfObject itemObject;

    if (item.childElements.isEmpty &&
        item.localName == 'Description' &&
        item.namespaceUri == RdfTerms.rdfNamespace &&
        item.attributes
            .where(
              (a) =>
                  a.namespaceUri == RdfTerms.rdfNamespace &&
                  !(a.localName == 'parseType' || a.localName == 'datatype'),
            )
            .isEmpty) {
      // Plain content in rdf:Description element - treat as literal
      String literalValue = item.innerText;

      // Apply whitespace normalization if configured
      if (_options.normalizeWhitespace) {
        literalValue = _normalizeWhitespace(literalValue);
      }

      // Check for language tag
      final langAttr = getLangAttribute(item);

      // Check for datatype attribute
      final datatypeAttr = item.getAttribute(
        'datatype',
        namespace: RdfTerms.rdfNamespace,
      );

      if (datatypeAttr != null) {
        // Typed literal
        final datatype = _iriTermFactory(
          _uriResolver.resolveUri(datatypeAttr, baseUri),
        );
        itemObject = LiteralTerm(literalValue, datatype: datatype);
      } else if (langAttr != null) {
        // Language-tagged literal
        itemObject = LiteralTerm.withLanguage(literalValue, langAttr);
      } else {
        // Plain string literal
        itemObject = LiteralTerm.string(literalValue);
      }
    } else {
      // Regular resource node
      itemObject = _getSubject(item, baseUri);
      _processNode(item, baseUri, triples);
    }

    // Add the triple connecting this list node to the item
    triples.add(Triple(currentNode, RdfTerms.first, itemObject));

    if (isLastItem) {
      // Terminate the list with rdf:nil
      triples.add(Triple(currentNode, RdfTerms.rest, RdfTerms.nil));
    } else {
      // Continue the list with the next node
      final nextNode = BlankNodeTerm();
      triples.add(Triple(currentNode, RdfTerms.rest, nextNode));

      // Process the next item recursively
      _buildRdfList(nextNode, baseUri, items, index + 1, triples);
    }
  }
}
