# RDF XML

[![pub package](https://img.shields.io/pub/v/rdf_xml.svg)](https://pub.dev/packages/rdf_xml)
[![build](https://github.com/kkalass/rdf_xml/actions/workflows/ci.yml/badge.svg)](https://github.com/kkalass/rdf_xml/actions)
[![codecov](https://codecov.io/gh/kkalass/rdf_xml/branch/main/graph/badge.svg)](https://codecov.io/gh/kkalass/rdf_xml)
[![license](https://img.shields.io/github/license/kkalass/rdf_xml.svg)](https://github.com/kkalass/rdf_xml/blob/main/LICENSE)

A RDF/XML decoder and encoder for the [rdf_core](https://pub.dev/packages/rdf_core) library, offering a complete implementation of the W3C RDF/XML specification.

[🌐 **Official Documentation**](https://kkalass.github.io/rdf_xml/)

---

## Part of a whole family of projects

If you are looking for more rdf-related functionality, have a look at our companion projects:

* basic graph classes as well as turtle/jsonld/n-triple decoding and encoding: [rdf_core](https://github.com/kkalass/rdf_core) 
* easy-to-use constants for many well-known vocabularies: [rdf_vocabularies](https://github.com/kkalass/rdf_vocabularies)
* generate your own easy-to-use constants for other vocabularies with a build_runner: [rdf_vocabulary_to_dart](https://github.com/kkalass/rdf_vocabulary_to_dart)
* map Dart Objects ↔️ RDF: [rdf_mapper](https://github.com/kkalass/rdf_mapper)

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
  rdf_xml: ^0.4.6
```

## 📖 Usage

### Decoding RDF/XML

```dart
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

  // Use the global rdfxml codec
  final rdfGraph = rdfxml.decode(xmlContent);
  
  // Print the decoded triples
  for (final triple in rdfGraph.triples) {
    print(triple);
  }
}
```



### Encoding to RDF/XML

```dart
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  // Create a graph with some triples
  final graph = RdfGraph.fromTriples([
    Triple(
      const IriTerm('http://example.org/resource'),
      const IriTerm('http://purl.org/dc/elements/1.1/title'),
      LiteralTerm.string('Example Resource'),
    ),
    Triple(
      const IriTerm('http://example.org/resource'),
      const IriTerm('http://purl.org/dc/elements/1.1/creator'),
      LiteralTerm.string('Example Author'),
    ),
  ]);

  // Use the global rdfxml codec
  final rdfXml = rdfxml.encode(graph);
  
  print(rdfXml);
}
```

### Integration with RdfCore

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

  // Register the codec with RdfCore
  final rdfCore = RdfCore.withStandardCodecs(additionalCodecs: [RdfXmlCodec()]);

  // Decode using RdfCore
  final rdfGraph = rdfCore.decode(xmlContent, contentType: "application/rdf+xml");
  
  // Print the decoded triples
  for (final triple in rdfGraph.triples) {
    print(triple);
  }

  // Encode using RdfCore with specified content type
  final rdfXml = rdfCore.encode(rdfGraph, contentType: "application/rdf+xml");
  
  print(rdfXml);
}
```

### Decoding from a File

```dart
import 'dart:io';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

Future<void> parseFromFile(String filePath) async {
  final file = File(filePath);
  final xmlContent = await file.readAsString();
  
  // Decode with base URI set to the file location
  final rdfGraph = rdfxml.decode(
    xmlContent, 
    documentUrl: 'file://${file.absolute.path}',
  );
  
  print('Parsed ${rdfGraph.size} triples from $filePath');
}
```

## ⚙️ Configuration

### Decoder Options

```dart
// Create a codec with strict validation
final strictCodec = RdfXmlCodec.strict();

// Create a codec that handles non-standard RDF/XML
final lenientCodec = RdfXmlCodec.lenient();

// Custom configuration
final customCodec = RdfXmlCodec(
  decoderOptions: RdfXmlDecoderOptions(
    strictMode: false,
    normalizeWhitespace: true,
    validateOutput: true,
    maxNestingDepth: 50,
  ),
);
```

### Encoder Options

```dart
// Human-readable output
final readableCodec = RdfXmlCodec.readable();

// Compact output for storage
final compactCodec = RdfXmlCodec.compact();

// Custom configuration
final customCodec = RdfXmlCodec(
  encoderOptions: RdfXmlEncoderOptions(
    prettyPrint: true,
    indentSpaces: 4,
    useTypedNodes: true,
    includeBaseDeclaration: true, // Controls xml:base attribute inclusion
  ),
);

// Control base URI handling
final baseUri = 'http://example.org/base/';
final withBase = rdfxml.encode(graph, baseUri: baseUri); // Includes xml:base
final withoutBase = RdfXmlCodec(
  encoderOptions: RdfXmlEncoderOptions(includeBaseDeclaration: false)
).encode(graph, baseUri: baseUri); // Omits xml:base but still relativizes URIs
```

> 💡 **See also**: Check out [`example/base_uri_handling.dart`](example/base_uri_handling.dart) for a comprehensive demonstration of base URI options and practical use cases.

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
