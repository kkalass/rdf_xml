// Part of the RdfXmlParser implementation
part of 'package:rdf_xml/src/rdfxml_parser.dart';

/// Stream-based context for RDF/XML parsing
///
/// Internal helper class that manages state during stream-based parsing.
/// Processes XML events and converts them to RDF triples.
class _StreamParsingContext {
  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Blank node manager for handling blank nodes
  final FunctionalBlankNodeManager _blankNodeManager;

  /// Parser options for configuring behavior
  final RdfXmlParserOptions _options;

  /// Base URI for resolving relative URIs
  final String? _baseUri;

  /// Resolved base URI
  late final String _resolvedBaseUri;

  /// Stack of element states for tracking nested elements
  final List<_ElementState> _elementStack = [];

  /// Current parsing depth
  int _currentDepth = 0;

  /// Buffer for collecting text nodes between start and end tags
  String _textBuffer = '';

  /// Whether we've found the root RDF element
  bool _foundRdfRoot = false;

  /// Map of XML namespace prefixes to their URIs
  final Map<String, String> _namespaces = {};

  /// Tracking der bereits generierten Triples für Container-Indizierung und Validierung
  final List<Triple> _generatedTriples = [];

  /// Constructor for stream parsing context
  _StreamParsingContext({
    required IUriResolver uriResolver,
    required FunctionalBlankNodeManager blankNodeManager,
    required RdfXmlParserOptions options,
    required String? baseUri,
    required RdfNamespaceMappings namespaceMappings,
  }) : _uriResolver = uriResolver,
       _blankNodeManager = blankNodeManager,
       _options =
           options.maxNestingDepth == 100
               ? RdfXmlParserOptions(
                 maxNestingDepth: 250,
                 normalizeWhitespace: options.normalizeWhitespace,
                 strictMode: options.strictMode,
                 validateOutput: options.validateOutput,
               )
               : options,
       _baseUri = baseUri {
    _resolvedBaseUri = _baseUri ?? '';

    // Initialize with standard namespaces
    _namespaces.addAll(namespaceMappings.asMap());
  }

