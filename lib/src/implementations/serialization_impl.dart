/// Default implementations of RDF/XML serialization interfaces
///
/// Provides concrete implementations of the serialization interfaces
/// defined in the interfaces directory.
library rdfxml.serialization.implementations;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import '../interfaces/serialization.dart';
import '../rdfxml_constants.dart';

final class _SubjectGroup {
  final RdfSubject subject;
  final RdfGraph _graph;
  List<IriTerm>? _types;
  late String? qname;
  _ReificationInfo? _reificationInfo;
  bool? _isReification;
  final String? _baseUrl;

  _SubjectGroup.computedQName(
    this.subject,
    this._baseUrl,
    List<Triple> triples,
    String? Function(IriTerm) getTypeQname,
  ) : _graph = RdfGraph(triples: triples) {
    var type = typeIri;
    qname = type == null ? null : getTypeQname(type);
  }

  _SubjectGroup(
    this.subject,
    this._baseUrl,
    List<Triple> triples,
    String? qname,
  ) : _graph = RdfGraph(triples: triples),
      qname = qname;

  _TypeInfo? get typeInfo {
    var t = typeIri;
    var n = qname;
    if (t == null || n == null) {
      return null;
    }
    return _TypeInfo(t, n);
  }

  List<IriTerm> get types {
    if (_types == null) {
      _types =
          _graph
              .findTriples(predicate: RdfTerms.type)
              .map((t) => t.object)
              .whereType<IriTerm>()
              .toList();
    }
    return _types!;
  }

  IriTerm? get typeIri {
    if (types.length == 1) {
      return types.first;
    }
    return null;
  }

  bool get isContainerType {
    if (subject is! BlankNodeTerm) {
      return false;
    }
    var typeIri = this.typeIri;
    return typeIri == RdfTerms.Bag ||
        typeIri == RdfTerms.Seq ||
        typeIri == RdfTerms.Alt;
  }

  String? get containerType {
    if (subject is! BlankNodeTerm) {
      return null;
    }
    var typeIri = this.typeIri;
    return switch (typeIri) {
      RdfTerms.Bag => "Bag",
      RdfTerms.Seq => "Seq",
      RdfTerms.Alt => "Alt",
      _ => null,
    };
  }

  bool get isReification {
    if (_isReification != null) {
      return _isReification!;
    }
    var reificationCandidate =
        subject is IriTerm && types.any((t) => t == RdfTerms.Statement);

    if (reificationCandidate) {
      final statementIri = subject;

      // Extract subject component
      final subjectTriples = properties(RdfTerms.subject);

      // Extract predicate component
      final predicateTriples = properties(RdfTerms.predicate);

      // Extract object component
      final objectTriples = properties(RdfTerms.object);

      // Complete reification requires all three components
      if (statementIri is IriTerm &&
          subjectTriples.length == 1 &&
          predicateTriples.length == 1 &&
          objectTriples.length == 1) {
        final s = subjectTriples[0] as RdfSubject;
        final p = predicateTriples[0] as RdfPredicate;
        final o = objectTriples[0];

        var baseUri = _baseUrl;

        // Only use rdf:ID if:
        // 1. We have a base URI
        // 2. The reification URI starts with baseUri# pattern
        final canUseRdfId =
            baseUri != null &&
            baseUri.isNotEmpty &&
            statementIri.iri.startsWith('$baseUri#');

        if (canUseRdfId) {
          // Extract the local ID from the URI (part after #)
          final localId = statementIri.iri.substring(
            baseUri.length + 1,
          ); // +1 for the #
          // Create reification info
          _reificationInfo = _ReificationInfo(
            localId: localId,
            subject: s,
            predicate: p,
            object: o,
          );
        }
      }
    }
    _isReification = _reificationInfo != null;
    return _isReification!;
  }

  _ReificationInfo? get reificationInfo {
    // side effect: isReification will build the info if needed!
    if (!isReification) {
      return null;
    }
    return _reificationInfo;
  }

  List<Triple> get triples => _graph.triples;

  List<Triple> findTriples({RdfPredicate? predicate, RdfObject? object}) {
    return _graph.findTriples(predicate: predicate, object: object).toList();
  }

  List<RdfObject> properties(RdfPredicate predicate) {
    return _graph
        .findTriples(predicate: predicate)
        .map((t) => t.object)
        .toList();
  }
}

