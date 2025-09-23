import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

final _log = Logger('namespace_manager_test');

/// Debugging helper method to understand why the tests generate 8 triples
/// instead of the expected 5.
void debugContainerTriples(List<Triple> triples) {
  // Create a graph
  final graph = RdfGraph(triples: triples);

  // Serialize to RDF/XML
  final serializer = RdfXmlSerializer();
  final xml = serializer.write(graph);

  // Print XML for debugging
  _log.finest('\n--- Serialized XML ---');
  _log.finest(xml);

  // Re-parse
  final parser = RdfXmlParser(xml);
  final reparsedTriples = parser.parse();

  // Print reparsed triples for debugging
  _log.finest('\n--- Reparsed Triples (${reparsedTriples.length}) ---');
  for (var i = 0; i < reparsedTriples.length; i++) {
    _log.finest('$i: ${reparsedTriples[i]}');
  }

  // Find duplicate subject-predicate pairs
  final subjectPredicatePairs = <String, List<Triple>>{};
  for (final triple in reparsedTriples) {
    final key = '${triple.subject} - ${triple.predicate}';
    subjectPredicatePairs.putIfAbsent(key, () => []).add(triple);
  }

  // Print duplicate subject-predicate pairs
  _log.finest('\n--- Duplicate subject-predicate pairs ---');
  for (final entry in subjectPredicatePairs.entries) {
    if (entry.value.length > 1) {
      _log.finest('${entry.key}: ${entry.value.length} occurrences');
      for (final triple in entry.value) {
        _log.finest('  $triple');
      }
    }
  }
}