  /// Processes a start element event
  ///
  /// Handles the beginning of an XML element, extracting RDF triples
  /// according to element type and attributes.
  Future<_ElementResult> processStartElement(XmlStartElementEvent event) async {
    final triples = <Triple>[];

    // Extract namespace declarations from this element
    _extractNamespaces(event);

    // Check nesting depth if limit is set
    if (_options.maxNestingDepth > 0) {
      _currentDepth++;
      if (_currentDepth > _options.maxNestingDepth) {
        _currentDepth--;
        throw RdfStructureException(
          'Maximum nesting depth exceeded: $_currentDepth > ${_options.maxNestingDepth}',
          elementName: event.name,
        );
      }
    }

    // Reset text buffer for new element
    _textBuffer = '';

    // Check if this is the rdf:RDF root element
    if (!_foundRdfRoot) {
      final isRdfRoot = _isRdfRootElement(event);
      if (isRdfRoot) {
        _foundRdfRoot = true;

        // Extract xml:base if present
        final xmlBase = _getXmlBase(event);
        if (xmlBase != null) {
          // Update base URI
          _resolvedBaseUri = xmlBase;
        }

        // Create state for the root element
        final state = _ElementState(
          name: event.name,
          subject: null, // Root has no subject
          predicate: null, // Root has no predicate
          isRdfRoot: true,
        );

        _elementStack.add(state);
        return _ElementResult(triples: []);
      }
    }

    // If we haven't found the RDF root yet, and this isn't it, skip
    if (!_foundRdfRoot) {
      final state = _ElementState(
        name: event.name,
        subject: null,
        predicate: null,
        isSkipped: true,
      );
      _elementStack.add(state);
      return _ElementResult(triples: []);
    }

    // If we have a parent element to provide context
    if (_elementStack.isNotEmpty) {
      final parentState = _elementStack.last;

      // Special handling for container items (rdf:li)
      if (parentState.isContainer &&
          event.localName == 'li' &&
          _getNamespace(event, 'rdf') == RdfTerms.rdfNamespace) {
        // Handle container items (rdf:li -> rdf:_n)
        final result = await _handleContainerItem(event, parentState);
        // Speichere generierte Triples
        _generatedTriples.addAll(result.triples);
        return result;
      }

      // If parent is the RDF root or a Description, this is a subject node
      if (parentState.isRdfRoot || parentState.isDescription) {
        final subject = _createSubjectFromElement(event);

        // Check if this is an rdf:Description or a typed resource
        final isDescription = _isRdfDescription(event);

        // If this is a typed resource, add a type triple
        if (!isDescription && !_isRdfNamespaceElement(event)) {
          final typeIri = _createTypeIriFromElement(event);
          triples.add(Triple(subject, RdfTerms.type, typeIri));
        }

        // Process attributes that represent properties
        final attrTriples = _processPropertyAttributes(event, subject);
        triples.addAll(attrTriples);

        // Create state for this element
        final state = _ElementState(
          name: event.name,
          subject: subject,
          predicate: null,
          isDescription: isDescription,
        );

        _elementStack.add(state);
      }
      // If parent has a subject but this isn't the RDF root, this is a property
      else if (parentState.subject != null) {
        final predicate = _createPredicateFromElement(event);

        // Check for rdf:ID attribute (reification)
        final idAttr = _getAttributeValue(event, 'ID', RdfTerms.rdfNamespace);

        // Check for rdf:resource attribute (simple resource reference)
        final resourceAttr = _getAttributeValue(
          event,
          'resource',
          RdfTerms.rdfNamespace,
        );

        if (resourceAttr != null) {
          final objectIri = _uriResolver.resolveUri(
            resourceAttr,
            _resolvedBaseUri,
          );
          if (objectIri.isEmpty) {
            throw UriResolutionException(
              'Failed to resolve rdf:resource URI',
              uri: resourceAttr,
              baseUri: _resolvedBaseUri,
              sourceContext: event.name,
            );
          }

          // Create the base triple
          final object = IriTerm(objectIri);
          final baseTriple = Triple(parentState.subject!, predicate, object);
          triples.add(baseTriple);

          // Handle reification if rdf:ID is present
          if (idAttr != null) {
            triples.addAll(_createReificationTriples(idAttr, baseTriple));
          }

          // Mark this element as processed so we don't process it again at end
          final state = _ElementState(
            name: event.name,
            subject: null,
            predicate: predicate,
            isResourceProperty: true,
          );

          _elementStack.add(state);
        }
        // Check for rdf:nodeID attribute (blank node reference)
        else {
          final nodeIdAttr = _getAttributeValue(
            event,
            'nodeID',
            RdfTerms.rdfNamespace,
          );

          if (nodeIdAttr != null) {
            final blankNode = _blankNodeManager.getBlankNode(nodeIdAttr);
            final baseTriple = Triple(
              parentState.subject!,
              predicate,
              blankNode,
            );
            triples.add(baseTriple);

            // Handle reification if rdf:ID is present
            if (idAttr != null) {
              triples.addAll(_createReificationTriples(idAttr, baseTriple));
            }

            // Mark this element as processed
            final state = _ElementState(
              name: event.name,
              subject: null,
              predicate: predicate,
              isResourceProperty: true,
            );

            _elementStack.add(state);
          }
          // Check for rdf:parseType attribute
          else {
            final parseTypeAttr = _getAttributeValue(
              event,
              'parseType',
              RdfTerms.rdfNamespace,
            );

            if (parseTypeAttr != null) {
              // Handle the different parseTypes
              switch (parseTypeAttr) {
                case 'Resource':
                  final nestedSubject = BlankNodeTerm();
                  final baseTriple = Triple(
                    parentState.subject!,
                    predicate,
                    nestedSubject,
                  );
                  triples.add(baseTriple);

                  // Handle reification if rdf:ID is present
                  if (idAttr != null) {
                    triples.addAll(
                      _createReificationTriples(idAttr, baseTriple),
                    );
                  }

                  final state = _ElementState(
                    name: event.name,
                    subject: nestedSubject,
                    predicate: predicate,
                    isParseTypeResource: true,
                  );

                  _elementStack.add(state);
                  break;

                case 'Literal':
                  // For Literal, we'll collect content until the end element
                  final state = _ElementState(
                    name: event.name,
                    subject: parentState.subject,
                    predicate: predicate,
                    isParseTypeLiteral: true,
                  );

                  _elementStack.add(state);
                  break;

                case 'Collection':
                  // For Collection, more complex handling in end element
                  final state = _ElementState(
                    name: event.name,
                    subject: parentState.subject,
                    predicate: predicate,
                    isParseTypeCollection: true,
                  );

                  _elementStack.add(state);
                  break;

                default:
                  if (_options.strictMode) {
                    throw RdfStructureException(
                      'Unknown rdf:parseType "$parseTypeAttr"',
                      elementName: event.name,
                    );
                  } else {
                    // In non-strict mode, treat as Resource
                    final nestedSubject = BlankNodeTerm();
                    triples.add(
                      Triple(parentState.subject!, predicate, nestedSubject),
                    );

                    final state = _ElementState(
                      name: event.name,
                      subject: nestedSubject,
                      predicate: predicate,
                      isParseTypeResource: true,
                    );

                    _elementStack.add(state);
                  }
              }
            }
            // Check if this is an RDF container element (Bag, Seq, Alt)
            else if (_isRdfContainerElement(event)) {
              // Container handling
              final containerNode = BlankNodeTerm();
              final baseTriple = Triple(
                parentState.subject!,
                predicate,
                containerNode,
              );
              triples.add(baseTriple);

              // Add the type triple based on the container type
              final containerType = _getContainerTypeIri(event);
              triples.add(Triple(containerNode, RdfTerms.type, containerType));

              // Mark this element as a container
              final state = _ElementState(
                name: event.name,
                subject: containerNode,
                predicate: null,
                isContainer: true,
              );

              _elementStack.add(state);
            }
            // Regular property element
            else {
              // Check if it has nested elements or is a literal
              final state = _ElementState(
                name: event.name,
                subject: parentState.subject,
                predicate: predicate,
                isLiteralProperty: true,
              );

              _elementStack.add(state);
            }
          }
        }
      }
    } else {
      // If we have no parent element but this is RDF, make it the root
      if (_isRdfRootElement(event)) {
        _foundRdfRoot = true;
        final state = _ElementState(
          name: event.name,
          subject: null,
          predicate: null,
          isRdfRoot: true,
        );
        _elementStack.add(state);
      } else {
        // Skip elements outside the RDF root
        final state = _ElementState(
          name: event.name,
          subject: null,
          predicate: null,
          isSkipped: true,
        );
        _elementStack.add(state);
      }
    }

    // Füge alle erzeugten Triples zu _generatedTriples hinzu, bevor wir sie zurückgeben
    _generatedTriples.addAll(triples);

    return _ElementResult(triples: triples);
  }

