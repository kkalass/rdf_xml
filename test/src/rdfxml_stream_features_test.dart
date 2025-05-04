import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlParser Stream-based Features', () {
    test('streaming parser handles typed nodes correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <ex:Person rdf:about="http://example.org/person/1">
            <ex:name>John Doe</ex:name>
          </ex:Person>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(2));

      // Find the type triple
      final typeTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == RdfTerms.type.iri,
      );

      expect(
        typeTriple.subject,
        equals(IriTerm('http://example.org/person/1')),
      );
      expect(typeTriple.predicate, equals(RdfTerms.type));
      expect(typeTriple.object, equals(IriTerm('http://example.org/Person')));

      // Find the name triple
      final nameTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/name',
      );

      expect(
        nameTriple.subject,
        equals(IriTerm('http://example.org/person/1')),
      );
      expect(nameTriple.predicate, equals(IriTerm('http://example.org/name')));
      expect(nameTriple.object, equals(LiteralTerm.string('John Doe')));
    });

    test('streaming parser handles language tags correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/"
                 xmlns:xml="http://www.w3.org/XML/1998/namespace">
          <rdf:Description rdf:about="http://example.org/book/1">
            <ex:title xml:lang="en">The Lord of the Rings</ex:title>
            <ex:title xml:lang="de">Der Herr der Ringe</ex:title>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(2));

      final englishTitle = streamTriples.firstWhere(
        (t) =>
            t.object is LiteralTerm &&
            (t.object as LiteralTerm).language == 'en',
        orElse: () => throw StateError('No English title found'),
      );

      expect(englishTitle.object, isA<LiteralTerm>());
      expect(
        (englishTitle.object as LiteralTerm).value,
        equals('The Lord of the Rings'),
      );
      expect((englishTitle.object as LiteralTerm).language, equals('en'));

      final germanTitle = streamTriples.firstWhere(
        (t) =>
            t.object is LiteralTerm &&
            (t.object as LiteralTerm).language == 'de',
        orElse: () => throw StateError('No German title found'),
      );

      expect(germanTitle.object, isA<LiteralTerm>());
      expect(
        (germanTitle.object as LiteralTerm).value,
        equals('Der Herr der Ringe'),
      );
      expect((germanTitle.object as LiteralTerm).language, equals('de'));
    });

    test('streaming parser handles nested resources correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/"
                 xmlns:xml="http://www.w3.org/XML/1998/namespace">
          <rdf:Description rdf:about="http://example.org/person/1">
            <ex:address>
              <ex:Address>
                <ex:street>123 Main St</ex:street>
                <ex:city>Springfield</ex:city>
              </ex:Address>
            </ex:address>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(4));

      // Find the address triple that links the person to the address
      final addressTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/address',
        orElse: () => throw StateError('No address triple found'),
      );

      expect(
        addressTriple.subject,
        equals(IriTerm('http://example.org/person/1')),
      );
      final addressNode = addressTriple.object;
      expect(addressNode, isA<BlankNodeTerm>());

      // Find the type triple for the address
      final typeTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == RdfTerms.type.iri,
        orElse: () => throw StateError('No type triple found for address'),
      );

      expect(typeTriple.object, equals(IriTerm('http://example.org/Address')));

      // Find the street triple
      final streetTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == 'http://example.org/street',
        orElse: () => throw StateError('No street triple found for address'),
      );

      expect(streetTriple.object, equals(LiteralTerm.string('123 Main St')));

      // Find the city triple
      final cityTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == 'http://example.org/city',
        orElse: () => throw StateError('No city triple found for address'),
      );

      expect(cityTriple.object, equals(LiteralTerm.string('Springfield')));
    });

    test('streaming parser handles datatyped literals correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema#">
          <rdf:Description rdf:about="http://example.org/person">
            <ex:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</ex:age>
            <ex:height rdf:datatype="http://www.w3.org/2001/XMLSchema#decimal">1.75</ex:height>
            <ex:registered rdf:datatype="http://www.w3.org/2001/XMLSchema#boolean">true</ex:registered>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(3));

      // Find the age triple
      final ageTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/age',
      );

      expect(ageTriple.object, isA<LiteralTerm>());
      expect((ageTriple.object as LiteralTerm).value, equals('42'));
      expect(
        (ageTriple.object as LiteralTerm).datatype,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
      );

      // Find the height triple
      final heightTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/height',
      );

      expect(heightTriple.object, isA<LiteralTerm>());
      expect((heightTriple.object as LiteralTerm).value, equals('1.75'));
      expect(
        (heightTriple.object as LiteralTerm).datatype,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#decimal')),
      );

      // Find the registered triple
      final registeredTriple = streamTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/registered',
      );

      expect(registeredTriple.object, isA<LiteralTerm>());
      expect((registeredTriple.object as LiteralTerm).value, equals('true'));
      expect(
        (registeredTriple.object as LiteralTerm).datatype,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#boolean')),
      );
    });

    test('streaming parser handles XML entities correctly', () async {
      final xmlWithEntities = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/resource">
            <ex:title>Title with &lt;brackets&gt; &amp; ampersands</ex:title>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xmlWithEntities);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(1));

      final title = streamTriples.first.object as LiteralTerm;
      expect(title.value, equals('Title with <brackets> & ampersands'));
    });

    test('streaming parser handles xml:base correctly', () async {
      final xmlWithBase = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
                 xmlns:ex="http://example.org/"
                 xml:base="http://example.org/base/">
          <rdf:Description rdf:about="relative">
            <ex:predicate rdf:resource="other"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xmlWithBase);
      final streamTriples = await parser.parseAsStream().toList();

      expect(streamTriples, hasLength(1));

      // Subject and object should have xml:base resolved
      expect(
        streamTriples[0].subject,
        equals(IriTerm('http://example.org/base/relative')),
      );
      expect(
        streamTriples[0].object,
        equals(IriTerm('http://example.org/base/other')),
      );
    });

    test(
      'streaming parser handles blank nodes with rdf:nodeID correctly',
      () async {
        final xmlWithNodeId = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:ex="http://example.org/">
          <rdf:Description rdf:nodeID="node1">
            <ex:knows rdf:nodeID="node2"/>
          </rdf:Description>
          <rdf:Description rdf:nodeID="node2">
            <ex:name>Jane</ex:name>
          </rdf:Description>
        </rdf:RDF>
      ''';

        final parser = RdfXmlParser(xmlWithNodeId);
        final streamTriples = await parser.parseAsStream().toList();

        expect(streamTriples, hasLength(2));

        // Both subjects should be blank nodes
        expect(streamTriples[0].subject, isA<BlankNodeTerm>());
        expect(streamTriples[1].subject, isA<BlankNodeTerm>());

        // The object of the first triple should be a blank node and
        // should match the subject of the second triple
        expect(streamTriples[0].object, isA<BlankNodeTerm>());
        expect(streamTriples[0].object, equals(streamTriples[1].subject));
      },
    );
  });
}
