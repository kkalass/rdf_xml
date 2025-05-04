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
final class DefaultNamespaceManager implements INamespaceManager {
  /// Namespace mappings registry
  final RdfNamespaceMappings _namespaceMappings;

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

    // Extract namespaces from IRI terms in the graph
    for (final triple in graph.triples) {
      _extractNamespace(triple.subject, result);
      _extractNamespace(triple.predicate, result);
      _extractNamespace(triple.object, result);
    }

    return result;
  }

  @override
  String? iriToQName(String iri, Map<String, String> namespaces) {
    for (final entry in namespaces.entries) {
      final prefix = entry.key;
      final namespace = entry.value;

      if (iri.startsWith(namespace)) {
        final localName = iri.substring(namespace.length);
        // Ensure the local name is a valid XML name
        if (_isValidXmlName(localName) && localName.isNotEmpty) {
          return '$prefix:$localName';
        }
      }
    }

    return null;
  }

  /// Extracts namespace from an RDF term if it's an IRI
  ///
  /// Helper method to find namespaces used in the graph data.
  /// This helps to generate compact QNames where possible.
  void _extractNamespace(RdfTerm term, Map<String, String> namespaces) {
    if (term is! IriTerm) {
      return;
    }

    final iri = term.iri;

    // Skip if this is an already known namespace
    if (namespaces.containsValue(iri)) {
      return;
    }

    // Try to extract a namespace
    final lastHash = iri.lastIndexOf('#');
    final lastSlash = iri.lastIndexOf('/');

    final nsEnd =
        lastHash > 0
            ? lastHash + 1
            : lastSlash > 0
            ? lastSlash + 1
            : -1;

    if (nsEnd > 0) {
      final namespace = iri.substring(0, nsEnd);

      // Skip if namespace already registered
      if (namespaces.containsValue(namespace)) {
        return;
      }

      // Find prefix for this namespace if available
      final mappingsMap = _namespaceMappings.asMap();
      for (final entry in mappingsMap.entries) {
        if (entry.value == namespace) {
          namespaces[entry.key] = namespace;
          return;
        }
      }

      // If we get here, it's a new namespace not in our mappings
      // Generate a new prefix
      int prefixNum = 1;
      String prefix;
      do {
        prefix = 'ns$prefixNum';
        prefixNum++;
      } while (namespaces.containsKey(prefix));

      namespaces[prefix] = namespace;
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
final class DefaultRdfXmlBuilder implements IRdfXmlBuilder {
  /// Namespace manager for handling namespace declarations and QName conversions
  final INamespaceManager _namespaceManager;

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

        // Serialize each subject group
        for (final entry in subjectGroups.entries) {
          _serializeSubject(builder, entry.key, entry.value, namespaces);
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
      if (!result.containsKey(triple.subject)) {
        result[triple.subject] = [];
      }
      result[triple.subject]!.add(triple);
    }

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
  ) {
    // Check for rdf:type triples to potentially use as element name
    final typeTriples =
        triples
            .where(
              (t) =>
                  t.predicate is IriTerm &&
                  (t.predicate as IriTerm).iri == RdfTerms.type.iri,
            )
            .toList();

    // Element name: if we have a single type, use it, otherwise use rdf:Description
    String elementName = 'rdf:Description';
    IriTerm? typeIri;

    if (typeTriples.length == 1 && typeTriples[0].object is IriTerm) {
      typeIri = typeTriples[0].object as IriTerm;
      final qname = _namespaceManager.iriToQName(typeIri.iri, namespaces);
      if (qname != null) {
        elementName = qname;
      }
    }

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
