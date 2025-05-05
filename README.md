# rdf_xml

[![pub package](https://img.shields.io/pub/v/rdf_xml.svg)](https://pub.dev/packages/rdf_xml)
[![build](https://github.com/kkalass/rdf_xml/actions/workflows/ci.yml/badge.svg)](https://github.com/kkalass/rdf_xml/actions)
[![codecov](https://codecov.io/gh/kkalass/rdf_xml/branch/main/graph/badge.svg)](https://codecov.io/gh/kkalass/rdf_xml)
[![license](https://img.shields.io/github/license/kkalass/rdf_xml.svg)](https://github.com/kkalass/rdf_xml/blob/main/LICENSE)

A high-performance RDF/XML parser and serializer for the [rdf_core](https://pub.dev/packages/rdf_core) library, offering a complete implementation of the W3C RDF/XML specification.

[🌐 **Official Documentation**](https://kkalass.github.io/rdf_xml/)

---

## 📋 Features

- **Complete RDF/XML support** - Full implementation of the W3C RDF/XML standard
- **High performance** - Optimized for both speed and memory efficiency
- **Configurable behavior** - Strict or lenient parsing modes, formatting options
- **Clean architecture** - Follows SOLID principles with dependency injection
- **Extensible design** - Easy to customize and adapt to specific needs
- **Well tested** - Comprehensive test suite with real-world examples

## 🚀 Installation

```bash
dart pub add rdf_xml
```

Or add to your `pubspec.yaml`:

```yaml
dependencies:
  rdf_xml: ^0.1.1
```

## 📖 Usage

### Parsing RDF/XML

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  final xmlContent = '''
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/">
      <rdf:Description rdf:about="http://example.org/resource">
        <dc:title>Example Resource</dc:title>
        <dc:creator>Example Author</dc:creator>
      </rdf:Description>
    </rdf:RDF>
  ''';

  // Create a parser directly
  final parser = RdfXmlFormat().createParser();
  final rdfGraph = parser.parse(xmlContent);
  
  // Print the parsed triples
  for (final triple in rdfGraph.triples) {
    print(triple);
  }
}
```

### Parsing from a File

```dart
import 'dart:io';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

Future<void> parseFromFile(String filePath) async {
  final file = File(filePath);
  final xmlContent = await file.readAsString();
  
  // Parse with base URI set to the file location
  final parser = RdfXmlParser(
    xmlContent, 
    baseUri: 'file://${file.absolute.path}',
  );
  
  final triples = parser.parse();
  final graph = RdfGraph.fromTriples(triples);
  
  print('Parsed ${graph.size} triples from $filePath');
}
```

### Working with Named Graphs

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  final xmlContent = '''
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:foaf="http://xmlns.com/foaf/0.1/">
      <foaf:Person rdf:about="http://example.org/person/alice">
        <foaf:name>Alice</foaf:name>
        <foaf:knows rdf:resource="http://example.org/person/bob"/>
      </foaf:Person>
    </rdf:RDF>
  ''';

  // Parse the content
  final parser = RdfXmlFormat().createParser();
  final graph = parser.parse(xmlContent);
  
  // Create a named graph
  final namedGraph = NamedGraph(
    IriTerm('http://example.org/graphs/people'),
    graph,
  );
  
  // Add to a dataset
  final dataset = RdfDataset.empty();
  dataset.addNamedGraph(namedGraph);
  
  // Query the dataset
  final people = dataset.findByPredicateObject(
    IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
    IriTerm('http://xmlns.com/foaf/0.1/Person'),
  );
  
  for (final person in people) {
    print('Found person: ${person.subject}');
  }
}
```

### Serializing to RDF/XML

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Create a graph with some triples
  final graph = RdfGraph.fromTriples([
    Triple(
      IriTerm('http://example.org/resource'),
      IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Example Resource'),
    ),
    Triple(
      IriTerm('http://example.org/resource'),
      IriTerm('http://purl.org/dc/elements/1.1/creator'),
      LiteralTerm.string('Example Author'),
    ),
  ]);

  // Create a serializer with readable formatting
  final serializer = RdfXmlFormat.readable().createSerializer();
  
  // Serialize with custom prefixes
  final rdfXml = serializer.write(
    graph,
    customPrefixes: {
      'dc': 'http://purl.org/dc/elements/1.1/',
      'ex': 'http://example.org/',
    },
  );
  
  print(rdfXml);
}
```

### Using with the Format Registry

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Register the format with the registry
  final registry = RdfFormatRegistry();
  registry.registerFormat(const RdfXmlFormat());
  
  // Get a parser by MIME type
  final parser = registry.getParser('application/rdf+xml');
  final serializer = registry.getSerializer('application/rdf+xml');
  
  // ...use parser and serializer
}
```

## ⚙️ Configuration

### Parser Options

```dart
// Create a parser with strict validation
final strictParser = RdfXmlParser(
  xmlContent,
  options: RdfXmlParserOptions.strict(),
);

// Create a parser that handles non-standard RDF/XML
final lenientParser = RdfXmlParser(
  xmlContent,
  options: RdfXmlParserOptions.lenient(),
);

// Create a high-performance parser for large documents
final fastParser = RdfXmlParser(
  xmlContent,
  options: RdfXmlParserOptions.performance(),
);

// Custom configuration
final customParser = RdfXmlParser(
  xmlContent,
  options: RdfXmlParserOptions(
    strictMode: false,
    normalizeWhitespace: true,
    validateOutput: true,
    maxNestingDepth: 50,
  ),
);
```

### Serializer Options

```dart
// Human-readable output
final readableSerializer = RdfXmlSerializer(
  options: RdfXmlSerializerOptions.readable(),
);

// Compact output for storage
final compactSerializer = RdfXmlSerializer(
  options: RdfXmlSerializerOptions.compact(),
);

// Compatible output for legacy systems
final compatibleSerializer = RdfXmlSerializer(
  options: RdfXmlSerializerOptions.compatible(),
);

// Custom configuration
final customSerializer = RdfXmlSerializer(
  options: RdfXmlSerializerOptions(
    prettyPrint: true,
    indentSpaces: 4,
    useNamespaces: true,
    useTypedNodes: false,
  ),
);
```

## 📚 RDF/XML Features

This library supports all features of the RDF/XML syntax:

- Resource descriptions (rdf:Description)
- Typed node elements
- Property elements
- Container elements (rdf:Bag, rdf:Seq, rdf:Alt)
- Collection elements (rdf:List)
- rdf:parseType (Resource, Literal, Collection)
- XML Base support
- XML language tags
- Datatyped literals
- Blank nodes (anonymous and labeled)
- RDF reification

## 🛣️ Roadmap / Next Steps

- Stream parsing?

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

- Fork the repo and submit a PR
- See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
- Join the discussion in [GitHub Issues](https://github.com/kkalass/rdf_xml/issues)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤖 AI Policy

This project is proudly human-led and human-controlled, with all key decisions, design, and code reviews made by people. At the same time, it stands on the shoulders of LLM giants: generative AI tools are used throughout the development process to accelerate iteration, inspire new ideas, and improve documentation quality. We believe that combining human expertise with the best of AI leads to higher-quality, more innovative open source software.

---

© 2025 Klas Kalaß. Licensed under the MIT License.
