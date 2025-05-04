import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:test/test.dart';

void main() {
  group('RDF Container Streaming Tests', () {
    test('streaming parser handles rdf:Bag container correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/container/bag">
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

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      // We expect:
      // 1 triple for the container reference
      // 1 triple for the container type (rdf:Bag)
      // 3 triples for the items (_1, _2, _3)
      expect(streamTriples, hasLength(5));

      // Find the container link triple
      final containerTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/container/bag') &&
            (t.predicate as IriTerm).iri == 'http://example.org/items',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's a Bag
      final typeTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag')),
      );

      // Verify it has the expected members
      final itemTriples =
          streamTriples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).iri.startsWith(
                      'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                    ),
              )
              .toList();

      expect(itemTriples, hasLength(3));

      // Check the values are as expected
      final values =
          itemTriples.map((t) => (t.object as LiteralTerm).value).toList();

      expect(values, containsAll(['Item 1', 'Item 2', 'Item 3']));

      // Check the predicates are _1, _2, _3
      final predicates =
          itemTriples.map((t) => (t.predicate as IriTerm).iri).toList();

      expect(
        predicates,
        containsAll([
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_1',
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_2',
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_3',
        ]),
      );
    });

    test('streaming parser handles rdf:Seq container correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/container/seq">
            <ex:orderedItems>
              <rdf:Seq>
                <rdf:li>First</rdf:li>
                <rdf:li>Second</rdf:li>
                <rdf:li>Third</rdf:li>
              </rdf:Seq>
            </ex:orderedItems>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      // We expect similar structure to Bag, but with rdf:Seq
      expect(streamTriples, hasLength(5));

      // Find the container link triple
      final containerTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/container/seq') &&
            (t.predicate as IriTerm).iri == 'http://example.org/orderedItems',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's a Seq
      final typeTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq')),
      );

      // Verify it has the expected members
      final itemTriples =
          streamTriples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).iri.startsWith(
                      'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                    ),
              )
              .toList();

      expect(itemTriples, hasLength(3));

      // Check the values are as expected and in the right order
      final orderedValues = [];
      for (int i = 1; i <= 3; i++) {
        final triple = itemTriples.firstWhere(
          (t) =>
              (t.predicate as IriTerm).iri ==
              'http://www.w3.org/1999/02/22-rdf-syntax-ns#_$i',
        );
        orderedValues.add((triple.object as LiteralTerm).value);
      }

      // The order is guaranteed in a Seq
      expect(orderedValues, equals(['First', 'Second', 'Third']));
    });

    test('streaming parser handles rdf:Alt container correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/container/alt">
            <ex:alternatives>
              <rdf:Alt>
                <rdf:li>Option A</rdf:li>
                <rdf:li>Option B</rdf:li>
                <rdf:li>Option C</rdf:li>
              </rdf:Alt>
            </ex:alternatives>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final streamTriples = await parser.parseAsStream().toList();

      // Structure like the others but with rdf:Alt
      expect(streamTriples, hasLength(5));

      // Find the container link triple
      final containerTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/container/alt') &&
            (t.predicate as IriTerm).iri == 'http://example.org/alternatives',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's an Alt
      final typeTriple = streamTriples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt')),
      );

      // Verify it has the expected alternatives
      final itemTriples =
          streamTriples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).iri.startsWith(
                      'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                    ),
              )
              .toList();

      expect(itemTriples, hasLength(3));

      // Check the default option (first one)
      final defaultOption = itemTriples.firstWhere(
        (t) =>
            (t.predicate as IriTerm).iri ==
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#_1',
      );

      expect((defaultOption.object as LiteralTerm).value, equals('Option A'));
    });

    test(
      'streaming parser handles RDF collections with detailed verification',
      () async {
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

        final firstListNode = itemsTriple.object as BlankNodeTerm;

        // Find the first item (item/1)
        final firstItemTriple = triples.firstWhere(
          (t) =>
              t.subject == firstListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.first.iri,
        );

        expect(
          firstItemTriple.object,
          equals(IriTerm('http://example.org/item/1')),
        );

        // Find the rest link from first to second node
        final firstRestTriple = triples.firstWhere(
          (t) =>
              t.subject == firstListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.rest.iri,
        );

        final secondListNode = firstRestTriple.object as BlankNodeTerm;

        // Find the second item (item/2)
        final secondItemTriple = triples.firstWhere(
          (t) =>
              t.subject == secondListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.first.iri,
        );

        expect(
          secondItemTriple.object,
          equals(IriTerm('http://example.org/item/2')),
        );

        // Find the rest link from second to third node
        final secondRestTriple = triples.firstWhere(
          (t) =>
              t.subject == secondListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.rest.iri,
        );

        final thirdListNode = secondRestTriple.object as BlankNodeTerm;

        // Find the third item (item/3)
        final thirdItemTriple = triples.firstWhere(
          (t) =>
              t.subject == thirdListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.first.iri,
        );

        expect(
          thirdItemTriple.object,
          equals(IriTerm('http://example.org/item/3')),
        );

        // Find the rest link from third node to nil
        final thirdRestTriple = triples.firstWhere(
          (t) =>
              t.subject == thirdListNode &&
              (t.predicate as IriTerm).iri == RdfTerms.rest.iri,
        );

        expect(thirdRestTriple.object, equals(RdfTerms.nil));
      },
    );

    test(
      'streaming parser can parse and verify complex nested structures',
      () async {
        final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/resource">
            <ex:hasBag>
              <rdf:Bag>
                <rdf:li>Item in bag</rdf:li>
                <rdf:li>
                  <rdf:Description>
                    <ex:hasSeq>
                      <rdf:Seq>
                        <rdf:li>First in sequence</rdf:li>
                        <rdf:li>Second in sequence</rdf:li>
                      </rdf:Seq>
                    </ex:hasSeq>
                  </rdf:Description>
                </rdf:li>
                <rdf:li rdf:resource="http://example.org/reference"/>
              </rdf:Bag>
            </ex:hasBag>
          </rdf:Description>
        </rdf:RDF>
      ''';

        final parser = RdfXmlParser(xml);
        final streamTriples = await parser.parseAsStream().toList();

        // First verify we have a reasonable number of triples
        expect(streamTriples.isNotEmpty, isTrue);

        // Find the top-level bag
        final bagTriple = streamTriples.firstWhere(
          (t) =>
              t.subject == IriTerm('http://example.org/resource') &&
              (t.predicate as IriTerm).iri == 'http://example.org/hasBag',
        );
        final bagNode = bagTriple.object;
        expect(bagNode, isA<BlankNodeTerm>());

        // Verify it's a Bag
        final bagTypeTriple = streamTriples.firstWhere(
          (t) =>
              t.subject == bagNode &&
              (t.predicate as IriTerm).iri ==
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
        );
        expect(
          bagTypeTriple.object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag')),
        );

        // Find all bag items
        final bagItems =
            streamTriples
                .where(
                  (t) =>
                      t.subject == bagNode &&
                      (t.predicate as IriTerm).iri.startsWith(
                        'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                      ),
                )
                .toList();

        expect(bagItems, hasLength(3));

        // Find the second item which should be a blank node
        final secondItemTriple = bagItems.firstWhere(
          (t) =>
              (t.predicate as IriTerm).iri ==
              'http://www.w3.org/1999/02/22-rdf-syntax-ns#_2',
        );
        expect(secondItemTriple.object, isA<BlankNodeTerm>());

        // This blank node should have a sequence
        final nestedBlankNode = secondItemTriple.object;
        final seqTriple = streamTriples.firstWhere(
          (t) =>
              t.subject == nestedBlankNode &&
              (t.predicate as IriTerm).iri == 'http://example.org/hasSeq',
        );

        // Find sequence node and verify its type
        final seqNode = seqTriple.object;
        expect(seqNode, isA<BlankNodeTerm>());

        final seqTypeTriple = streamTriples.firstWhere(
          (t) =>
              t.subject == seqNode &&
              (t.predicate as IriTerm).iri ==
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
        );
        expect(
          seqTypeTriple.object,
          equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq')),
        );

        // Check sequence items
        final seqItems =
            streamTriples
                .where(
                  (t) =>
                      t.subject == seqNode &&
                      (t.predicate as IriTerm).iri.startsWith(
                        'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                      ),
                )
                .toList();

        expect(seqItems, hasLength(2));

        // Third item in bag should be a reference
        final thirdItemTriple = bagItems.firstWhere(
          (t) =>
              (t.predicate as IriTerm).iri ==
              'http://www.w3.org/1999/02/22-rdf-syntax-ns#_3',
        );

        expect(
          thirdItemTriple.object,
          equals(IriTerm('http://example.org/reference')),
        );
      },
    );
  });
}
