import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/exceptions.dart';
import 'package:rdf_xml/src/interfaces/xml_parsing.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

/// Custom URI resolver for testing purposes
class CustomUriResolver implements IUriResolver {
  final Map<String, String> _prefixMappings;

  CustomUriResolver(this._prefixMappings);

  @override
  String resolveUri(String uri, String? baseUri) {
    // Special handling for URIs with custom prefixes
    for (final prefix in _prefixMappings.keys) {
      if (uri.startsWith(prefix)) {
        return uri.replaceFirst(prefix, _prefixMappings[prefix]!);
      }
    }

    // For other URIs, perform standard resolution
    if (uri.startsWith('#')) {
      if (baseUri == null) {
        throw RdfXmlBaseUriRequiredException(relativeUri: uri);
      }
      return '$baseUri$uri';
    } else if (!uri.contains(':')) {
      if (baseUri == null) {
        throw RdfXmlBaseUriRequiredException(relativeUri: uri);
      }

      return '$baseUri$uri';
    }

    return uri;
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
      expect(subject.value, equals('http://mycustomnamespace.org/resource1'));

      // Check that object was resolved using custom prefix mapping
      final object = triples[0].object as IriTerm;
      expect(object.value, equals('http://localhost:8080/resources/item1'));
    });
  });
}