/// Default implementation of INamespaceManager
///
/// Manages namespaces and QName conversions for RDF/XML serialization.
/// Includes caching and optimized algorithms for better performance with large documents.
///
final class DefaultNamespaceManager implements INamespaceManager {
  /// Namespace mappings registry
  final RdfNamespaceMappings _namespaceMappings;

  /// Cache for QName conversions
  static final Map<String, Map<String, String?>> _qnameCache = {};

  /// Cache for namespace extractions from IRIs
  static final Map<String, String?> _namespaceExtractionCache = {};

  /// Creates a new DefaultNamespaceManager
  ///
  /// Parameters:
  /// - [namespaceMappings] Optional namespace mappings to use
  const DefaultNamespaceManager({RdfNamespaceMappings? namespaceMappings})
    : _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings();

  @override
  Map<String, String> buildNamespaceDeclarations(
    RdfGraph graph,
    Map<String, String> customPrefixes,
  ) {
    // Optimize by using a Set to track processed IRIs
    final processedIris = <String>{};

    // Track which namespaces are actually used
    final usedNamespaces = <String, String>{};

    // Always include RDF namespace, as it's required for RDF/XML
    final rdfNamespace = RdfTerms.rdfNamespace;
    usedNamespaces['rdf'] = rdfNamespace;

    // Track all prefixes we might need
    final allNamespaces = Map<String, String>.from(_namespaceMappings.asMap());
    allNamespaces.addAll(customPrefixes);

    // Extract namespaces from IRI terms in the graph
    for (final triple in graph.triples) {
      _collectUsedNamespace(
        triple.subject,
        allNamespaces,
        usedNamespaces,
        processedIris,
      );
      _collectUsedNamespace(
        triple.predicate,
        allNamespaces,
        usedNamespaces,
        processedIris,
      );
      _collectUsedNamespace(
        triple.object,
        allNamespaces,
        usedNamespaces,
        processedIris,
      );
    }

    return usedNamespaces;
  }

  /// Collects namespaces that are actually used in the document
  void _collectUsedNamespace(
    RdfTerm term,
    Map<String, String> allNamespaces,
    Map<String, String> usedNamespaces,
    Set<String> processedIris,
  ) {
    if (term is! IriTerm) {
      return;
    }

    final iri = term.iri;

    // Skip if already processed
    if (processedIris.contains(iri)) {
      return;
    }
    processedIris.add(iri);

    // Check if this IRI uses a known namespace
    final qname = iriToQName(iri, allNamespaces);
    if (qname != null) {
      // Extract prefix from QName
      final prefixEnd = qname.indexOf(':');
      if (prefixEnd > 0) {
        final prefix = qname.substring(0, prefixEnd);

        // Find the namespace for this prefix
        final namespace = allNamespaces[prefix];
        if (namespace != null) {
          // Add this namespace to used namespaces
          usedNamespaces[prefix] = namespace;
          return;
        }
      }
    }

    // If we get here, we need to create a new namespace entry
    _extractNamespace(iri, usedNamespaces);
  }

  /// Extracts namespace from a term if it's an IRI, using a cache and tracking processed IRIs
  void _extractNamespaceFromTerm(
    RdfTerm term,
    Map<String, String> namespaces,
    Set<String> processedIris,
  ) {
    if (term is! IriTerm) {
      return;
    }

    final iri = term.iri;

    // Skip if already processed
    if (processedIris.contains(iri)) {
      return;
    }
    processedIris.add(iri);

    _extractNamespace(iri, namespaces);
  }

  @override
  String? iriToQName(String iri, Map<String, String> namespaces) {
    // Check if this combination is in the cache
    final cacheKey = iri;
    final nsKey = namespaces.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');

    if (_qnameCache.containsKey(nsKey) &&
        _qnameCache[nsKey]!.containsKey(cacheKey)) {
      return _qnameCache[nsKey]![cacheKey];
    }

    // Initialize the namespace cache if needed
    _qnameCache[nsKey] ??= {};

    // Try to convert to QName
    String? result;

    // Sort namespaces by length (descending) for best match
    final sortedNamespaces =
        namespaces.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in sortedNamespaces) {
      final prefix = entry.key;
      final namespace = entry.value;

      if (iri.startsWith(namespace)) {
        final localName = iri.substring(namespace.length);
        // Ensure the local name is a valid XML name
        if (_isValidXmlName(localName) && localName.isNotEmpty) {
          result = '$prefix:$localName';
          break;
        }
      }
    }