  /// Handles the rdf:li elements for containers and changes them to _1, _2, etc.
  Future<_ElementResult> _handleContainerItem(
    XmlStartElementEvent event,
    _ElementState parentState,
  ) async {
    final triples = <Triple>[];

    // Check if parent is a container
    if (parentState.isContainer &&
        event.localName == 'li' &&
        _getNamespace(event, 'rdf') == RdfTerms.rdfNamespace) {
      // Count existing container members to determine the new index
      int itemCount = _countContainerItems(parentState.subject!);

      // Generate the appropriate predicate based on the position (_1, _2, etc.)
      final predicate = IriTerm('${RdfTerms.rdfNamespace}_${itemCount + 1}');

      // Handle both literal content and nested resources
      final resourceAttr = _getAttributeValue(
        event,
        'resource',
        RdfTerms.rdfNamespace,
      );

      if (resourceAttr != null) {
        // This is a resource reference
        final objectIri = _uriResolver.resolveUri(
          resourceAttr,
          _resolvedBaseUri,
        );
        triples.add(
          Triple(parentState.subject!, predicate, IriTerm(objectIri)),
        );

        // Create a state for this element so we don't process it again
        _elementStack.add(
          _ElementState(
            name: event.name,
            subject: null,
            predicate: predicate,
            isResourceProperty: true,
          ),
        );
      } else {
        // This is likely a literal or will contain nested content
        // Set up for text collection or nested processing
        _elementStack.add(
          _ElementState(
            name: event.name,
            subject: parentState.subject,
            predicate: predicate,
            isLiteralProperty: true,
          ),
        );
      }

      return _ElementResult(triples: triples);
    }

    // Not a container item
    return _ElementResult(triples: []);
  }

