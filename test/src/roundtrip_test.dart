import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

final _log = Logger('RDF/XML Roundtrip Test');

void main() {
  group('Roundtrip test', () {
    test('parses and serializes xml correctly', () {
      final xmlContent = '''
    <?xml version="1.0" encoding="UTF-8"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/"
             xmlns:ex="http://example.org/terms#"
             xml:base="http://example.org/data/">
      
      <!-- Resource with multiple properties -->
      <rdf:Description rdf:about="resource1">
        <dc:title>Configuration Example</dc:title>
        <dc:description xml:lang="en">An example showing configuration options</dc:description>
      </rdf:Description>
      
      <!-- Typed node with nested blank node -->
      <ex:Document rdf:about="doc1">
        <ex:author>
          <ex:Person>
            <ex:name>Jane Smith</ex:name>
          </ex:Person>
        </ex:author>
        <ex:lastModified rdf:datatype="http://www.w3.org/2001/XMLSchema#date">2025-05-05</ex:lastModified>
      </ex:Document>
      
      <!-- Container example -->
      <rdf:Description rdf:about="collection1">
        <ex:items>
          <rdf:Bag>
            <rdf:li>Item 1</rdf:li>
            <rdf:li>Item 2</rdf:li>
            <rdf:li>Item 3</rdf:li>
          </rdf:Bag>
        </ex:items>
      </rdf:Description>
    </rdf:RDF>
  ''';

      final parser = RdfXmlParser(xmlContent);
      final triples = parser.parse();
      // Check if the triples contain language information
      // This serves to diagnose the problem
      final langTriples =
          triples.where((t) {
            if (t.object is LiteralTerm) {
              final lit = t.object as LiteralTerm;
              return lit.language != null;
            }
            return false;
          }).toList();
      expect(
        langTriples,
        isNotEmpty,
        reason: 'Language-tagged literals should be present.',
      );
      // Output of all language-tagged literals
      for (final triple in langTriples) {
        final lit = triple.object as LiteralTerm;
        _log.finest(
          'Literal with language tag: ${lit.value} (${lit.language})',
        );
      }

      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(
        RdfGraph.fromTriples(triples),
        baseUri: 'http://example.org/data/',
      );

      // Parse both XML documents for structured comparison
      final originalDoc = XmlDocument.parse(xmlContent);
      final serializedDoc = XmlDocument.parse(serializedXml);

      // Compare documents using detailed analysis
      final differences = compareXmlDocuments(originalDoc, serializedDoc);

      if (differences.isNotEmpty) {
        _log.finest('XML Differences found:');
        for (final diff in differences) {
          _log.finest('- $diff');
        }

        _log.finest('\nOriginal XML:');
        _log.finest(xmlContent);

        _log.finest('\nSerialized XML:');
        _log.finest(serializedXml);

        fail(
          'XML documents are not semantically equivalent. See differences above.',
        );
      }
    });
  });
}

/// Compares two XML documents and returns a list of differences
/// This function performs a semantic comparison, considering the RDF/XML structure
List<String> compareXmlDocuments(XmlDocument original, XmlDocument serialized) {
  final differences = <String>[];

  // Check root element
  final originalRoot = original.rootElement;
  final serializedRoot = serialized.rootElement;

  // Compare root element names
  if (originalRoot.name.qualified != serializedRoot.name.qualified) {
    differences.add(
      'Root element names differ: ${originalRoot.name.qualified} vs ${serializedRoot.name.qualified}',
    );
  }

  // Compare namespaces
  _compareNamespaces(originalRoot, serializedRoot, differences);

  // Compare xml:base attribute
  final originalBase = originalRoot.getAttribute(
    'base',
    namespace: 'http://www.w3.org/XML/1998/namespace',
  );
  final serializedBase = serializedRoot.getAttribute(
    'base',
    namespace: 'http://www.w3.org/XML/1998/namespace',
  );

  if (originalBase != serializedBase) {
    differences.add(
      'xml:base attributes differ: $originalBase vs $serializedBase',
    );
  }

  // Extract and compare top-level nodes by their about/ID attributes
  final originalResources = _extractResourcesByIdentifier(originalRoot);
  final serializedResources = _extractResourcesByIdentifier(serializedRoot);

  // Check for missing resources
  for (final key in originalResources.keys) {
    if (!serializedResources.containsKey(key)) {
      differences.add('Resource missing in serialized output: $key');
    }
  }

  // Check for extra resources
  for (final key in serializedResources.keys) {
    if (!originalResources.containsKey(key)) {
      differences.add('Extra resource in serialized output: $key');
    }
  }

  // Compare resources that exist in both
  for (final key in originalResources.keys.where(
    serializedResources.containsKey,
  )) {
    final originalResource = originalResources[key]!;
    final serializedResource = serializedResources[key]!;

    _compareElements(
      originalResource,
      serializedResource,
      differences,
      context: 'Resource $key',
    );
  }

  return differences;
}

