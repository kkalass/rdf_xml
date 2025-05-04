/// Default implementations of RDF/XML serialization interfaces
///
/// Provides concrete implementations of the serialization interfaces
/// defined in the interfaces directory.
library rdfxml.serialization.implementations;

import 'package:rdf_core/rdf_core.dart';
import 'package:xml/xml.dart';

import '../interfaces/serialization.dart';
import '../rdfxml_constants.dart';

/// Default implementation of INamespaceManager
///
/// Manages namespaces and QName conversions for RDF/XML serialization.
/// Includes caching and optimized algorithms for better performance with large documents.
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
    // Start with standard namespaces
    final result = Map<String, String>.from(RdfTerms.standardNamespaces);

    // Add custom prefix mappings (overrides standard namespaces)
    result.addAll(customPrefixes);

    // Optimize by using a Set to track processed IRIs
    final processedIris = <String>{};

    // Extract namespaces from IRI terms in the graph
    for (final triple in graph.triples) {
      _extractNamespaceFromTerm(triple.subject, result, processedIris);
      _extractNamespaceFromTerm(triple.predicate, result, processedIris);
      _extractNamespaceFromTerm(triple.object, result, processedIris);
    }

    return result;
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

  /// Creates a new DefaultRdfXmlBuilder
  ///
  /// Parameters:
  /// - [namespaceManager] Namespace manager for handling namespace operations
  const DefaultRdfXmlBuilder({INamespaceManager? namespaceManager})
    : _namespaceManager = namespaceManager ?? const DefaultNamespaceManager();

  @override
  XmlDocument buildDocument(
    RdfGraph graph,
    String? baseUri,
    Map<String, String> namespaces,
  ) {
    final builder = XmlBuilder();

    // Add XML declaration
    builder.declaration(version: '1.0', encoding: 'UTF-8');

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

        // Group triples by subject for more compact output
        final subjectGroups = _groupTriplesBySubject(graph);

        // Pre-compute type information for better performance
        final subjectTypeMap = _precomputeSubjectTypes(
          subjectGroups,
          namespaces,
        );

        // Serialize each subject group
        for (final entry in subjectGroups.entries) {
          _serializeSubject(
            builder,
            entry.key,
            entry.value,
            namespaces,
            subjectTypeMap[entry.key],
          );
        }
      },
    );

    return builder.buildDocument();
  }

  /// Groups triples by subject to prepare for more compact serialization
  ///
  /// This is a key optimization for RDF/XML output, as it allows
  /// nesting multiple predicates under a single subject.
  Map<RdfSubject, List<Triple>> _groupTriplesBySubject(RdfGraph graph) {
    final result = <RdfSubject, List<Triple>>{};

    for (final triple in graph.triples) {
      result.putIfAbsent(triple.subject, () => []).add(triple);
    }

    return result;
  }

  /// Pre-computes type information for all subjects
  ///
  /// This avoids repeated lookups and improves performance for large datasets.
  Map<RdfSubject, _TypeInfo?> _precomputeSubjectTypes(
    Map<RdfSubject, List<Triple>> subjectGroups,
    Map<String, String> namespaces,
  ) {
    final result = <RdfSubject, _TypeInfo?>{};

    for (final entry in subjectGroups.entries) {
      final subject = entry.key;
      final triples = entry.value;

      // Find rdf:type triples
      final typeTriples =
          triples
              .where(
                (t) =>
                    t.predicate is IriTerm &&
                    (t.predicate as IriTerm).iri == RdfTerms.type.iri &&
                    t.object is IriTerm,
              )
              .toList();

      if (typeTriples.length == 1) {
        final typeIri = typeTriples[0].object as IriTerm;
        final qname = _getTypeQName(typeIri, namespaces);

        if (qname != null) {
          result[subject] = _TypeInfo(typeIri, qname);
        }
      }
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
    RdfSubject subject,
    List<Triple> triples,
    Map<String, String> namespaces,
    _TypeInfo? typeInfo,
  ) {
    // Element name: if we have a type info, use it, otherwise use rdf:Description
    final elementName = typeInfo?.qname ?? 'rdf:Description';
    final typeIri = typeInfo?.iri;

    // Start element for this subject
    builder.element(
      elementName,
      nest: () {
        // Add subject identification
        if (subject is IriTerm) {
          builder.attribute('rdf:about', subject.iri);
        } else if (subject is BlankNodeTerm) {
          builder.attribute('rdf:nodeID', 'blank${identityHashCode(subject)}');
        }

        // Add all predicates except the type that's already encoded in the element name
        for (final triple in triples) {
          if (typeIri != null &&
              triple.predicate is IriTerm &&
              (triple.predicate as IriTerm).iri == RdfTerms.type.iri &&
              triple.object == typeIri) {
            continue; // Skip the type triple that's already encoded in the element name
          }

          _serializePredicate(
            builder,
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
    RdfPredicate predicate,
    RdfObject object,
    Map<String, String> namespaces,
  ) {
    if (predicate is! IriTerm) {
      return;
    }

    // Get QName for predicate if possible
    final predicateQName =
        _namespaceManager.iriToQName(predicate.iri, namespaces) ?? 'rdf:value';

    // Handle different object types
    if (object is IriTerm) {
      // Resource reference
      builder.element(predicateQName, attributes: {'rdf:resource': object.iri});
    } else if (object is BlankNodeTerm) {
      // Either nested blank node or reference to existing blank node
      builder.element(
        predicateQName,
        attributes: {'rdf:nodeID': 'blank${identityHashCode(object)}'},
      );
    } else if (object is LiteralTerm) {
      // Literal value
      final attributes = <String, String>{};

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