  /// Count the number of existing container items for a subject
  int _countContainerItems(RdfSubject subject) {
    // Speichern der bereits erzeugten Triples, die Container-Elemente sind
    final containerTriples = <Triple>[];

    // Überprüfe alle Triple, die diesem Container-Subject gehören
    for (final triple in _generatedTriples) {
      if (triple.subject == subject &&
          triple.predicate is IriTerm &&
          (triple.predicate as IriTerm).iri.startsWith(
            '${RdfTerms.rdfNamespace}_',
          )) {
        containerTriples.add(triple);
      }
    }

    return containerTriples.length;
  }

  /// Checks if an element is the RDF root element
  bool _isRdfRootElement(XmlStartElementEvent event) {
    // Check if it's rdf:RDF
    if (event.name == 'RDF' &&
        _getNamespace(event, 'rdf') == RdfTerms.rdfNamespace) {
      return true;
    }

    // Also check attributes for xmlns:rdf
    for (final attr in event.attributes) {
      if (attr.name == 'xmlns:rdf' && attr.value == RdfTerms.rdfNamespace) {
        return true;
      }
    }

    return false;
  }

  /// Checks if an element is rdf:Description
  bool _isRdfDescription(XmlStartElementEvent event) {
    return event.name == 'Description' &&
        _getNamespace(event, 'rdf') == RdfTerms.rdfNamespace;
  }

  /// Checks if an element is in the RDF namespace
  bool _isRdfNamespaceElement(XmlStartElementEvent event) {
    final namespace = _getNamespaceForPrefix(event, event.namespacePrefix);
    return namespace == RdfTerms.rdfNamespace;
  }

  /// Creates a subject term from an element
  RdfSubject _createSubjectFromElement(XmlStartElementEvent event) {
    // Check for rdf:about attribute
    final aboutAttr = _getAttributeValue(event, 'about', RdfTerms.rdfNamespace);
    if (aboutAttr != null) {
      try {
        final iri = _uriResolver.resolveUri(aboutAttr, _resolvedBaseUri);
        if (iri.isEmpty) {
          throw UriResolutionException(
            'Failed to resolve rdf:about URI',
            uri: aboutAttr,
            baseUri: _resolvedBaseUri,
            sourceContext: event.name,
          );
        }
        return IriTerm(iri);
      } catch (e) {
        throw UriResolutionException(
          'Failed to resolve rdf:about URI',
          uri: aboutAttr,
          baseUri: _resolvedBaseUri,
          sourceContext: event.name,
        );
      }
    }

    // Check for rdf:ID attribute
    final idAttr = _getAttributeValue(event, 'ID', RdfTerms.rdfNamespace);
    if (idAttr != null) {
      try {
        if (_resolvedBaseUri.isEmpty) {
          throw UriResolutionException(
            'Base URI is not set for rdf:ID',
            uri: '#$idAttr',
            baseUri: _resolvedBaseUri,
            sourceContext: event.name,
          );
        }
        final iri = '${_resolvedBaseUri}#$idAttr';
        return IriTerm(iri);
      } catch (e) {
        throw UriResolutionException(
          'Failed to create IRI from rdf:ID',
          uri: '#$idAttr',
          baseUri: _resolvedBaseUri,
          sourceContext: event.name,
        );
      }
    }

    // Check for rdf:nodeID attribute
    final nodeIdAttr = _getAttributeValue(
      event,
      'nodeID',
      RdfTerms.rdfNamespace,
    );
    if (nodeIdAttr != null) {
      return _blankNodeManager.getBlankNode(nodeIdAttr);
    }

    // No identifier, create a blank node
    return BlankNodeTerm();
  }

