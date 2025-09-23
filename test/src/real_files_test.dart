import 'dart:io';

import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';

final _log = Logger('Real RDF Tests');
void main() {
  group('Real RDF files', () {
    test('Foaf as turtle', () {
      final foafFile = File('test/assets/foaf.rdf');
      final xmlContent = foafFile.readAsStringSync();
      final foafTurtleFile = File('test/assets/foaf.ttl');
      final expectedTurtle = foafTurtleFile.readAsStringSync();
      final rdfCore = RdfCore.withStandardCodecs(
        additionalCodecs: [RdfXmlCodec()],
      );
      final graph = rdfCore.decode(
        xmlContent,
        contentType: 'application/rdf+xml',
        documentUrl: 'http://xmlns.com/foaf/0.1/',
      );
      final turtle = rdfCore.encode(
        graph,
        options: TurtleEncoderOptions(
          customPrefixes: {
            'wot': 'http://xmlns.com/wot/0.1/',
            // override the default prefix for schema.org which goes to https://schema.org/
            'schema': 'http://schema.org/',
          },
        ),
      );

      _log.finest('Serialized FOAF to Turtle format: $turtle');
      expect(turtle.trim(), equals(expectedTurtle.trim()));
    });

    test('parse and validate FOAF ontology file', () {
      final foafFile = File('test/assets/foaf.rdf');
      final xmlContent = foafFile.readAsStringSync();

      // Parse the file with a base URI
      final parser = RdfXmlParser(
        xmlContent,
        baseUri: 'http://xmlns.com/foaf/0.1/',
      );
      final triples = parser.parse();

      // Validate basic FOAF ontology structure
      expect(triples, isNotEmpty);
      _log.finest('Parsed ${triples.length} triples from FOAF');

      // Create a graph for further analysis
      final graph = RdfGraph(triples: triples);

      // Check for some key FOAF classes
      final personClass = const IriTerm('http://xmlns.com/foaf/0.1/Person');
      final documentClass = const IriTerm('http://xmlns.com/foaf/0.1/Document');
      final agentClass = const IriTerm('http://xmlns.com/foaf/0.1/Agent');

      // In RDFS/OWL ontologies, classes are often defined as subjects of rdfs:Class or owl:Class
      final rdfsClass = const IriTerm(
        'http://www.w3.org/2000/01/rdf-schema#Class',
      );
      final owlClass = const IriTerm('http://www.w3.org/2002/07/owl#Class');

      expect(
        graph.triples
            .where(
              (t) =>
                  (t.subject == personClass) &&
                  (t.predicate == RdfTerms.type &&
                          (t.object == rdfsClass || t.object == owlClass) ||
                      t.predicate ==
                          const IriTerm(
                            'http://www.w3.org/2000/01/rdf-schema#label',
                          )),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF Person class not found',
      );

      expect(
        graph.triples
            .where(
              (t) =>
                  (t.subject == documentClass) &&
                  (t.predicate == RdfTerms.type &&
                          (t.object == rdfsClass || t.object == owlClass) ||
                      t.predicate ==
                          const IriTerm(
                            'http://www.w3.org/2000/01/rdf-schema#label',
                          )),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF Document class not found',
      );

      expect(
        graph.triples
            .where(
              (t) =>
                  (t.subject == agentClass) &&
                  (t.predicate == RdfTerms.type &&
                          (t.object == rdfsClass || t.object == owlClass) ||
                      t.predicate ==
                          const IriTerm(
                            'http://www.w3.org/2000/01/rdf-schema#label',
                          )),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF Agent class not found',
      );

      // Check for some key FOAF properties
      final nameProp = const IriTerm('http://xmlns.com/foaf/0.1/name');
      final knowsProp = const IriTerm('http://xmlns.com/foaf/0.1/knows');
      final mboxProp = const IriTerm('http://xmlns.com/foaf/0.1/mbox');

      // In RDF/OWL properties are defined as rdf:Property or owl:ObjectProperty/DatatypeProperty
      final rdfProperty = const IriTerm(
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#Property',
      );
      final owlObjectProperty = const IriTerm(
        'http://www.w3.org/2002/07/owl#ObjectProperty',
      );
      final owlDatatypeProperty = const IriTerm(
        'http://www.w3.org/2002/07/owl#DatatypeProperty',
      );

      expect(
        graph.triples
            .where(
              (t) =>
                  t.subject == nameProp &&
                  (t.predicate == RdfTerms.type &&
                      (t.object == rdfProperty ||
                          t.object == owlDatatypeProperty ||
                          t.object == owlObjectProperty)),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF name property not found',
      );

      expect(
        graph.triples
            .where(
              (t) =>
                  t.subject == knowsProp &&
                  (t.predicate == RdfTerms.type &&
                      (t.object == rdfProperty ||
                          t.object == owlDatatypeProperty ||
                          t.object == owlObjectProperty)),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF knows property not found',
      );

      expect(
        graph.triples
            .where(
              (t) =>
                  t.subject == mboxProp &&
                  (t.predicate == RdfTerms.type &&
                      (t.object == rdfProperty ||
                          t.object == owlDatatypeProperty ||
                          t.object == owlObjectProperty)),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF mbox property not found',
      );

      // Test round-trip serialization
      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(graph);

      // Re-parse the serialized data
      final reparsedTriples =
          RdfXmlParser(
            serializedXml,
            baseUri: 'http://xmlns.com/foaf/0.1/',
          ).parse();
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // The number of triples may differ between original and serialized forms
      // due to different serialization strategies, but the semantics should be equivalent
      expect(reparsedTriples, isNotEmpty);
      _log.finest(
        'Re-parsed ${reparsedTriples.length} triples from serialized FOAF',
      );

      // Check that key classes are still present after round-trip
      expect(
        reparsedGraph.triples
            .where(
              (t) =>
                  t.subject == personClass &&
                  (t.predicate == RdfTerms.type ||
                      t.predicate ==
                          const IriTerm(
                            'http://www.w3.org/2000/01/rdf-schema#label',
                          )),
            )
            .isNotEmpty,
        isTrue,
        reason: 'FOAF Person class not found after round-trip',
      );
    });

    test('parse and validate SKOS ontology file', () {
      final skosFile = File('test/assets/skos.rdf');
      final xmlContent = skosFile.readAsStringSync();

      // Parse the file with a base URI for SKOS
      final parser = RdfXmlParser(
        xmlContent,
        baseUri: 'http://www.w3.org/2004/02/skos/core',
      );
      final triples = parser.parse();

      // Validate basic SKOS ontology structure
      expect(triples, isNotEmpty);
      _log.finest('Parsed ${triples.length} triples from SKOS');

      // Create a graph for further analysis
      final graph = RdfGraph(triples: triples);

      // Check for some key SKOS classes with full URIs
      final conceptClass = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#Concept',
      );
      final conceptSchemeClass = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#ConceptScheme',
      );
      final collectionClass = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#Collection',
      );

      // Verify these classes exist in the model by checking if they have any statements
      expect(
        graph.triples.where((t) => t.subject == conceptClass).isNotEmpty,
        isTrue,
        reason: 'SKOS Concept class not found',
      );

      expect(
        graph.triples.where((t) => t.subject == conceptSchemeClass).isNotEmpty,
        isTrue,
        reason: 'SKOS ConceptScheme class not found',
      );

      expect(
        graph.triples.where((t) => t.subject == collectionClass).isNotEmpty,
        isTrue,
        reason: 'SKOS Collection class not found',
      );

      // Check for some key SKOS properties
      final prefLabelProp = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#prefLabel',
      );
      final broaderProp = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#broader',
      );
      final narrowerProp = const IriTerm(
        'http://www.w3.org/2004/02/skos/core#narrower',
      );

      expect(
        graph.triples.where((t) => t.subject == prefLabelProp).isNotEmpty,
        isTrue,
        reason: 'SKOS prefLabel property not found',
      );

      expect(
        graph.triples.where((t) => t.subject == broaderProp).isNotEmpty,
        isTrue,
        reason: 'SKOS broader property not found',
      );

      expect(
        graph.triples.where((t) => t.subject == narrowerProp).isNotEmpty,
        isTrue,
        reason: 'SKOS narrower property not found',
      );

      // Test round-trip serialization
      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(graph);

      // Re-parse the serialized data
      final reparsedTriples =
          RdfXmlParser(
            serializedXml,
            baseUri: 'http://www.w3.org/2004/02/skos/core',
          ).parse();
      final reparsedGraph = RdfGraph(triples: reparsedTriples);

      // The number of triples may differ between original and serialized forms
      // due to different serialization strategies, but the semantics should be equivalent
      expect(reparsedTriples, isNotEmpty);
      _log.finest(
        'Re-parsed ${reparsedTriples.length} triples from serialized SKOS',
      );

      // Check that key classes and properties are still present after round-trip
      expect(
        reparsedGraph.triples
            .where((t) => t.subject == conceptClass)
            .isNotEmpty,
        isTrue,
        reason: 'SKOS Concept class not found after round-trip',
      );
    });

    test('roundtrip test with FOAF subset', () {
      final foafFile = File('test/assets/foaf.rdf');
      final xmlContent = foafFile.readAsStringSync();

      // Parse the file with a base URI
      final parser = RdfXmlParser(
        xmlContent,
        baseUri: 'http://xmlns.com/foaf/0.1/',
      );
      final allTriples = parser.parse();

      // Just take a small subset of triples (first 50) for testing round-trip conversion
      final subsetTriples = allTriples.take(50).toList();
      final smallGraph = RdfGraph(triples: subsetTriples);

      // Serialize and re-parse this specific subset
      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(smallGraph);

      final reparsedTriples =
          RdfXmlParser(
            serializedXml,
            baseUri: 'http://xmlns.com/foaf/0.1/',
          ).parse();

      // Eine hochwertige Implementierung sollte mindestens 95% der Triples erhalten
      expect(
        reparsedTriples.length >= 0.95 * subsetTriples.length,
        isTrue,
        reason:
            'Zu wenige Triples nach Roundtrip: ${reparsedTriples.length} < ${0.95 * subsetTriples.length}',
      );

      // Überprüfe, dass alle wichtigen semantischen Beziehungen erhalten bleiben
      // Sammle alle subject-predicate Paare und vergleiche diese
      final originalPairs =
          subsetTriples
              .map((triple) => '${triple.subject}|${triple.predicate}')
              .toSet();
      final reparsedPairs =
          reparsedTriples
              .map((triple) => '${triple.subject}|${triple.predicate}')
              .toSet();

      // Wichtige Beziehungen sollten erhalten bleiben (mindestens 90%)
      final preservedPairsCount =
          originalPairs.where((pair) => reparsedPairs.contains(pair)).length;

      expect(
        preservedPairsCount >= 0.9 * originalPairs.length,
        isTrue,
        reason:
            'Zu viele semantische Beziehungen gingen verloren: $preservedPairsCount < ${0.9 * originalPairs.length}',
      );
    });

    test('roundtrip test with SKOS subset', () {
      final skosFile = File('test/assets/skos.rdf');
      final xmlContent = skosFile.readAsStringSync();

      // Parse the file with a base URI
      final parser = RdfXmlParser(
        xmlContent,
        baseUri: 'http://www.w3.org/2004/02/skos/core',
      );
      final allTriples = parser.parse();

      // Just take a small subset of triples (first 50) for testing round-trip conversion
      final subsetTriples = allTriples.take(50).toList();
      final smallGraph = RdfGraph(triples: subsetTriples);

      // Serialize and re-parse this specific subset
      final serializer = RdfXmlSerializer();
      final serializedXml = serializer.write(smallGraph);

      final reparsedTriples =
          RdfXmlParser(
            serializedXml,
            baseUri: 'http://www.w3.org/2004/02/skos/core',
          ).parse();

      // Eine hochwertige Implementierung sollte mindestens 95% der Triples erhalten
      expect(
        reparsedTriples.length >= 0.95 * subsetTriples.length,
        isTrue,
        reason:
            'Zu wenige Triples nach Roundtrip: ${reparsedTriples.length} < ${0.95 * subsetTriples.length}',
      );

      // Überprüfe, dass alle wichtigen semantischen Beziehungen erhalten bleiben
      // Sammle alle subject-predicate Paare und vergleiche diese
      final originalPairs =
          subsetTriples
              .map((triple) => '${triple.subject}|${triple.predicate}')
              .toSet();
      final reparsedPairs =
          reparsedTriples
              .map((triple) => '${triple.subject}|${triple.predicate}')
              .toSet();

      // Wichtige Beziehungen sollten erhalten bleiben (mindestens 90%)
      final preservedPairsCount =
          originalPairs.where((pair) => reparsedPairs.contains(pair)).length;

      expect(
        preservedPairsCount >= 0.9 * originalPairs.length,
        isTrue,
        reason:
            'Zu viele semantische Beziehungen gingen verloren: $preservedPairsCount < ${0.9 * originalPairs.length}',
      );
    });
  });
}