/// Extract resources by their identifier (rdf:about, rdf:ID, or rdf:nodeID)
Map<String, XmlElement> _extractResourcesByIdentifier(XmlElement root) {
  final resources = <String, XmlElement>{};

  for (final child in root.childElements) {
    // Try to get the identifier from various RDF identifier attributes
    String? identifier =
        child.getAttribute(
          'about',
          namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        ) ??
        child.getAttribute(
          'ID',
          namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        ) ??
        child.getAttribute(
          'nodeID',
          namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        );

    if (identifier != null) {
      resources[identifier] = child;
    } else {
      // For elements without an identifier, use their position as a key
      resources['position_${resources.length}'] = child;
    }
  }

  return resources;
}

/// Compare two elements recursively
void _compareElements(
  XmlElement original,
  XmlElement serialized,
  List<String> differences, {
  required String context,
}) {
  // Compare element names
  if (original.name.qualified != serialized.name.qualified) {
    differences.add(
      '$context: Element names differ: ${original.name.qualified} vs ${serialized.name.qualified}',
    );
  }

  // Compare attributes (excluding namespace declarations)
  _compareAttributes(original, serialized, differences, context: context);

  // Extract and compare child elements
  final originalProps = _extractProperties(original);
  final serializedProps = _extractProperties(serialized);

  // Check for missing properties
  for (final key in originalProps.keys) {
    if (!serializedProps.containsKey(key)) {
      differences.add('$context: Property missing in serialized output: $key');
    }
  }

  // Check for extra properties
  for (final key in serializedProps.keys) {
    if (!originalProps.containsKey(key)) {
      differences.add('$context: Extra property in serialized output: $key');
    }
  }

  // Compare properties that exist in both
  for (final key in originalProps.keys.where(serializedProps.containsKey)) {
    final originalProp = originalProps[key]!;
    final serializedProp = serializedProps[key]!;

    _compareProperty(
      originalProp,
      serializedProp,
      differences,
      context: '$context > $key',
    );
  }
}

/// Extract properties by their predicate name (element name)
Map<String, List<XmlElement>> _extractProperties(XmlElement element) {
  final properties = <String, List<XmlElement>>{};

  for (final child in element.childElements) {
    final key = child.name.qualified;
    properties.putIfAbsent(key, () => []).add(child);
  }

  return properties;
}

/// Compare properties (can be multiple with same predicate)
void _compareProperty(
  List<XmlElement> originalProps,
  List<XmlElement> serializedProps,
  List<String> differences, {
  required String context,
}) {
  // Check if property counts match
  if (originalProps.length != serializedProps.length) {
    differences.add(
      '$context: Property count differs: ${originalProps.length} vs ${serializedProps.length}',
    );
    // Continue comparison with available elements
  }

  // Compare properties pairwise (up to the count of the smaller list)
  final count =
      originalProps.length < serializedProps.length
          ? originalProps.length
          : serializedProps.length;

  for (var i = 0; i < count; i++) {
    final originalProp = originalProps[i];
    final serializedProp = serializedProps[i];

    // Check property value (for literal properties)
    if (originalProp.childElements.isEmpty &&
        serializedProp.childElements.isEmpty) {
      if (originalProp.innerText.trim() != serializedProp.innerText.trim()) {
        differences.add(
          '$context[${i + 1}]: Property values differ: "${originalProp.innerText.trim()}" vs "${serializedProp.innerText.trim()}"',
        );
      }

      // Check for language tag (xml:lang)
      final originalLang = originalProp.getAttribute(
        'lang',
        namespace: 'http://www.w3.org/XML/1998/namespace',
      );
      final serializedLang = serializedProp.getAttribute(
        'lang',
        namespace: 'http://www.w3.org/XML/1998/namespace',
      );

      if (originalLang != serializedLang) {
        differences.add(
          '$context[${i + 1}]: Language tags differ: $originalLang vs $serializedLang',
        );
      }

      // Check for datatype
      final originalDatatype = originalProp.getAttribute(
        'datatype',
        namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      );
      final serializedDatatype = serializedProp.getAttribute(
        'datatype',
        namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      );

      if (originalDatatype != serializedDatatype) {
        differences.add(
          '$context[${i + 1}]: Datatypes differ: $originalDatatype vs $serializedDatatype',
        );
      }
    }
    // For resource or nested resource properties, compare recursively
    else {
      // Check for rdf:resource
      final originalResource = originalProp.getAttribute(
        'resource',
        namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      );
      final serializedResource = serializedProp.getAttribute(
        'resource',
        namespace: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      );

      if (originalResource != null && serializedResource != null) {
        // Compare resource references
        if (originalResource != serializedResource) {
          differences.add(
            '$context[${i + 1}]: Resource URIs differ: $originalResource vs $serializedResource',
          );
        }
      }
      // Compare child elements if both have them
      else if (originalProp.childElements.isNotEmpty &&
          serializedProp.childElements.isNotEmpty) {
        // Special handling for containers (Bag, Seq, Alt)
        if (_isRdfContainer(originalProp.childElements.first) &&
            _isRdfContainer(serializedProp.childElements.first)) {
          _compareContainers(
            originalProp.childElements.first,
            serializedProp.childElements.first,
            differences,
            context: '$context[${i + 1}]',
          );
        }
        // For other nested structures
        else {
          _compareElements(
            originalProp.childElements.first,
            serializedProp.childElements.first,
            differences,
            context: '$context[${i + 1}]',
          );
        }
      }
      // Structure mismatch
      else {
        differences.add(
          '$context[${i + 1}]: Structure mismatch - one has child elements, the other doesn\'t',
        );
      }
    }
  }
}

