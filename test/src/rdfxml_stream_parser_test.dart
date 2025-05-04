import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_format.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlParser Stream-based Parsing', () {
    test('parseAsStream returns the same triples as parse', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject1">
            <ex:predicate1>Object1</ex:predicate1>
          </rdf:Description>
          <rdf:Description rdf:about="http://example.org/subject2">
            <ex:predicate2>Object2</ex:predicate2>
          </rdf:Description>
          <ex:Person rdf:about="http://example.org/person/1">
            <ex:name>John Doe</ex:name>
            <ex:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">30</ex:age>
          </ex:Person>
        </rdf:RDF>
      ''';

      // Parse with regular method
      final parser = RdfXmlParser(xml);
      final standardTriples = parser.parse();

      // Parse with stream method
      final streamParser = RdfXmlParser(xml);
      final streamTriples = await streamParser.parseAsStream().toList();

      // Compare results - should have same number of triples
      expect(streamTriples.length, equals(standardTriples.length));

      // Both methods should yield the same triples (may be in different order)
      for (final triple in standardTriples) {
        expect(
          streamTriples,
          contains(triple),
          reason: 'Stream parsing should contain triple: $triple',
        );
      }
    });

    test('parseAsStream handles large documents efficiently', () async {
      // Create a large RDF/XML document with many triples
      final StringBuffer xmlBuffer = StringBuffer();
      xmlBuffer.write('''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
      ''');

      // Add 1000 description elements
      for (int i = 0; i < 1000; i++) {
        xmlBuffer.write('''
          <rdf:Description rdf:about="http://example.org/subject$i">
            <ex:predicate>Value $i</ex:predicate>
          </rdf:Description>
        ''');
      }

      xmlBuffer.write('</rdf:RDF>');

      final xml = xmlBuffer.toString();

      // Parse with stream method
      final parser = RdfXmlParser(xml);
      int tripleCount = 0;

      // Process triples one by one without storing the full list
      await for (final triple in parser.parseAsStream()) {
        tripleCount++;

        // Verify structure of a sample triple
        if (tripleCount == 500) {
          expect(
            triple.subject,
            equals(IriTerm('http://example.org/subject499')),
          );
          expect(
            triple.predicate,
            equals(IriTerm('http://example.org/predicate')),
          );
          expect(triple.object, equals(LiteralTerm.string('Value 499')));
        }
      }

      // Should have parsed 1000 triples
      expect(tripleCount, equals(1000));
    });

    test('RdfXmlFormat streaming parser integration', () async {
      final format = RdfXmlFormat();
      final streamingParser = format.createStreamingParser();

      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Test regular parsing
      final graph = streamingParser.parse(xml);
      expect(graph.triples, hasLength(1));

      // Test stream parsing
      final triples = await streamingParser.parseAsStream(xml).toList();
      expect(triples, hasLength(1));
      expect(triples[0].subject, equals(IriTerm('http://example.org/subject')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
      expect(triples[0].object, equals(LiteralTerm.string('Object')));
    });

    test('parseAsStream handles RDF collections', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/list">
            <ex:items rdf:parseType="Collection">
              <rdf:Description rdf:about="http://example.org/item/1"/>
              <rdf:Description rdf:about="http://example.org/item/2"/>
              <rdf:Description rdf:about="http://example.org/item/3"/>
            </ex:items>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final triples = await parser.parseAsStream().toList();

      // We expect 7 triples for a 3-item collection
      expect(triples, hasLength(7));

      // Find the items triple that links the list to the first node
      final itemsTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/list') &&
            (t.predicate as IriTerm).iri == 'http://example.org/items',
      );

      // Verify that we have all the necessary RDF List structure triples
      final listNode = itemsTriple.object;
      expect(listNode, isA<BlankNodeTerm>());

      // Verify we have 3 first predicates (one for each item)
      final firstTriples =
          triples
              .where(
                (t) =>
                    (t.predicate as IriTerm).iri ==
                    'http://www.w3.org/1999/02/22-rdf-syntax-ns#first',
              )
              .toList();
      expect(firstTriples, hasLength(3));

      // Check for the 3 items
      final items = firstTriples.map((t) => (t.object as IriTerm).iri).toSet();

      expect(items, contains('http://example.org/item/1'));
      expect(items, contains('http://example.org/item/2'));
      expect(items, contains('http://example.org/item/3'));

      // Check if the list terminates with rdf:nil
      final nilTriple = triples.firstWhere(
        (t) =>
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' &&
            t.object ==
                IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil'),
      );
      expect(nilTriple, isNotNull);
    });
  });
}