  /// Creates a type IRI from an element name
  IriTerm _createTypeIriFromElement(XmlStartElementEvent event) {
    final namespace =
        _getNamespaceForPrefix(event, event.namespacePrefix) ?? '';
    if (namespace.isEmpty) {
      throw RdfStructureException(
        'Namespace not found for prefix: ${event.namespacePrefix}',
        elementName: event.name,
      );
    }
    return IriTerm('$namespace${event.localName}');
  }

  /// Creates a predicate IRI from an element name
  RdfPredicate _createPredicateFromElement(XmlStartElementEvent event) {
    final namespace =
        _getNamespaceForPrefix(event, event.namespacePrefix) ?? '';
    if (namespace.isEmpty) {
      throw RdfStructureException(
        'Namespace not found for prefix: ${event.namespacePrefix}',
        elementName: event.name,
      );
    }
    return IriTerm('$namespace${event.localName}');
  }

  /// Processes attributes that represent properties
  List<Triple> _processPropertyAttributes(
    XmlStartElementEvent event,
    RdfSubject subject,
  ) {
    final triples = <Triple>[];

    for (final attr in event.attributes) {
      // Skip rdf: and xmlns: attributes
      final prefix = attr.namespacePrefix;
      if (prefix != 'rdf' &&
          prefix != 'xmlns' &&
          prefix != null &&
          prefix.isNotEmpty) {
        final namespace = _getNamespaceForPrefix(event, prefix) ?? '';
        if (namespace.isEmpty) {
          throw RdfStructureException(
            'Namespace not found for prefix: $prefix',
            elementName: event.name,
          );
        }
        final predicate = IriTerm('$namespace${attr.localName}');
        final object = LiteralTerm.string(attr.value);

        triples.add(Triple(subject, predicate, object));
      }
    }

    return triples;
  }

  /// Gets the value of an attribute with namespace
  String? _getAttributeValue(
    XmlStartElementEvent event,
    String localName,
    String namespace,
  ) {
    for (final attr in event.attributes) {
      if (attr.localName == localName &&
          _getNamespaceForPrefix(event, attr.namespacePrefix) == namespace) {
        return attr.value;
      }
    }
    return null;
  }

  /// Gets the xml:base attribute value
  String? _getXmlBase(XmlStartElementEvent event) {
    return _getAttributeValue(
      event,
      'base',
      'http://www.w3.org/XML/1998/namespace',
    );
  }

  /// Extracts namespace declarations from an element
  void _extractNamespaces(XmlStartElementEvent event) {
    for (final attr in event.attributes) {
      if (attr.name.startsWith('xmlns:')) {
        final prefix = attr.name.substring(6); // Remove 'xmlns:' prefix
        _namespaces[prefix] = attr.value;
      } else if (attr.name == 'xmlns') {
        // Default namespace
        _namespaces[''] = attr.value;
      }
    }
  }