/// Compare container elements (rdf:Bag, rdf:Seq, rdf:Alt)
void _compareContainers(
  XmlElement original,
  XmlElement serialized,
  List<String> differences, {
  required String context,
}) {
  // Check container type
  if (original.name.qualified != serialized.name.qualified) {
    differences.add(
      '$context: Container types differ: ${original.name.qualified} vs ${serialized.name.qualified}',
    );
  }

  // Extract and compare container items
  final originalItems =
      original.childElements.where((e) => e.name.local == 'li').toList();
  final serializedItems =
      serialized.childElements.where((e) => e.name.local == 'li').toList();

  // Check item count
  if (originalItems.length != serializedItems.length) {
    differences.add(
      '$context: Container item count differs: ${originalItems.length} vs ${serializedItems.length}',
    );
  }

  // Compare items pairwise
  final count =
      originalItems.length < serializedItems.length
          ? originalItems.length
          : serializedItems.length;

  for (var i = 0; i < count; i++) {
    if (originalItems[i].innerText.trim() !=
        serializedItems[i].innerText.trim()) {
      differences.add(
        '$context: Container item ${i + 1} values differ: "${originalItems[i].innerText.trim()}" vs "${serializedItems[i].innerText.trim()}"',
      );
    }
  }
}

/// Check if an element is an RDF container (Bag, Seq, Alt)
bool _isRdfContainer(XmlElement element) {
  return element.namespaceUri ==
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#' &&
      (element.localName == 'Bag' ||
          element.localName == 'Seq' ||
          element.localName == 'Alt');
}

/// Compare attributes between elements
void _compareAttributes(
  XmlElement original,
  XmlElement serialized,
  List<String> differences, {
  required String context,
}) {
  // Get all non-namespace attributes
  final originalAttrs =
      original.attributes
          .where((attr) => !attr.name.qualified.startsWith('xmlns:'))
          .toList();
  final serializedAttrs =
      serialized.attributes
          .where((attr) => !attr.name.qualified.startsWith('xmlns:'))
          .toList();

  // Create maps for easier comparison
  final originalAttrMap = {
    for (var attr in originalAttrs) attr.name.qualified: attr.value,
  };
  final serializedAttrMap = {
    for (var attr in serializedAttrs) attr.name.qualified: attr.value,
  };

  // Check for missing attributes
  for (final key in originalAttrMap.keys) {
    if (!serializedAttrMap.containsKey(key)) {
      differences.add(
        '$context: Attribute missing in serialized output: $key="${originalAttrMap[key]}"',
      );
    }
  }

  // Check for extra attributes
  for (final key in serializedAttrMap.keys) {
    if (!originalAttrMap.containsKey(key)) {
      differences.add(
        '$context: Extra attribute in serialized output: $key="${serializedAttrMap[key]}"',
      );
    }
  }

  // Compare attribute values
  for (final key in originalAttrMap.keys.where(serializedAttrMap.containsKey)) {
    if (originalAttrMap[key] != serializedAttrMap[key]) {
      differences.add(
        '$context: Attribute value differs for $key: "${originalAttrMap[key]}" vs "${serializedAttrMap[key]}"',
      );
    }
  }
}

/// Compare namespaces between elements
void _compareNamespaces(
  XmlElement original,
  XmlElement serialized,
  List<String> differences,
) {
  // Extract namespace declarations
  final originalNamespaces = _extractNamespaces(original);
  final serializedNamespaces = _extractNamespaces(serialized);

  // Compare namespace URIs (ignoring prefixes as these can change)
  final originalUris = originalNamespaces.values.toSet();
  final serializedUris = serializedNamespaces.values.toSet();

  // Check for missing namespaces
  for (final uri in originalUris) {
    if (!serializedUris.contains(uri)) {
      differences.add('Namespace URI missing in serialized output: $uri');
    }
  }

  // We don't check for extra namespaces as the serializer might add some
}

/// Extract namespace declarations from an element
Map<String, String> _extractNamespaces(XmlElement element) {
  final namespaces = <String, String>{};

  for (final attr in element.attributes) {
    if (attr.name.prefix == 'xmlns' || attr.name.local == 'xmlns') {
      final prefix = attr.name.prefix == 'xmlns' ? attr.name.local : '';
      namespaces[prefix] = attr.value;
    }
  }

  return namespaces;
}