    // Cache the result
    _qnameCache[nsKey]![cacheKey] = result;
    return result;
  }

  /// Extracts namespace from an IRI
  ///
  /// Helper method to find namespaces used in the graph data with caching.
  /// This helps to generate compact QNames where possible.
  void _extractNamespace(String iri, Map<String, String> namespaces) {
    // Skip if this is an already known namespace
    if (namespaces.containsValue(iri)) {
      return;
    }

    // Check namespace extraction cache
    if (_namespaceExtractionCache.containsKey(iri)) {
      final cachedNamespace = _namespaceExtractionCache[iri];
      if (cachedNamespace != null) {
        // Check if this namespace is already registered with any prefix
        if (!namespaces.containsValue(cachedNamespace)) {
          _assignPrefixToNamespace(cachedNamespace, namespaces);
        }
      }
      return;
    }

    // Try to extract a namespace using common namespace delimiters
    final lastHash = iri.lastIndexOf('#');
    final lastSlash = iri.lastIndexOf('/');

    // Prefer hash-based namespaces over path-based ones
    final nsEnd =
        lastHash > 0
            ? lastHash + 1
            : lastSlash > 0
            ? lastSlash + 1
            : -1;

    if (nsEnd > 0) {
      final namespace = iri.substring(0, nsEnd);

      // Cache the extraction result
      _namespaceExtractionCache[iri] = namespace;

      // Skip if this namespace is already registered with any prefix
      if (namespaces.containsValue(namespace)) {
        return;
      }

      _assignPrefixToNamespace(namespace, namespaces);
    } else {
      // Cache the failed extraction
      _namespaceExtractionCache[iri] = null;
    }
  }

  /// Assigns a prefix to a namespace, maintaining consistency
  void _assignPrefixToNamespace(
    String namespace,
    Map<String, String> namespaces,
  ) {
    // Check known namespace mappings first for consistent prefixes
    final mappingsMap = _namespaceMappings.asMap();
    for (final entry in mappingsMap.entries) {
      if (entry.value == namespace) {
        namespaces[entry.key] = namespace;
        return;
      }
    }

    // Generate a meaningful prefix from domain when possible
    String? prefix = _tryGeneratePrefixFromDomain(namespace);

    // Ensure prefix is not already used
    if (prefix != null && !namespaces.containsKey(prefix)) {
      namespaces[prefix] = namespace;
      return;
    }

    // Fall back to numbered prefixes
    int prefixNum = 1;
    do {
      prefix = 'ns$prefixNum';
      prefixNum++;
    } while (namespaces.containsKey(prefix));

    namespaces[prefix] = namespace;
  }

  /// Attempts to generate a meaningful prefix from a namespace URI
  ///
  /// For example, http://example.org/ might become "example"
  String? _tryGeneratePrefixFromDomain(String namespace) {
    try {
      // Extract domain from http/https namespaces
      final uriRegex = RegExp(r'^https?://(?:www\.)?([^/]+)/?');
      final match = uriRegex.firstMatch(namespace);

      if (match != null && match.groupCount >= 1) {
        final domain = match.group(1);
        if (domain == null || domain.isEmpty) return null;

        // Extract organization/project name from domain
        final parts = domain.split('.');

        // For domains like example.org, return "example"
        if (parts.length >= 2) {
          final candidate = parts[0];

          // Ensure it's a valid XML name component
          if (_isValidXmlName(candidate)) {
            return candidate;
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Checks if a string is a valid XML local name
  ///
  /// Simple validation for XML names.
  bool _isValidXmlName(String name) {
    if (name.isEmpty) {
      return false;
    }

    // First character must be a letter or underscore
    final firstChar = name.codeUnitAt(0);
    if (!((firstChar >= 65 && firstChar <= 90) || // A-Z
        (firstChar >= 97 && firstChar <= 122) || // a-z
        firstChar == 95)) {
      // _
      return false;
    }

    // Subsequent characters can also include digits and some symbols
    for (int i = 1; i < name.length; i++) {
      final char = name.codeUnitAt(i);
      if (!((char >= 65 && char <= 90) || // A-Z
          (char >= 97 && char <= 122) || // a-z
          (char >= 48 && char <= 57) || // 0-9
          char == 95 || // _
          char == 45 || // -
          char == 46)) {
        // .
        return false;
      }
    }

    return true;
  }
}

/// Default implementation of IRdfXmlBuilder
///
/// Builds XML documents from RDF graphs for serialization.
/// Includes performance optimizations for handling large datasets.
final class DefaultRdfXmlBuilder implements IRdfXmlBuilder {
  /// Namespace manager for handling namespace declarations and QName conversions
  final INamespaceManager _namespaceManager;

  /// Cache for type-to-QName lookups to improve serialization performance
  static final Map<IriTerm, Map<String, String?>> _typeQNameCache = {};

  /// Current base URI for the document being serialized
  String? _currentBaseUri;

  /// Creates a new DefaultRdfXmlBuilder
  ///
  /// Parameters:
  /// - [namespaceManager] Namespace manager for handling namespace operations
  DefaultRdfXmlBuilder({INamespaceManager? namespaceManager})
    : _namespaceManager = namespaceManager ?? const DefaultNamespaceManager();

  /// Current mapping of subject to triples for the current serialization
  /// Initialized in buildDocument
  var _currentSubjectGroups = <RdfSubject, _SubjectGroup>{};

  /// Maps from statement signature (subject+predicate+object) to statement URI
  var _reifiedStatementsMap = <String, _ReificationInfo>{};

  /// Builds an XML document from an RDF graph
  ///
  /// Creates a complete XML representation of the given RDF data.
  @override
  XmlDocument buildDocument(
    RdfGraph graph,
    String? baseUri,
    Map<String, String> namespaces,
  ) {
    // Store the base URI for use in reification
    // If there is no baseUri, we could try to guess a good one from the graph
    // for example if all Subjects have the same root (e.g. the part before the #)
    _currentBaseUri = baseUri;

    final builder = XmlBuilder();

    // Add XML declaration
    builder.declaration(version: '1.0', encoding: 'UTF-8');

    // Group triples by subject for more compact output
    _currentSubjectGroups = _groupTriplesBySubject(graph, namespaces);

    // Detect reification patterns in the graph
    _reifiedStatementsMap = _identifyReificationPatterns(_currentSubjectGroups);

    // Start rdf:RDF element
    builder.element(
      'rdf:RDF',
      nest: () {
        // Add namespace declarations
        for (final entry in namespaces.entries) {
          builder.attribute('xmlns:${entry.key}', entry.value);
        }

        // Add base URI if provided
        if (baseUri != null && baseUri.isNotEmpty) {
          builder.attribute('xml:base', baseUri);
        }

        // Serialize each subject group, except containers that will be nested
        for (final sg in _currentSubjectGroups.values) {
          // Skip container nodes that will be nested
          if (sg.isContainerType) {
            continue;
          }

          // Skip reification statements that will be serialized with rdf:ID
          if (sg.isReification) {
            var newTriples = [...sg.triples];
            newTriples.removeWhere(
              (t) =>
                  t.predicate == RdfTerms.subject ||
                  t.predicate == RdfTerms.predicate ||
                  t.predicate == RdfTerms.object ||
                  (t.predicate == RdfTerms.type &&
                      t.object == RdfTerms.Statement),
            );
            if (newTriples.isNotEmpty) {
              _serializeSubject(
                builder,
                _SubjectGroup(sg.subject, sg._baseUrl, newTriples, null),
                namespaces,
              );
            }
            continue;
          }

          _serializeSubject(builder, sg, namespaces);
        }
      },
    );

    return builder.buildDocument();
  }

  /// Identifies reification patterns in the graph
  ///
  /// Detects subjects that represent reification statements (rdf:Statement) with
  /// corresponding rdf:subject, rdf:predicate, and rdf:object triples.
  Map<String, _ReificationInfo> _identifyReificationPatterns(
    Map<RdfSubject, _SubjectGroup> currentSubjectGroups,
  ) {
    // Reset reification maps
    var result = <String, _ReificationInfo>{};

    for (final sg in currentSubjectGroups.values) {
      // Create reification info
      final info = sg.reificationInfo;
      if (info == null) {
        continue;
      }
      // Check if the original statement exists in the graph
      final statementSignature = _getStatementKey(
        info.subject,
        info.predicate,
        info.object,
      );

      result[statementSignature] = info;
    }
    return result;
  }

  String _getStatementKey(RdfSubject s, RdfPredicate p, RdfObject o) =>
      '${s.toString()}|${p.toString()}|${o.toString()}';

  /// Groups triples by subject to prepare for more compact serialization
  ///
  /// This is a key optimization for RDF/XML output, as it allows
  /// nesting multiple predicates under a single subject.
  Map<RdfSubject, _SubjectGroup> _groupTriplesBySubject(
    RdfGraph graph,
    Map<String, String> namespaces,
  ) {
    final groups = <RdfSubject, List<Triple>>{};

    for (final triple in graph.triples) {
      groups.putIfAbsent(triple.subject, () => []).add(triple);
    }

    final result = <RdfSubject, _SubjectGroup>{};
    for (final e in groups.entries) {
      result[e.key] = _SubjectGroup.computedQName(
        e.key,
        _currentBaseUri,
        e.value,
        (typeIri) => _getTypeQName(typeIri, namespaces),
      );
    }
    return result;
  }

  /// Gets a QName for a type IRI with caching for better performance
  String? _getTypeQName(IriTerm typeIri, Map<String, String> namespaces) {
    final nsKey = namespaces.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');

    // Initialize cache for this namespace set if needed
    _typeQNameCache[typeIri] ??= {};

    // Check cache
    if (_typeQNameCache[typeIri]!.containsKey(nsKey)) {
      return _typeQNameCache[typeIri]![nsKey];
    }

    // Compute and cache
    final result = _namespaceManager.iriToQName(typeIri.iri, namespaces);
    _typeQNameCache[typeIri]![nsKey] = result;

    return result;
  }

  /// Serializes a subject group as an XML element
  ///
  /// Creates an element for the subject and adds nested elements for predicates.
  void _serializeSubject(
    XmlBuilder builder,
    _SubjectGroup subjectGroup,
    Map<String, String> namespaces,
  ) {
    // Element name: if we have a type info, use it, otherwise use rdf:Description
    final elementName = subjectGroup.qname ?? 'rdf:Description';
    final typeIri = subjectGroup.typeIri;
    final subject = subjectGroup.subject;
    final triples = subjectGroup.triples;

    // Start element for this subject
    builder.element(
      elementName,
      nest: () {
        // Add subject identification
        switch (subject) {
          case IriTerm _:
            builder.attribute('rdf:about', subject.iri);
          case BlankNodeTerm _:
            builder.attribute(
              'rdf:nodeID',
              'blank${identityHashCode(subject)}',
            );
        }

        // Add all predicates except the type that's already encoded in the element name
        for (final triple in triples) {
          if (typeIri != null &&
              triple.predicate == RdfTerms.type &&
              triple.object == typeIri) {
            continue; // Skip the type triple that's already encoded in the element name
          }

          _serializePredicate(
            builder,
            subjectGroup,
            triple.predicate,
            triple.object,
            namespaces,
          );
        }
      },
    );
  }

  /// Serializes a predicate-object pair as an XML element
  ///
  /// Creates a child element for the predicate with appropriate handling
  /// for the object value based on its type.
  void _serializePredicate(
    XmlBuilder builder,
    _SubjectGroup subjectGroup,
    RdfPredicate predicate,
    RdfObject object,
    Map<String, String> namespaces,
  ) {
    final iri = (predicate as IriTerm).iri;
    // Get QName for predicate if possible
    final predicateQName = _namespaceManager.iriToQName(iri, namespaces);
    if (predicateQName == null) {
      throw RdfSerializerException(
        "Could not create a qname for ${iri} and known prefixes ${namespaces.keys}}",
        format: "rdf/xml",
      );
    }

    // Check if this predicate-object pair is reified
    final statementSignature = _getStatementKey(
      subjectGroup.subject,
      predicate,
      object,
    );
    final reificationInfo = _reifiedStatementsMap[statementSignature];
    // Note: the localId is handled here, the other triples will be handled as
    // a normal SubjectNode
    final localId = reificationInfo?.localId;

    // Handle different object types
    switch (object) {
      case IriTerm _:
        // Resource reference
        builder.element(
          predicateQName,
          attributes: {
            'rdf:resource': object.iri,
            if (localId != null) 'rdf:ID': localId,
          },
        );
      case BlankNodeTerm _:
        // Check if this blank node represents a container (Bag, Seq, Alt)
        var containerGroup = _currentSubjectGroups[object];
        if (containerGroup != null && containerGroup.isContainerType) {
          // This is a container, serialize it with proper container syntax
          _serializeContainer(
            builder,
            predicateQName,
            localId,
            object,
            containerGroup.containerType!,
            namespaces,
          );
        } else {
          // Regular blank node reference
          builder.element(
            predicateQName,
            attributes: {
              if (localId != null) 'rdf:ID': localId,
              'rdf:nodeID': 'blank${identityHashCode(object)}',
            },
          );
        }
      case LiteralTerm _:
        // Literal value
        final attributes = <String, String>{
          if (localId != null) 'rdf:ID': localId,
        };

        // Handle language tag or datatype
        if (object.language != null) {
          attributes['xml:lang'] = object.language!;
        } else if (object.datatype.iri != RdfTerms.string.iri) {
          attributes['rdf:datatype'] = object.datatype.iri;
        }

        builder.element(
          predicateQName,
          attributes: attributes,
          nest: object.value,
        );
    }
  }

  /// Serializes an RDF container
  ///
  /// Creates container element with proper container syntax for Bag, Seq, or Alt.
  void _serializeContainer(
    XmlBuilder builder,
    String predicateQName,
    String? localId,
    BlankNodeTerm containerNode,
    String containerType,
    Map<String, String> namespaces,
  ) {
    // Get container triples
    final containerGroup = _currentSubjectGroups[containerNode];
    if (containerGroup == null) {
      // Fallback to simple reference if no container details available
      builder.element(
        predicateQName,
        attributes: {
          if (localId != null) 'rdf:ID': localId,
          'rdf:nodeID': 'blank${identityHashCode(containerNode)}',
        },
      );
      return;
    }

    // Extract and sort container items by their index
    final containerItems = <int, Triple>{};

    for (final triple in containerGroup.triples) {
      if (triple.predicate is IriTerm) {
        final predIri = (triple.predicate as IriTerm).iri;

        // Check if this is a container item predicate (rdf:_1, rdf:_2, etc.)
        if (predIri.startsWith('${RdfTerms.rdfNamespace}_')) {
          try {
            final indexStr = predIri.substring(
              '${RdfTerms.rdfNamespace}_'.length,
            );
            final index = int.parse(indexStr);
            containerItems[index] = triple;
          } catch (_) {
            // Skip invalid indices
          }
        }
      }
    }

    // Only create container element if we have items
    builder.element(
      predicateQName,
      attributes: {if (localId != null) 'rdf:ID': localId},
      nest: () {
        // Create the container element (rdf:Bag, rdf:Seq, or rdf:Alt)
        builder.element(
          'rdf:$containerType',
          nest: () {
            // Sort by index and add container items
            final sortedIndices = containerItems.keys.toList()..sort();

            for (final index in sortedIndices) {
              final triple = containerItems[index]!;

              // Add as rdf:li element
              builder.element(
                'rdf:li',
                nest: () {
                  switch (triple.object) {
                    case IriTerm _:
                      // Resource reference
                      builder.attribute(
                        'rdf:resource',
                        (triple.object as IriTerm).iri,
                      );
                    case BlankNodeTerm _:
                      // Blank node reference
                      builder.attribute(
                        'rdf:nodeID',
                        'blank${identityHashCode(triple.object)}',
                      );
                    case LiteralTerm _:
                      // Literal value
                      final literal = triple.object as LiteralTerm;

                      // Add language or datatype if needed
                      if (literal.language != null) {
                        builder.attribute('xml:lang', literal.language!);
                      } else if (literal.datatype.iri != RdfTerms.string.iri) {
                        builder.attribute('rdf:datatype', literal.datatype.iri);
                      }

                      // Add the value
                      builder.text(literal.value);
                  }
                },
              );
            }
          },
        );
      },
    );
  }
}

/// Helper class to store type information for subjects
///
/// Used to cache type-related data for more efficient serialization.
class _TypeInfo {
  /// The type IRI term
  final IriTerm iri;

  /// The QName for the type
  final String qname;

  /// Creates a new type info object
  const _TypeInfo(this.iri, this.qname);
}

/// Helper class to store reification information
///
/// Used to track reification statements and their original triples.
class _ReificationInfo {
  /// The URI of the reification statement
  final String localId;

  /// The original triple subject
  final RdfSubject subject;

  /// The original triple predicate
  final RdfPredicate predicate;

  /// The original triple object
  final RdfObject object;

  /// Creates a new reification info object
  const _ReificationInfo({
    required this.localId,
    required this.subject,
    required this.predicate,
    required this.object,
  });
}
