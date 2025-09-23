/// Default implementations of RDF/XML serialization interfaces
///
/// Provides concrete implementations of the serialization interfaces
/// defined in the interfaces directory.
library rdfxml.serialization.implementations;

import 'dart:math';

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import '../configuration.dart';
import '../interfaces/serialization.dart';
import '../rdfxml_constants.dart';

final _logger = Logger('rdf.serializer.rdfxml');

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

/// Information about a RDF Collection
///
/// Used to track RDF collection items for serialization.
class _CollectionInfo {
  /// The items in the collection in order
  final List<RdfObject> items;
  final List<BlankNodeTerm> nodeChain;

  /// Creates a new RDF collection info
  const _CollectionInfo({required this.items, required this.nodeChain});
}

final class _SubjectGroup {
  final RdfSubject subject;
  final String? _baseUrl;
  final RdfGraph _graph;
  List<IriTerm>? _types;
  late String? qname;
  _ReificationInfo? _reificationInfo;
  bool? _isReification;
  bool? _isCollectionNode;
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

  RdfObject? get collectionFirst {
    if (subject is BlankNodeTerm) {
      final predicates = _graph.findTriples(predicate: RdfTerms.first);
      if (predicates.length != 1) {
        return null;
      }
      return predicates.first.object;
    }
    return null;
  }

  RdfObject? get collectionRest {
    if (subject is BlankNodeTerm) {
      final rest = _graph.findTriples(predicate: RdfTerms.rest);
      if (rest.length != 1) {
        return null;
      }
      return rest.first.object;
    }
    return null;
  }

  bool get isCollectionNode {
    if (_isCollectionNode == null) {
      _isCollectionNode =
          subject is BlankNodeTerm &&
          length == 2 &&
          collectionFirst != null &&
          collectionRest != null;
    }
    return _isCollectionNode!;
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
      final subjects = property(RdfTerms.subject);

      // Extract predicate component
      final predicates = property(RdfTerms.predicate);

      // Extract object component
      final objects = property(RdfTerms.object);

      // Complete reification requires all three components
      if (statementIri is IriTerm &&
          subjects.length == 1 &&
          predicates.length == 1 &&
          objects.length == 1) {
        final s = subjects[0] as RdfSubject;
        final p = predicates[0] as RdfPredicate;
        final o = objects[0];

        var baseUri = _baseUrl;

        // Only use rdf:ID if:
        // 1. We have a base URI
        // 2. The reification URI starts with baseUri# pattern
        final canUseRdfId =
            baseUri != null &&
            baseUri.isNotEmpty &&
            statementIri.value.startsWith('$baseUri#');

        if (canUseRdfId) {
          // Extract the local ID from the URI (part after #)
          final localId = statementIri.value.substring(
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

  int get length => _graph.triples.length;

  List<Triple> findTriples({RdfPredicate? predicate, RdfObject? object}) {
    return _graph.findTriples(predicate: predicate, object: object).toList();
  }

  List<RdfObject> property(RdfPredicate predicate) {
    return _graph
        .findTriples(predicate: predicate)
        .map((t) => t.object)
        .toList();
  }
}

/// Default implementation of IRdfXmlBuilder
///
/// Builds XML documents from RDF graphs for serialization.
/// Includes performance optimizations for handling large datasets.
final class DefaultRdfXmlBuilder implements IRdfXmlBuilder {
  /// Current base URI for the document being serialized
  String? _currentBaseUri;

  /// Creates a new DefaultRdfXmlBuilder
  ///
  DefaultRdfXmlBuilder();

  /// Current mapping of subject to triples for the current serialization
  /// Initialized in buildDocument
  var _currentSubjectGroups = <RdfSubject, _SubjectGroup>{};

  /// Maps from statement signature (subject+predicate+object) to statement URI
  var _reifiedStatementsMap = <String, _ReificationInfo>{};

  /// Map from blank node to collection info
  var _collectionsMap = <BlankNodeTerm, _CollectionInfo>{};
  var _collectionChainNodes = <BlankNodeTerm>{};

  var _blankNodeReferences = <BlankNodeTerm, List<RdfSubject>>{};

  /// Builds an XML document from an RDF graph
  ///
  /// Creates a complete XML representation of the given RDF data.
  @override
  XmlDocument buildDocument(
    RdfGraph graph,
    String? baseUri,
    IriCompactionResult iriCompaction,
    RdfXmlEncoderOptions options,
  ) {
    // Store the base URI for use in reification
    _currentBaseUri = baseUri;

    final builder = XmlBuilder();

    // Add XML declaration
    builder.declaration(version: '1.0', encoding: 'UTF-8');

    // Group triples by subject for more compact output
    _currentSubjectGroups = _groupTriplesBySubject(graph, iriCompaction);

    // Detect reification patterns in the graph
    _reifiedStatementsMap = _identifyReificationPatterns(_currentSubjectGroups);

    // Detect RDF collections in the graph
    _collectionsMap = _identifyCollectionPatterns();
    _collectionChainNodes =
        _collectionsMap.values.expand((col) => col.nodeChain).toSet();

    _blankNodeReferences = identifyBlankNodeReferences(graph);

    // Track blank nodes that are serialized as nested resources
    final processedBlankNodes = <BlankNodeTerm>{};

    // Start rdf:RDF element
    builder.element(
      'rdf:RDF',
      nest: () {
        // Add namespace declarations
        final namespaces = iriCompaction.prefixes.entries.where(
          (e) => e.key != 'rdf',
        );
        builder.attribute('xmlns:rdf', RdfTerms.rdfNamespace);
        for (final entry in namespaces) {
          builder.attribute('xmlns:${entry.key}', entry.value);
        }

        // Add base URI if provided and option is enabled
        if (baseUri != null &&
            baseUri.isNotEmpty &&
            options.includeBaseDeclaration) {
          builder.attribute('xml:base', baseUri);
        }

        // Serialize each subject group, except containers that will be nested and
        // blank nodes that will be serialized inline
        for (final sg in _currentSubjectGroups.values) {
          // Skip nodes that will be nested
          if (sg.isContainerType) {
            continue;
          }

          // Skip all blank nodes in first pass
          if (sg.subject is BlankNodeTerm) {
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
                iriCompaction,
                processedBlankNodes,
              );
            }
            continue;
          }

          _serializeSubject(builder, sg, iriCompaction, processedBlankNodes);
        }

        // Second pass: serialize  nodes that were not processed inline
        for (final sg in _currentSubjectGroups.values) {
          // process blank nodes that were not already processed as nested resources
          if (sg.subject is BlankNodeTerm &&
              !processedBlankNodes.contains(sg.subject)) {
            _serializeSubject(builder, sg, iriCompaction, processedBlankNodes);
          }
        }
      },
    );

    return builder.buildDocument();
  }

  Map<BlankNodeTerm, List<RdfSubject>> identifyBlankNodeReferences(
    RdfGraph graph,
  ) {
    var result = <BlankNodeTerm, List<RdfSubject>>{};
    for (var triple in graph.triples) {
      if (triple.object is BlankNodeTerm) {
        result
            .putIfAbsent(triple.object as BlankNodeTerm, () => [])
            .add(triple.subject);
      }
    }
    return result;
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
    IriCompactionResult iriCompaction,
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
        (typeIri) => _getTypeQName(typeIri, iriCompaction),
      );
    }
    return result;
  }