void main() {
  group('RDF Container Elements', () {
    test('parses rdf:Bag container correctly', () {
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
      final triples = parser.parse();

      // We expect:
      // 1 triple for the container reference
      // 1 triple for the container type (rdf:Bag)
      // 3 triples for the items (_1, _2, _3)
      expect(triples, hasLength(5));

      // Find the container link triple
      final containerTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/container/bag') &&
            (t.predicate as IriTerm).value == 'http://example.org/items',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's a Bag
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).value ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag')),
      );

      // Verify it has the expected members
      final itemTriples =
          triples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).value.startsWith(
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
          itemTriples.map((t) => (t.predicate as IriTerm).value).toList();

      expect(
        predicates,
        containsAll([
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_1',
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_2',
          'http://www.w3.org/1999/02/22-rdf-syntax-ns#_3',
        ]),
      );
    });

    test('parses rdf:Seq container correctly', () {
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
      final triples = parser.parse();

      // We expect similar structure to Bag, but with rdf:Seq
      expect(triples, hasLength(5));

      // Find the container link triple
      final containerTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/container/seq') &&
            (t.predicate as IriTerm).value == 'http://example.org/orderedItems',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's a Seq
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).value ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq')),
      );

      // Verify it has the expected members
      final itemTriples =
          triples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).value.startsWith(
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
              (t.predicate as IriTerm).value ==
              'http://www.w3.org/1999/02/22-rdf-syntax-ns#_$i',
        );
        orderedValues.add((triple.object as LiteralTerm).value);
      }

      // The order is guaranteed in a Seq
      expect(orderedValues, equals(['First', 'Second', 'Third']));
    });

    test('parses rdf:Alt container correctly', () {
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
      final triples = parser.parse();

      // Structure like the others but with rdf:Alt
      expect(triples, hasLength(5));

      // Find the container link triple
      final containerTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/container/alt') &&
            (t.predicate as IriTerm).value == 'http://example.org/alternatives',
      );

      // Get the container node
      final containerNode = containerTriple.object;
      expect(containerNode, isA<BlankNodeTerm>());

      // Verify it's an Alt
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == containerNode &&
            (t.predicate as IriTerm).value ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      expect(
        typeTriple.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt')),
      );

      // Verify it has the expected alternatives
      final itemTriples =
          triples
              .where(
                (t) =>
                    t.subject == containerNode &&
                    (t.predicate as IriTerm).value.startsWith(
                      'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                    ),
              )
              .toList();

      expect(itemTriples, hasLength(3));

      // Check the default option (first one)
      final defaultOption = itemTriples.firstWhere(
        (t) =>
            (t.predicate as IriTerm).value ==
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#_1',
      );

      expect((defaultOption.object as LiteralTerm).value, equals('Option A'));
    });

    test('serializes and re-parses rdf:Bag container correctly', () {
      // Create a graph with a Bag container
      final subject = const IriTerm('http://example.org/container/bag');
      final predicate = const IriTerm('http://example.org/items');
      final containerNode = BlankNodeTerm();

      final triples = <Triple>[
        Triple(subject, predicate, containerNode),
        Triple(
          containerNode,
          RdfTerms.type,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_1'),
          LiteralTerm.string('Item 1'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_2'),
          LiteralTerm.string('Item 2'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_3'),
          LiteralTerm.string('Item 3'),
        ),
      ];

      // Debug the container serialization
      debugContainerTriples(triples);

      final graph = RdfGraph(triples: triples);

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Re-parse and verify
      final parser = RdfXmlParser(xml);
      final reparsedTriples = parser.parse();

      // Create a new graph with the parsed triples
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // The number of triples should be the same
      expect(reparsedTriples.length, equals(triples.length));

      // Check all original triples are semantically preserved
      // Note: Blank node IDs may differ

      // Check the container is linked to the subject
      final containerTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        subject,
        predicate,
      );
      expect(containerTriples, hasLength(1));

      // Get the new container node
      final newContainerNode = containerTriples.first.object;

      // Check it's a Bag
      final typeTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        newContainerNode as RdfSubject,
        RdfTerms.type,
      );
      expect(typeTriples, hasLength(1));
      expect(
        typeTriples.first.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag')),
      );

      // Check all items are present
      final values = [];
      for (int i = 1; i <= 3; i++) {
        final itemTriples = RdfTestUtils.triplesWithSubjectPredicate(
          reparsedGraph,
          newContainerNode,
          IriTerm.validated('http://www.w3.org/1999/02/22-rdf-syntax-ns#_$i'),
        );
        expect(itemTriples, hasLength(1));
        values.add((itemTriples.first.object as LiteralTerm).value);
      }

      expect(values, containsAll(['Item 1', 'Item 2', 'Item 3']));
    });

    test('serializes and re-parses rdf:Seq container correctly', () {
      // Create a graph with a Seq container
      final subject = const IriTerm('http://example.org/container/seq');
      final predicate = const IriTerm('http://example.org/orderedItems');
      final containerNode = BlankNodeTerm();

      final triples = <Triple>[
        Triple(subject, predicate, containerNode),
        Triple(
          containerNode,
          RdfTerms.type,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_1'),
          LiteralTerm.string('First'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_2'),
          LiteralTerm.string('Second'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_3'),
          LiteralTerm.string('Third'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Re-parse and verify
      final parser = RdfXmlParser(xml);
      final reparsedTriples = parser.parse();

      // Create a new graph with the parsed triples
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // The number of triples should be the same
      expect(reparsedTriples.length, equals(triples.length));

      // Get the new container node
      final containerTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        subject,
        predicate,
      );
      expect(containerTriples, hasLength(1));
      final newContainerNode = containerTriples.first.object;

      // Check it's a Seq
      final typeTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        newContainerNode as RdfSubject,
        RdfTerms.type,
      );
      expect(typeTriples, hasLength(1));
      expect(
        typeTriples.first.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq')),
      );

      // Check the items are in the right order
      final orderedValues = [];
      for (int i = 1; i <= 3; i++) {
        final itemTriples = RdfTestUtils.triplesWithSubjectPredicate(
          reparsedGraph,
          newContainerNode,
          IriTerm.validated('http://www.w3.org/1999/02/22-rdf-syntax-ns#_$i'),
        );
        expect(itemTriples, hasLength(1));
        orderedValues.add((itemTriples.first.object as LiteralTerm).value);
      }

      expect(orderedValues, equals(['First', 'Second', 'Third']));
    });

    test('serializes and re-parses rdf:Alt container correctly', () {
      // Create a graph with an Alt container
      final subject = const IriTerm('http://example.org/container/alt');
      final predicate = const IriTerm('http://example.org/alternatives');
      final containerNode = BlankNodeTerm();

      final triples = <Triple>[
        Triple(subject, predicate, containerNode),
        Triple(
          containerNode,
          RdfTerms.type,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_1'),
          LiteralTerm.string('Option A'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_2'),
          LiteralTerm.string('Option B'),
        ),
        Triple(
          containerNode,
          const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_3'),
          LiteralTerm.string('Option C'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Re-parse and verify
      final parser = RdfXmlParser(xml);
      final reparsedTriples = parser.parse();

      // Create a new graph with the parsed triples
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // The number of triples should be the same
      expect(reparsedTriples.length, equals(triples.length));

      // Get the new container node
      final containerTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        subject,
        predicate,
      );
      expect(containerTriples, hasLength(1));
      final newContainerNode = containerTriples.first.object;

      // Check it's an Alt
      final typeTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        newContainerNode as RdfSubject,
        RdfTerms.type,
      );
      expect(typeTriples, hasLength(1));
      expect(
        typeTriples.first.object,
        equals(const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt')),
      );

      // Check the default option is preserved (first item)
      final defaultOptionTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        newContainerNode,
        const IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#_1'),
      );
      expect(defaultOptionTriples, hasLength(1));
      expect(
        (defaultOptionTriples.first.object as LiteralTerm).value,
        equals('Option A'),
      );
    });
  });
}
