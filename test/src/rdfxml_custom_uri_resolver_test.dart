import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/interfaces/xml_parsing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Custom URI resolver for testing purposes
class CustomUriResolver implements IUriResolver {
  final Map<String, String> _prefixMappings;

  CustomUriResolver(this._prefixMappings);

  @override
  String resolveUri(String uri, String baseUri) {
    // Special handling for URIs with custom prefixes
    for (final prefix in _prefixMappings.keys) {
      if (uri.startsWith(prefix)) {
        return uri.replaceFirst(prefix, _prefixMappings[prefix]!);
      }
    }

    // For other URIs, perform standard resolution
    if (uri.startsWith('#')) {
      return '$baseUri$uri';
    } else if (!uri.contains(':')) {
      return '$baseUri$uri';
    }

    return uri;
  }

  @override
  String resolveBaseUri(XmlDocument document, String? providedBaseUri) {
    // Always use the provided base URI if available
    if (providedBaseUri != null) {
      return providedBaseUri;
    }

    // Custom implementation: check for a default base URI in our mappings
    return _prefixMappings['DEFAULT_BASE'] ?? 'http://example.org/';
  }
}

void main() {
  group('RdfXmlParser with Custom URI Resolver', () {
    test('resolves URIs using custom mapping strategy', () {
      final customResolver = CustomUriResolver({
        'my:': 'http://mycustomnamespace.org/',
        'local:': 'http://localhost:8080/resources/',
        'DEFAULT_BASE': 'http://testdomain.com/data/',
      });

      final xmlContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="my:resource1">
            <ex:relates rdf:resource="local:item1"/>
            <ex:value>Test Value</ex:value>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Create parser with custom URI resolver
      final parser = RdfXmlParser(xmlContent, uriResolver: customResolver);

      final triples = parser.parse();

      // Verify that custom URI resolution was applied correctly
      expect(triples, hasLength(2));

      // Check that subject was resolved using custom prefix mapping
      final subject = triples[0].subject as IriTerm;
      expect(subject.iri, equals('http://mycustomnamespace.org/resource1'));

      // Check that object was resolved using custom prefix mapping
      final object = triples[0].object as IriTerm;
      expect(object.iri, equals('http://localhost:8080/resources/item1'));
    });

    test('handles xml:base with custom resolver', () {
      final customResolver = CustomUriResolver({
        'app:': 'http://myapp.org/api/',
        'DEFAULT_BASE': 'http://fallback.com/',
      });

      final xmlContent = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/"
                 xml:base="http://basedomain.org/rdf/">
          <rdf:Description rdf:about="relative">
            <ex:connects rdf:resource="app:endpoint"/>
            <ex:connects rdf:resource="other"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Create parser with custom URI resolver and explicit base URI
      // The explicit base URI should override xml:base
      final parser = RdfXmlParser(
        xmlContent,
        baseUri: 'http://explicit.org/base/',
        uriResolver: customResolver,
      );

      final triples = parser.parse();

      // We should have two triples with the same subject but different objects
      expect(triples, hasLength(2));

      // Subject should be resolved against explicit base URI
      final subject = triples[0].subject as IriTerm;
      expect(subject.iri, equals('http://explicit.org/base/relative'));

      // First object should use custom prefix resolution
      final object1 = triples[0].object as IriTerm;
      expect(object1.iri, equals('http://myapp.org/api/endpoint'));

      // Second object should be resolved against explicit base URI
      final object2 = triples[1].object as IriTerm;
      expect(object2.iri, equals('http://explicit.org/base/other'));
    });
  });
}