  /// Gets the namespace URI for a prefix
  String? _getNamespaceForPrefix(XmlStartElementEvent event, String? prefix) {
    if (prefix == null || prefix.isEmpty) {
      return null;
    }

    // First check in current element's attributes
    final attrName = 'xmlns:$prefix';
    for (final attr in event.attributes) {
      if (attr.name == attrName) {
        // Store in our namespace map for future use
        _namespaces[prefix] = attr.value;
        return attr.value;
      }
    }

    // Check our namespace map
    return _namespaces[prefix];
  }

  /// Gets the namespace for a standard prefix
  String? _getNamespace(XmlStartElementEvent event, String prefix) {
    // First check in the event's attributes
    final namespace = _getNamespaceForPrefix(event, prefix);
    if (namespace != null) {
      return namespace;
    }

    // Fall back to our namespace map
    return _namespaces[prefix];
  }

  /// Gets the default namespace for well-known prefixes
  String? _getDefaultNamespaceForPrefix(String prefix) {
    return _namespaces[prefix];
  }

  /// Normalizes whitespace according to XML rules
  String _normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Processes a text event
  ///
  /// Collects text content for literal properties.
  void processText(XmlTextEvent event) {
    // Use value instead of text (text is deprecated)
    _textBuffer += event.value;
  }

  /// Handles the end of an XML element, finalizing any RDF triples
  /// that span multiple events (e.g., literal properties).
  _ElementResult processEndElement(XmlEndElementEvent event) {
    final triples = <Triple>[];

    // Decrement depth counter
    if (_options.maxNestingDepth > 0) {
      _currentDepth--;
    }

    // Match with the corresponding start element
    if (_elementStack.isNotEmpty) {
      final state = _elementStack.removeLast();

      // Skip elements we're ignoring
      if (state.isSkipped || state.isRdfRoot) {
        return _ElementResult(triples: []);
      }

      // Handle literal properties
      if (state.isLiteralProperty &&
          state.subject != null &&
          state.predicate != null) {
        // Get the text content
        String literalValue = _textBuffer.trim();

        // Apply whitespace normalization if configured
        if (_options.normalizeWhitespace) {
          literalValue = _normalizeWhitespace(literalValue);
        }

        // Überprüfen, ob dieser Wert einen bestimmten Datentyp hat
        final datatype = _detectDatatype(literalValue);

        // Plain literal oder datatyped literal, aber nur erstellen wenn literalValue nicht leer ist
        if (literalValue.isNotEmpty) {
          final literal =
              datatype != null
                  ? LiteralTerm(literalValue, datatype: datatype)
                  : LiteralTerm.string(literalValue);

          final triple = Triple(state.subject!, state.predicate!, literal);
          triples.add(triple);
          // Triple in die Liste der generierten Triples aufnehmen
          _generatedTriples.add(triple);
        }
      }
      // Handle parseType="Literal"
      else if (state.isParseTypeLiteral &&
          state.subject != null &&
          state.predicate != null) {
        // For a real parser, we'd need to collect the XML content here
        final xmlContent = _textBuffer;
        final triple = Triple(
          state.subject!,
          state.predicate!,
          LiteralTerm(xmlContent, datatype: RdfTerms.xmlLiteral),
        );
        triples.add(triple);
        // Triple in die Liste der generierten Triples aufnehmen
        _generatedTriples.add(triple);
      }
    }

    // Reset text buffer
    _textBuffer = '';

    return _ElementResult(triples: triples);
  }

  /// Erkennt den Datentyp eines literalen Wertes
  IriTerm? _detectDatatype(String value) {
    // Versuche, einen Integer zu erkennen
    if (RegExp(r'^[+-]?\d+$').hasMatch(value)) {
      return IriTerm('http://www.w3.org/2001/XMLSchema#integer');
    }

    // Versuche, eine Dezimalzahl zu erkennen
    if (RegExp(r'^[+-]?\d+\.\d+$').hasMatch(value)) {
      return IriTerm('http://www.w3.org/2001/XMLSchema#decimal');
    }

    // Versuche, einen Boolean zu erkennen
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      return IriTerm('http://www.w3.org/2001/XMLSchema#boolean');
    }

