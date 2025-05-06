# rdf_xml

[![pub package](https://img.shields.io/pub/v/rdf_xml.svg)](https://pub.dev/packages/rdf_xml)
[![build](https://github.com/kkalass/rdf_xml/actions/workflows/ci.yml/badge.svg)](https://github.com/kkalass/rdf_xml/actions)
[![codecov](https://codecov.io/gh/kkalass/rdf_xml/branch/main/graph/badge.svg)](https://codecov.io/gh/kkalass/rdf_xml)
[![license](https://img.shields.io/github/license/kkalass/rdf_xml.svg)](https://github.com/kkalass/rdf_xml/blob/main/LICENSE)

A RDF/XML parser and serializer for the [rdf_core](https://pub.dev/packages/rdf_core) library, offering a complete implementation of the W3C RDF/XML specification.

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

  // Register the format with the registry
  final rdfCore = RdfCore.withStandardFormats();
  rdfCore.registerFormat(RdfXmlFormat());

  final rdfGraph = rdfCore.parse(xmlContent);
  
  // Print the parsed triples
  for (final triple in rdfGraph.triples) {
    print(triple);
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

  // Register the format with the registry
  final rdfCore = RdfCore.withStandardFormats();
  rdfCore.registerFormat(RdfXmlFormat());

  // Serialize
  final rdfXml = rdfCore.write(graph, contentType: "application/rdf+xml",);
  
  print(rdfXml);
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
  final parser = RdfXmlFormat().createParser();
  final rdfGraph = parser.parse(
    xmlContent, 
    documentUrl: 'file://${file.absolute.path}',
  );
  
  print('Parsed ${rdfGraph.size} triples from $filePath');
}
```

## ⚙️ Configuration

### Parser Options

```dart
// Create a parser with strict validation
final strictParser = RdfXmlFormat.strict().createParser();

// Create a parser that handles non-standard RDF/XML
final lenientParser = RdfXmlFormat.lenient().createParser();

// Custom configuration
final customParser = RdfXmlFormat(
  parserOptions: RdfXmlParserOptions(
    strictMode: false,
    normalizeWhitespace: true,
    validateOutput: true,
    maxNestingDepth: 50,
  ),
).createParser();
```

### Serializer Options

```dart
// Human-readable output
final readableSerializer = RdfXmlFormat.readable().createSerializer();

// Compact output for storage
final compactSerializer = RdfXmlFormat.compact().createSerializer();

// Custom configuration
final customSerializer = RdfXmlFormat(
  serializerOptions: RdfXmlSerializerOptions(
    prettyPrint: true,
    indentSpaces: 4,
    useTypedNodes: true,
  ),
).createSerializer();
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
