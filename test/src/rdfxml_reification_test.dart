import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';

final _log = Logger('RDF Reification Tests');
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
            t.subject == const IriTerm('http://example.org/statement1') &&
            t.predicate == RdfTerms.type,
      );
      expect(typeTriple.object, equals(RdfTerms.Statement));

      // Check the reified subject
      final subjectTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/statement1') &&
            t.predicate == RdfTerms.subject,
      );
      expect(
        subjectTriple.object,
        equals(const IriTerm('http://example.org/JohnDoe')),
      );

      // Check the reified predicate
      final predicateTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/statement1') &&
            t.predicate == RdfTerms.predicate,
      );
      expect(
        predicateTriple.object,
        equals(const IriTerm('http://example.org/authorOf')),
      );

      // Check the reified object
      final objectTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/statement1') &&
            t.predicate == RdfTerms.object,
      );
      expect(
        objectTriple.object,
        equals(const IriTerm('http://example.org/Book1')),
      );

      // Check the metadata about the reified statement
      final assertedByTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).value == 'http://example.org/assertedBy',
      );
      expect(assertedByTriple.object, equals(LiteralTerm.string('Alice')));

      final certaintyTriple = triples.firstWhere(
        (t) =>
            t.subject == const IriTerm('http://example.org/statement1') &&
            (t.predicate as IriTerm).value == 'http://example.org/certainty',
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

      final parser = RdfXmlParser(xml, baseUri: 'http://example.org/doc');
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
            t.subject == const IriTerm('http://example.org/JohnDoe') &&
            (t.predicate as IriTerm).value == 'http://example.org/authorOf',
      );
      expect(
        originalTriple.object,
        equals(const IriTerm('http://example.org/Book1')),
      );

      // Check reification statements about the original triple
      // Type assertion
      final typeTriple = triples.firstWhere(
        (t) =>
            (t.subject as IriTerm).value.contains('statement1') &&
            t.predicate == RdfTerms.type,
      );
      expect(typeTriple.object, equals(RdfTerms.Statement));

      // Get the statement IRI
      final statementIri = (typeTriple.subject as IriTerm).value;

      // Subject assertion
      final subjectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm.validated(statementIri) &&
            t.predicate == RdfTerms.subject,
      );
      expect(
        subjectTriple.object,
        equals(const IriTerm('http://example.org/JohnDoe')),
      );

      // Predicate assertion
      final predicateTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm.validated(statementIri) &&
            t.predicate == RdfTerms.predicate,
      );
      expect(
        predicateTriple.object,
        equals(const IriTerm('http://example.org/authorOf')),
      );

      // Object assertion
      final objectTriple = triples.firstWhere(
        (t) =>
            t.subject == IriTerm.validated(statementIri) &&
            t.predicate == RdfTerms.object,
      );
      expect(
        objectTriple.object,
        equals(const IriTerm('http://example.org/Book1')),
      );
    });

    test('serializes and round-trips reified statements correctly', () {
      // Create the original assertion
      final subject = const IriTerm('http://example.org/JohnDoe');
      final predicate = const IriTerm('http://example.org/authorOf');
      final object = const IriTerm('http://example.org/Book1');
      final originalTriple = Triple(subject, predicate, object);

      // Create the reification node
      // Use a baseUri compatible identifier
      final baseUri = 'http://example.org/doc';
      final localId = 'statement1';
      final statementNode = IriTerm.validated('$baseUri#$localId');

      // Create the reification triples
      final triples = <Triple>[
        originalTriple,
        Triple(statementNode, RdfTerms.type, RdfTerms.Statement),
        Triple(statementNode, RdfTerms.subject, subject),
        Triple(statementNode, RdfTerms.predicate, predicate),
        Triple(statementNode, RdfTerms.object, object),
        Triple(
          statementNode,
          const IriTerm('http://example.org/assertedBy'),
          LiteralTerm.string('Alice'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph, baseUri: baseUri);

      _log.finest('Serialized XML:');
      _log.finest(xml);

      // Re-parse from XML
      final parser = RdfXmlParser(xml, baseUri: baseUri);
      final reparsedTriples = parser.parse();

      // Print the reparsed triples for debugging
      _log.finest('Reparsed triples:');
      for (final triple in reparsedTriples) {
        _log.finest('${triple.subject} ${triple.predicate} ${triple.object}');
      }

      // Check that all original triples are present
      // We can't simply compare triples.length because serialization
      // might generate a different number of triples with the same semantics

      // Check the original statement is preserved - directly
      final originalFound = reparsedTriples.any(
        (t) =>
            t.subject == subject &&
            t.predicate == predicate &&
            t.object == object,
      );
      expect(
        originalFound,
        isTrue,
        reason: 'Original triple not found in reparsed data',
      );

      // Check the statement type - directly
      final typeFound = reparsedTriples.any(
        (t) =>
            t.subject == statementNode &&
            t.predicate == RdfTerms.type &&
            t.object == RdfTerms.Statement,
      );
      expect(
        typeFound,
        isTrue,
        reason: 'Statement type triple not found in reparsed data',
      );

      // Check the reification components - directly
      final subjectFound = reparsedTriples.any(
        (t) =>
            t.subject == statementNode &&
            t.predicate == RdfTerms.subject &&
            t.object == subject,
      );
      expect(
        subjectFound,
        isTrue,
        reason: 'Subject triple not found in reparsed data',
      );

      final predicateFound = reparsedTriples.any(
        (t) =>
            t.subject == statementNode &&
            t.predicate == RdfTerms.predicate &&
            t.object == predicate,
      );
      expect(
        predicateFound,
        isTrue,
        reason: 'Predicate triple not found in reparsed data',
      );

      final objectFound = reparsedTriples.any(
        (t) =>
            t.subject == statementNode &&
            t.predicate == RdfTerms.object &&
            t.object == object,
      );
      expect(
        objectFound,
        isTrue,
        reason: 'Object triple not found in reparsed data',
      );

      // Check the metadata assertion - directly
      final metadataFound = reparsedTriples.any(
        (t) =>
            t.subject == statementNode &&
            t.predicate == const IriTerm('http://example.org/assertedBy') &&
            t.object == LiteralTerm.string('Alice'),
      );
      expect(
        metadataFound,
        isTrue,
        reason: 'Metadata triple not found in reparsed data',
      );
    });

    test('serializes reified statements using rdf:ID syntax when possible', () {
      // Create the original triple
      final subject = const IriTerm('http://example.org/JohnDoe');
      final predicate = const IriTerm('http://example.org/authorOf');
      final object = const IriTerm('http://example.org/Book1');
      final originalTriple = Triple(subject, predicate, object);

      // Create the reification statement with proper baseUri handling
      final baseUri = 'http://example.org/doc';
      final localId = 'statement1';
      final statementNode = IriTerm.validated('$baseUri#$localId');

      // Create the reification triples
      final triples = <Triple>[
        originalTriple,
        Triple(statementNode, RdfTerms.type, RdfTerms.Statement),
        Triple(statementNode, RdfTerms.subject, subject),
        Triple(statementNode, RdfTerms.predicate, predicate),
        Triple(statementNode, RdfTerms.object, object),
        Triple(
          statementNode,
          const IriTerm('http://example.org/assertedBy'),
          LiteralTerm.string('Alice'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      // Set up custom namespaces for cleaner output
      final customPrefixes = {'ex': 'http://example.org/'};

      // Serialize to RDF/XML
      final serializer = RdfXmlSerializer();
      final xml = serializer.write(
        graph,
        baseUri: baseUri,
        customPrefixes: customPrefixes,
      );

      _log.finest('XML output for rdf:ID test:');
      _log.finest(xml);

      // The output should use rdf:ID for reification
      // But we need to check for the attribute and not the exact formatting
      expect(xml, contains('rdf:ID="statement1"'));

      // Also check that it's on the right property
      expect(xml, contains('ex:authorOf'));

      // Check the elements are related (in the same element)
      final containsAuthorOfWithID = RegExp(
        r'<ex:authorOf[^>]*rdf:ID="statement1"',
      ).hasMatch(xml);
      expect(
        containsAuthorOfWithID,
        isTrue,
        reason:
            'XML does not contain ex:authorOf with rdf:ID="statement1" attribute',
      );

      // Parse back to verify round-trip correctness
      final parser = RdfXmlParser(xml, baseUri: 'http://example.org/doc');
      final reparsedTriples = parser.parse();

      // We should have all 6 original triples after parsing
      // (The original statement + 5 reification triples)
      expect(reparsedTriples.length, equals(triples.length));

      // Verify the original triple is present
      final originalExists = reparsedTriples.any(
        (t) =>
            t.subject == subject &&
            t.predicate == predicate &&
            t.object == object,
      );
      expect(originalExists, isTrue);

      // Verify the reification statement type is present
      final typeExists = reparsedTriples.any(
        (t) =>
            (t.subject as IriTerm).value.contains('statement1') &&
            t.predicate == RdfTerms.type &&
            t.object ==
                const IriTerm(
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement',
                ),
      );
      expect(typeExists, isTrue);
    });
  });
}