    // Für alle anderen Werte defaultmäßig String
    return null;
  }

  /// Checks if an element is an RDF container element (Bag, Seq, Alt)
  bool _isRdfContainerElement(XmlStartElementEvent event) {
    final namespace = _getNamespace(event, 'rdf');
    if (namespace != RdfTerms.rdfNamespace) {
      return false;
    }

    final localName = event.localName;
    return localName == 'Bag' || localName == 'Seq' || localName == 'Alt';
  }

  /// Gets the type IRI for a container element
  IriTerm _getContainerTypeIri(XmlStartElementEvent event) {
    final localName = event.localName;
    return IriTerm('${RdfTerms.rdfNamespace}$localName');
  }

  /// Creates reification triples for a statement with rdf:ID
  List<Triple> _createReificationTriples(String idAttr, Triple baseTriple) {
    final triples = <Triple>[];

    // Create the statement IRI from the ID
    if (_resolvedBaseUri.isEmpty) {
      throw UriResolutionException(
        'Base URI is not set for rdf:ID',
        uri: '#$idAttr',
        baseUri: _resolvedBaseUri,
        sourceContext: 'reification',
      );
    }

    // Form the statement IRI
    final statementIri = IriTerm('${_resolvedBaseUri}#$idAttr');

    // Add the reification triples
    // 1. Type statement
    triples.add(
      Triple(
        statementIri,
        RdfTerms.type,
        IriTerm('${RdfTerms.rdfNamespace}Statement'),
      ),
    );

    // 2. Subject
    triples.add(
      Triple(
        statementIri,
        IriTerm('${RdfTerms.rdfNamespace}subject'),
        baseTriple.subject,
      ),
    );

    // 3. Predicate - Konvertierung notwendig, da Prädikate nicht direkt als Objekte verwendet werden können
    final predicateIri = (baseTriple.predicate as IriTerm).iri;
    triples.add(
      Triple(
        statementIri,
        IriTerm('${RdfTerms.rdfNamespace}predicate'),
        IriTerm(predicateIri),
      ),
    );

    // 4. Object
    triples.add(
      Triple(
        statementIri,
        IriTerm('${RdfTerms.rdfNamespace}object'),
        baseTriple.object,
      ),
    );

    return triples;
  }
}

/// Result of processing an XML element
class _ElementResult {
  /// Triples produced by processing the element
  final List<Triple> triples;

  /// Constructor for element processing result
  const _ElementResult({required this.triples});
}

/// State for an XML element during parsing
class _ElementState {
  /// Element name
  final String name;

  /// Subject term for this element, if it represents a subject
  final RdfSubject? subject;

  /// Predicate term for this element, if it represents a property
  final RdfPredicate? predicate;

  /// Whether this is the RDF root element
  final bool isRdfRoot;

  /// Whether this is an rdf:Description element
  final bool isDescription;

  /// Whether this is a property with rdf:resource
  final bool isResourceProperty;

  /// Whether this is a property with rdf:parseType="Resource"
  final bool isParseTypeResource;

  /// Whether this is a property with rdf:parseType="Literal"
  final bool isParseTypeLiteral;

  /// Whether this is a property with rdf:parseType="Collection"
  final bool isParseTypeCollection;

  /// Whether this is a literal property
  final bool isLiteralProperty;

  /// Whether this element should be skipped
  final bool isSkipped;

  /// Whether this is an RDF container element (Bag, Seq, Alt)
  final bool isContainer;

  /// Constructor for element state
  const _ElementState({
    required this.name,
    required this.subject,
    required this.predicate,
    this.isRdfRoot = false,
    this.isDescription = false,
    this.isResourceProperty = false,
    this.isParseTypeResource = false,
    this.isParseTypeLiteral = false,
    this.isParseTypeCollection = false,
    this.isLiteralProperty = false,
    this.isSkipped = false,
    this.isContainer = false,
  });
}