  /// Gets a QName for a type IRI with caching for better performance
  String? _getTypeQName(IriTerm typeIri, IriCompactionResult iriCompaction) {
    final compacted = iriCompaction.compactIri(typeIri, IriRole.type);
    return _toQName(compacted, typeIri);
  }

  String _toQName(CompactIri? compacted, IriTerm typeIri) {
    return switch (compacted) {
      PrefixedIri(prefix: var prefix, localPart: var localPart) =>
        '$prefix:$localPart',
      null => throw ArgumentError('Unknown IRI compacted form for $typeIri'),
      _ =>
        throw ArgumentError(
          'QName required - must be PrefixedIri - the other types are illegal $typeIri - $compacted. Check the compaction settings.',
        ),
    };
  }

  Map<BlankNodeTerm, String> _blankNodeIds = {};
  String _blankNodeId(BlankNodeTerm node) =>
      _blankNodeIds.putIfAbsent(node, () => 'b${_blankNodeIds.length + 1}');

  /// Serializes a subject group as an XML element
  ///
  /// Creates an element for the subject and adds nested elements for predicates.
  void _serializeSubject(
    XmlBuilder builder,
    _SubjectGroup subjectGroup,
    IriCompactionResult iriCompaction,
    Set<BlankNodeTerm> processedBlankNodes, {
    bool suppressNodeId = false,
  }) {
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
            builder.attribute(
              'rdf:about',
              _getResourceReference(subject, IriRole.subject, iriCompaction),
            );
          case BlankNodeTerm _:
            if (!suppressNodeId) {
              builder.attribute('rdf:nodeID', _blankNodeId(subject));
            }
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
            iriCompaction,
            processedBlankNodes,
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
    IriCompactionResult iriCompaction,
    Set<BlankNodeTerm> processedBlankNodes,
  ) {
    final iri = predicate as IriTerm;
    // Get QName for predicate if possible
    final compacted = iriCompaction.compactIri(iri, IriRole.predicate);
    final String predicateQName;
    try {
      predicateQName = _toQName(compacted, iri);
    } catch (e) {
      throw RdfEncoderException(
        "Could not create a qname for ${iri} and known prefixes ${iriCompaction.prefixes.keys}",
        format: "rdf/xml",
        cause: e,
      );
    }

    // Check if this predicate-object pair is reified
    String? localId = getLocalId(subjectGroup.subject, predicate, object);

    // Handle different object types
    switch (object) {
      case IriTerm _:
        builder.element(
          predicateQName,
          attributes: {
            'rdf:resource': _getResourceReference(
              object,
              predicate == RdfTerms.type ? IriRole.type : IriRole.object,
              iriCompaction,
            ),
            if (localId != null) 'rdf:ID': localId,
          },
        );
      case BlankNodeTerm _:

        // Check if this blank node is a container or a typed node with properties
        var containerGroup = _currentSubjectGroups[object];
        if (containerGroup != null && containerGroup.isContainerType) {
          // This is a container, serialize it with proper container syntax
          _serializeContainer(
            builder,
            predicateQName,
            localId,
            object,
            containerGroup.containerType!,
            iriCompaction,
            processedBlankNodes,
          );
        } else if (_collectionsMap.containsKey(object)) {
          // Check if the object is the start of a collection
          _serializeCollection(
            builder,
            predicateQName,
            localId,
            object,
            iriCompaction,
            processedBlankNodes,
          );
        } else if (_collectionChainNodes.contains(object)) {
          // skip - this should not be referenced here and be rendered as part of a collection anyways
          // This node is part of a collection chain and should not be serialized separately
          _logger.warning(
            'Found collection chain node $object referenced directly. '
            'This should be handled as part of a collection.',
          );
          _buildBlankNodeReference(
            builder,
            predicateQName,
            object,
            localId: localId,
          );
        } else {
          // If there is only the subject of this triple referencing
          // this blank node, then we can fully inline it and suppress its id
          // else we rather just render a reference
          var canNestBlankNode =
              _blankNodeReferences[object]?.length == 1 &&
              _blankNodeReferences[object]![0] == subjectGroup.subject &&
              containerGroup != null &&
              containerGroup.typeIri != null;
          if (canNestBlankNode) {
            // Nested Regular blank node subject
            builder.element(
              predicateQName,
              attributes: {
                if (localId != null) 'rdf:ID': localId,
                // rdf:nodeID is not needed here, as we will serialize the blank node inline
              },
              nest: () {
                // Make sure it will not be rendered again
                processedBlankNodes.add(object);
                _serializeSubject(
                  builder,
                  containerGroup,
                  iriCompaction,
                  processedBlankNodes,
                  suppressNodeId: true,
                );
              },
            );
          } else {
            // Fallback to simple reference if no container details available
            _buildBlankNodeReference(
              builder,
              predicateQName,
              object,
              localId: localId,
            );
          }
        }
      case LiteralTerm literal:
        _buildLiteralTerm(builder, predicateQName, localId, literal);
    }
  }

