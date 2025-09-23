import 'package:test/test.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';

void main() {
  group('RDF/XML Base URI Integration Tests', () {
    late RdfXmlCodec codec;

    setUp(() {
      codec = RdfXmlCodec();
    });

    test('xml:base attribute with fragment ending should resolve correctly', () {
      // Test the specific case mentioned: base URI ending with # and relative IRI
      final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xml:base="http://my.host/path#">
  <rdf:Description rdf:about="foo">
    <ex:title>Test Resource</ex:title>
  </rdf:Description>
</rdf:RDF>''';

      final graph = codec.decode(xmlContent);
      final triples = graph.triples.toList();

      expect(triples, hasLength(1));

      final subject = triples[0].subject as IriTerm;
      // Should be resolved to http://my.host/foo, NOT http://my.host/path#foo
      expect(subject.value, equals('http://my.host/foo'));
      expect(subject.value, isNot(equals('http://my.host/path#foo')));
    });

    test(
      'documentUrl parameter with fragment ending should resolve correctly',
      () {
        final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="bar">
    <ex:title>Another Test Resource</ex:title>
  </rdf:Description>
</rdf:RDF>''';

        final graph = codec.decode(
          xmlContent,
          documentUrl: 'http://my.host/document#',
        );
        final triples = graph.triples.toList();

        expect(triples, hasLength(1));

        final subject = triples[0].subject as IriTerm;
        // Should be resolved to http://my.host/bar, NOT http://my.host/document#bar
        expect(subject.value, equals('http://my.host/bar'));
        expect(subject.value, isNot(equals('http://my.host/document#bar')));
      },
    );

    test('xml:base overrides documentUrl parameter', () {
      final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xml:base="http://override.host/path/">
  <rdf:Description rdf:about="resource">
    <ex:title>Override Test</ex:title>
  </rdf:Description>
</rdf:RDF>''';

      final graph = codec.decode(
        xmlContent,
        documentUrl: 'http://my.host/document#',
      );
      final triples = graph.triples.toList();

      expect(triples, hasLength(1));

      final subject = triples[0].subject as IriTerm;
      // Should use xml:base, not documentUrl
      expect(subject.value, equals('http://override.host/path/resource'));
      expect(subject.value, isNot(contains('my.host')));
    });

    test('nested xml:base attributes resolve correctly', () {
      final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xmlns:xml="http://www.w3.org/XML/1998/namespace"
         xml:base="http://my.host/root/">
  <rdf:Description rdf:about="resource1">
    <ex:title>Root Level</ex:title>
  </rdf:Description>
  
  <rdf:Description xml:base="subpath/" rdf:about="resource2">
    <ex:title>Nested Level</ex:title>
  </rdf:Description>
</rdf:RDF>''';

      final graph = codec.decode(xmlContent);
      final triples = graph.triples.toList();

      expect(triples, hasLength(2));

      final subjects = triples.map((t) => (t.subject as IriTerm).value).toSet();

      expect(subjects, contains('http://my.host/root/resource1'));
      expect(subjects, contains('http://my.host/root/subpath/resource2'));
    });

    test('fragment references resolve correctly with base URI', () {
      final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xml:base="http://my.host/document">
  <rdf:Description rdf:about="">
    <ex:title>Document</ex:title>
    <ex:hasFragment rdf:resource="#section1"/>
  </rdf:Description>
  
  <rdf:Description rdf:about="#section1">
    <ex:title>Section 1</ex:title>
  </rdf:Description>
</rdf:RDF>''';

      final graph = codec.decode(xmlContent);
      final triples = graph.triples.toList();

      expect(triples, hasLength(3));

      final iris = triples.map((t) => (t.subject as IriTerm).value).toSet();
      iris.addAll(
        triples
            .where((t) => t.object is IriTerm)
            .map((t) => (t.object as IriTerm).value),
      );

      expect(iris, contains('http://my.host/document'));
      expect(iris, contains('http://my.host/document#section1'));
    });

    test('non-URI identifiers pass through unchanged', () {
      final xmlContent = '''<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xml:base="http://my.host/path#">
  <rdf:Description rdf:about="urn:isbn:123456789">
    <ex:title>Book with ISBN</ex:title>
    <ex:sameAs rdf:resource="doi:10.1000/123456"/>
  </rdf:Description>
</rdf:RDF>''';

      final graph = codec.decode(xmlContent);
      final triples = graph.triples.toList();

      expect(triples, hasLength(2));

      final subject = triples[0].subject as IriTerm;
      expect(subject.value, equals('urn:isbn:123456789'));

      final object = triples[1].object as IriTerm;
      expect(object.value, equals('doi:10.1000/123456'));
    });
  });
}
