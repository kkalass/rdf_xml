import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('RDF Reification Tests', () {
    test('parses RDF reification statements correctly', () {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/statement1">
            <rdf:type rdf:resource="http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement"/>
            <rdf:subject rdf:resource="http://example.org/JohnDoe"/>
            <rdf:predicate rdf:resource="http://example.org/authorOf"/>
            <rdf:object rdf:resource="http://example.org/Book1"/>
            <ex:assertedBy>Alice</ex:assertedBy>
            <ex:certainty>0.9</ex:certainty>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final triples = parser.parse();

      // We expect 6 triples in total:
      // 1. The type assertion (Statement)
      // 2. The subject assertion
      // 3. The predicate assertion
      // 4. The object assertion
      // 5. The assertedBy statement
      // 6. The certainty statement
      expect(triples, hasLength(6));

      // Check the statement has the right type
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            t.predicate == RdfTerms.type,
      );
      expect(
        typeTriple.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement')),
      );

      // Check the reified subject
      final subjectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#subject',
      );
      expect(
        subjectTriple.object,
        equals(IriTerm('http://example.org/JohnDoe')),
      );

      // Check the reified predicate
      final predicateTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate',
      );
      expect(
        predicateTriple.object,
        equals(IriTerm('http://example.org/authorOf')),
      );

      // Check the reified object
      final objectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#object',
      );
      expect(objectTriple.object, equals(IriTerm('http://example.org/Book1')));

      // Check the metadata about the reified statement
      final assertedByTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).iri == 'http://example.org/assertedBy',
      );
      expect(assertedByTriple.object, equals(LiteralTerm.string('Alice')));

      final certaintyTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).iri == 'http://example.org/certainty',
      );
      expect(certaintyTriple.object, equals(LiteralTerm.string('0.9')));
    });

    test('parses RDF implicit reification via rdf:ID correctly', () {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/JohnDoe">
            <ex:authorOf rdf:ID="statement1" rdf:resource="http://example.org/Book1"/>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final triples = parser.parse();

      // We expect 5 triples in total:
      // 1. The original statement (JohnDoe authorOf Book1)
      // 2. The statement type assertion
      // 3. The subject assertion
      // 4. The predicate assertion
      // 5. The object assertion
      expect(triples, hasLength(5));

      // Check the original statement
      final originalTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm('http://example.org/JohnDoe') &&
            (t.predicate as IriTerm).iri == 'http://example.org/authorOf',
      );
      expect(
        originalTriple.object,
        equals(IriTerm('http://example.org/Book1')),
      );

      // Check reification statements about the original triple
      // Type assertion
      final typeTriple = triples.firstWhere(
        (t) =>
            (t.subject as IriTerm).iri.contains('statement1') &&
            t.predicate == RdfTerms.type,
      );
      expect(
        typeTriple.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement')),
      );

      // Get the statement IRI
      final statementIri = (typeTriple.subject as IriTerm).iri;

      // Subject assertion
      final subjectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm(statementIri) &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#subject',
      );
      expect(
        subjectTriple.object,
        equals(IriTerm('http://example.org/JohnDoe')),
      );

      // Predicate assertion
      final predicateTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm(statementIri) &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate',
      );
      expect(
        predicateTriple.object,
        equals(IriTerm('http://example.org/authorOf')),
      );

      // Object assertion
      final objectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm(statementIri) &&
            (t.predicate as IriTerm).iri ==
                'http://www.w3.org/1999/02/22-rdf-syntax-ns#object',
      );
      expect(objectTriple.object, equals(IriTerm('http://example.org/Book1')));
    });

    test('serializes and round-trips reified statements correctly', () {
      // Create the original assertion
      final subject = IriTerm('http://example.org/JohnDoe');
      final predicate = IriTerm('http://example.org/authorOf');
      final object = IriTerm('http://example.org/Book1');
      final originalTriple = Triple(subject, predicate, object);

      // Create the reification node
      final statementNode = IriTerm('http://example.org/statement1');

      // Create the reification triples
      final triples = <Triple>[
        originalTriple,
        Triple(
          statementNode,
          RdfTerms.type,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement'),
        ),
        Triple(
          statementNode,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#subject'),
          subject,
        ),
        Triple(
          statementNode,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate'),
          predicate,
        ),
        Triple(
          statementNode,
          IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#object'),
          object,
        ),
        Triple(
          statementNode,
          IriTerm('http://example.org/assertedBy'),
          LiteralTerm.string('Alice'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Re-parse from XML
      final parser = RdfXmlParser(xml);
      final reparsedTriples = parser.parse();

      // Create a new graph with the parsed triples
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // Check that all original triples are present
      // We can't simply compare triples.length because serialization
      // might generate a different number of triples with the same semantics

      // Check the original statement is preserved
      final originalStatement = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        subject,
        predicate,
      );
      expect(originalStatement, hasLength(1));
      expect(originalStatement.first.object, equals(object));

      // Check the statement type
      final typeTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        statementNode,
        RdfTerms.type,
      );
      expect(typeTriples, hasLength(1));
      expect(
        typeTriples.first.object,
        equals(IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement')),
      );

      // Check the reification components
      final subjectTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        statementNode,
        IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#subject'),
      );
      expect(subjectTriples, hasLength(1));
      expect(subjectTriples.first.object, equals(subject));

      final predicateTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        statementNode,
        IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate'),
      );
      expect(predicateTriples, hasLength(1));
      expect(predicateTriples.first.object, equals(predicate));

      final objectTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        statementNode,
        IriTerm('http://www.w3.org/1999/02/22-rdf-syntax-ns#object'),
      );
      expect(objectTriples, hasLength(1));
      expect(objectTriples.first.object, equals(object));

      // Check the metadata assertion
      final metadataTriples = RdfTestUtils.triplesWithSubjectPredicate(
        reparsedGraph,
        statementNode,
        IriTerm('http://example.org/assertedBy'),
      );
      expect(metadataTriples, hasLength(1));
      expect(metadataTriples.first.object, equals(LiteralTerm.string('Alice')));
    });

    test('streaming parser handles reification correctly', () async {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/statement1">
            <rdf:type rdf:resource="http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement"/>
            <rdf:subject rdf:resource="http://example.org/JohnDoe"/>
            <rdf:predicate rdf:resource="http://example.org/authorOf"/>
            <rdf:object rdf:resource="http://example.org/Book1"/>
            <ex:assertedBy>Alice</ex:assertedBy>
          </rdf:Description>
        </rdf:RDF>
      ''';

      // Standard parse for comparison
      final parser = RdfXmlParser(xml);
      final standardTriples = parser.parse();

      // Stream parse
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
  });
}