  String? getLocalId(
    RdfSubject subject,
    RdfPredicate predicate,
    RdfObject object,
  ) {
    final statementSignature = _getStatementKey(subject, predicate, object);
    final reificationInfo = _reifiedStatementsMap[statementSignature];
    // Note: the localId is handled here, the other triples will be handled as
    // a normal SubjectNode
    final localId = reificationInfo?.localId;
    return localId;
  }

  void _buildLiteralTerm(
    XmlBuilder builder,
    String qName,
    String? localId,
    LiteralTerm literal,
  ) {
    builder.element(
      qName,
      attributes: {
        if (localId != null) 'rdf:ID': localId,
        if (literal.datatype != RdfTerms.string &&
            literal.datatype != RdfTerms.langString)
          'rdf:datatype': literal.datatype.value,
        if (literal.language != null) 'xml:lang': literal.language!,
      },
      nest: literal.value,
    );
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
    IriCompactionResult iriCompaction,
    Set<BlankNodeTerm> processedBlankNodes,
  ) {
    // Get container triples
    final containerGroup = _currentSubjectGroups[containerNode];
    if (containerGroup == null) {
      // Fallback to simple reference if no container details available
      _buildBlankNodeReference(
        builder,
        predicateQName,
        containerNode,
        localId: localId,
      );
      return;
    }

    // Extract and sort container items by their index
    final containerItems = <int, Triple>{};
    final notHandledTriples = <Triple>[];
    for (final triple in containerGroup.triples) {
      if (triple.predicate is IriTerm) {
        final predIri = (triple.predicate as IriTerm).value;

        // Check if this is a container item predicate (rdf:_1, rdf:_2, etc.)
        if (predIri.startsWith('${RdfTerms.rdfNamespace}_')) {
          try {
            final indexStr = predIri.substring(
              '${RdfTerms.rdfNamespace}_'.length,
            );
            final index = int.parse(indexStr);
            containerItems[index] = triple;
          } catch (e) {
            // Log warning for invalid indices
            _logger.warning('Invalid container item index in $predIri: $e');
            notHandledTriples.add(triple);
          }
        } else if (triple.predicate == RdfTerms.type &&
            triple.object == containerGroup.typeIri) {
          // Ignore type triple, this will be handled by the element name
          // through the containerType
        } else {
          notHandledTriples.add(triple);
        }
      } else {
        // Not a valid container item predicate
        notHandledTriples.add(triple);
      }
    }

    if (notHandledTriples.isNotEmpty) {
      // lets rather skip this and just use a reference - this does not look
      // like a consistent and valid container
      _buildBlankNodeReference(
        builder,
        predicateQName,
        containerNode,
        localId: localId,
      );
      return;
    }

    processedBlankNodes.add(containerNode);
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
              final qName = 'rdf:li';
              // Add as rdf:li element
              switch (triple.object) {
                case IriTerm iri:
                  builder.element(
                    qName,
                    attributes: {
                      'rdf:resource': _getResourceReference(
                        iri,
                        IriRole.object,
                        iriCompaction,
                      ),
                    },
                  );
                case BlankNodeTerm blankNodeTerm:
                  // Blank node reference
                  _buildBlankNodeReference(builder, qName, blankNodeTerm);
                case LiteralTerm literal:
                  _buildLiteralTerm(builder, qName, null, literal);
              }
            }
          },
        );
      },
    );
  }

  void _buildBlankNodeReference(
    XmlBuilder builder,
    String predicateQName,
    BlankNodeTerm containerNode, {
    String? localId,
  }) {
    builder.element(
      predicateQName,
      attributes: {
        if (localId != null) 'rdf:ID': localId,
        'rdf:nodeID': _blankNodeId(containerNode),
      },
    );
  }

  /// Serializes an RDF collection
  ///
  /// Creates an XML element with rdf:parseType="Collection" that represents the
  /// collection in a more compact and readable form than the triple representation
  void _serializeCollection(
    XmlBuilder builder,
    String predicateQName,
    String? localId,
    BlankNodeTerm collectionNode,
    IriCompactionResult iriCompaction,
    Set<BlankNodeTerm> processedBlankNodes,
  ) {
    // Get collection info
    final collectionInfo = _collectionsMap[collectionNode];
    if (collectionInfo == null) {
      // Fallback to simple reference if no collection details available
      _buildBlankNodeReference(
        builder,
        predicateQName,
        collectionNode,
        localId: localId,
      );
      return;
    }

    // Mark all collection nodes as processed so they won't be serialized at top level
    processedBlankNodes.addAll(collectionInfo.nodeChain);

    // Create collection element with parseType="Collection"
    builder.element(
      predicateQName,
      attributes: {
        'rdf:parseType': 'Collection',
        if (localId != null) 'rdf:ID': localId,
      },
      nest: () {
        // Add each item in the collection
        for (final item in collectionInfo.items) {
          switch (item) {
            case IriTerm _:
              // Resource reference
              builder.element(
                'rdf:Description',
                attributes: {
                  'rdf:about': _getResourceReference(
                    item,
                    IriRole.object,
                    iriCompaction,
                  ),
                },
              );
            case BlankNodeTerm blankNode:
              // Check if this is a typed node
              final nodeGroup = _currentSubjectGroups[blankNode];

              if (nodeGroup == null) {
                throw RdfEncoderException(
                  'Blank node $blankNode not found in subject groups.',
                  format: "rdf/xml",
                );
              }
              // Mark as processed
              processedBlankNodes.add(blankNode);
              _serializeSubject(
                builder,
                nodeGroup,
                iriCompaction,
                processedBlankNodes,
              );

            case LiteralTerm literal:
              // Handle literal in collection directly
              _buildLiteralTerm(builder, 'rdf:Description', null, literal);
          }
        }
      },
    );
  }

  String _getResourceReference(
    IriTerm item,
    IriRole role,
    IriCompactionResult iriCompaction,
  ) {
    final compacted = iriCompaction.compactIri(item, role);
    return switch (compacted) {
      PrefixedIri(prefix: var prefix, localPart: var localPart) =>
        '$prefix:$localPart',
      RelativeIri(relative: var relative) => relative,
      FullIri(iri: var iri) => iri,
      SpecialIri(iri: var iri) => () {
        _logger.warning(
          'WARNING: Special IRI $iri used in serialization. '
          'This either means that a special treatment was not applied, or an IRI was configured as special which is not so special at all.',
        );
        return iri.value;
      }(),
    };
  }

  List<BlankNodeTerm>? _buildCollectionChain(
    Set<BlankNodeTerm> processedChains,
    BlankNodeTerm startNode,
  ) {
    // Initial chain contains just the start node
    var currentChain = <BlankNodeTerm>[startNode];
    var currentNode = startNode;

    // Follow the rdf:rest chain to build the complete list of nodes
    while (true) {
      // Mark this node as processed
      processedChains.add(currentNode);

      // Get the rest value for this node
      final group = _currentSubjectGroups[currentNode];
      if (group == null) {
        _logger.warning(
          'WARNING: Collection node $currentNode not found in subject groups. Chain may be incomplete.',
        );
        return null;
      }

      final rest = group.collectionRest;
      if (rest == null) {
        _logger.warning(
          'WARNING: Collection node $currentNode has no rdf:rest property. Chain is incomplete.',
        );
        return null;
      }

      // Avoid circular references
      if (processedChains.contains(rest)) {
        _logger.warning(
          'WARNING: Circular reference detected in collection chain at node $currentNode -> $rest. Aborting chain.',
        );
        return null;
      }

      if (rest == RdfTerms.nil) {
        // Valid end of collection
        return currentChain;
      } else if (rest is BlankNodeTerm &&
          _currentSubjectGroups.containsKey(rest) &&
          _currentSubjectGroups[rest]!.isCollectionNode) {
        // Continue the chain
        currentNode = rest;
        currentChain.add(rest);
      } else {
        // Invalid chain - not a proper collection structure
        _logger.warning(
          'WARNING: Invalid collection structure detected at node $currentNode. '
          'The rdf:rest value $rest is not a recognized collection node or rdf:nil.',
        );
        return null;
      }
    }
  }

  /// Identifies collections in the RDF graph
  ///
  /// Detects patterns of rdf:first/rdf:rest/rdf:nil that represent RDF collections
  /// and stores them for efficient serialization with rdf:parseType="Collection"
  Map<BlankNodeTerm, _CollectionInfo> _identifyCollectionPatterns() {
    // Map of blank nodes to collection info
    final result = <BlankNodeTerm, _CollectionInfo>{};

    // Step 1: Identify all blank nodes that have rdf:first and rdf:rest properties
    // These are potential collection nodes
    final collectionGroups =
        _currentSubjectGroups.values
            .where((sg) => sg.isCollectionNode)
            .toList();
    final nonStartTerms =
        collectionGroups.map((sg) => sg.collectionRest!).toSet();
    final startTerms =
        collectionGroups
            .where((sg) => !nonStartTerms.contains(sg.subject))
            .map((sg) => sg.subject as BlankNodeTerm)
            .toSet();

    // Step 2: Build the complete chains by following rdf:rest links
    final validCollections = <BlankNodeTerm, List<BlankNodeTerm>>{};
    final processedChains = <BlankNodeTerm>{};

    for (final startNode in startTerms) {
      // Skip if already processed
      if (processedChains.contains(startNode)) {
        _logger.warning(
          'WARNING: Collection node $startNode already processed. Possible circular reference.',
        );
        continue;
      }

      var currentChain = _buildCollectionChain(processedChains, startNode);
      if (currentChain != null) {
        validCollections[startNode] = currentChain;
      }
    }

    // Step 3: Extract collection items from each valid chain
    for (final entry in validCollections.entries) {
      final startNode = entry.key;
      final nodeChain = entry.value;

      // Extract items from each node in order
      final collectionItems = <RdfObject>[];

      for (final node in nodeChain) {
        final group = _currentSubjectGroups[node]!;
        final first = group.collectionFirst!;
        // Add the item
        collectionItems.add(first);
      }

      // Create collection info
      result[startNode] = _CollectionInfo(
        items: collectionItems,
        nodeChain: nodeChain,
      );
    }

    return result;
  }
}
