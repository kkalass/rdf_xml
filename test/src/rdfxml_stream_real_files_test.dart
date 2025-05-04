import 'dart:io';

import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/rdf_xml.dart';
import 'package:test/test.dart';

void main() {
  group('RDF/XML Stream Parsing with Real Files', () {
    test(
      'parses FOAF ontology with streaming and returns same triples as normal parsing',
      () async {
        final foafFile = File('test/assets/foaf.rdf');
        final xmlContent = foafFile.readAsStringSync();

        // Standard parse
        final parser = RdfXmlParser(
          xmlContent,
          baseUri: 'http://xmlns.com/foaf/0.1/',
        );
        final standardTriples = parser.parse();

        // Stream parse
        final streamParser = RdfXmlParser(
          xmlContent,
          baseUri: 'http://xmlns.com/foaf/0.1/',
        );
        final streamTriples = await streamParser.parseAsStream().toList();

        // Compare results
        expect(streamTriples.length, equals(standardTriples.length));

        // Both methods should yield the same triples (may be in different order)
        for (final triple in standardTriples) {
          expect(
            streamTriples,
            contains(triple),
            reason: 'Stream parsing should contain triple: $triple',
          );
        }

        // Check some key FOAF concepts are present
        final personClass = IriTerm('http://xmlns.com/foaf/0.1/Person');
        final foundPersonTriples = streamTriples.where(
          (triple) =>
              triple.subject == personClass || triple.object == personClass,
        );
        expect(foundPersonTriples, isNotEmpty);
      },
    );

    test(
      'parses SKOS ontology with streaming and returns same triples as normal parsing',
      () async {
        final skosFile = File('test/assets/skos.rdf');
        final xmlContent = skosFile.readAsStringSync();

        // Standard parse
        final parser = RdfXmlParser(
          xmlContent,
          baseUri: 'http://www.w3.org/2004/02/skos/core',
        );
        final standardTriples = parser.parse();

        // Stream parse
        final streamParser = RdfXmlParser(
          xmlContent,
          baseUri: 'http://www.w3.org/2004/02/skos/core',
        );
        final streamTriples = await streamParser.parseAsStream().toList();

        // Compare results
        expect(streamTriples.length, equals(standardTriples.length));

        // Both methods should yield the same triples (may be in different order)
        for (final triple in standardTriples) {
          expect(
            streamTriples,
            contains(triple),
            reason: 'Stream parsing should contain triple: $triple',
          );
        }

        // Check some key SKOS concepts are present
        final conceptClass = IriTerm(
          'http://www.w3.org/2004/02/skos/core#Concept',
        );
        final foundConceptTriples = streamTriples.where(
          (triple) =>
              triple.subject == conceptClass || triple.object == conceptClass,
        );
        expect(foundConceptTriples, isNotEmpty);
      },
    );

    test(
      'streaming parser handles RDF containers in real-world files',
      () async {
        // Create a file with containers for testing
        final tempDir = Directory.systemTemp.createTempSync('rdf_xml_test_');
        final tempFile = File('${tempDir.path}/containers.rdf');

        try {
          tempFile.writeAsStringSync('''
          <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                   xmlns:ex="http://example.org/">
            <!-- Bag container -->
            <rdf:Description rdf:about="http://example.org/container/bag">
              <ex:items>
                <rdf:Bag>
                  <rdf:li>Item 1</rdf:li>
                  <rdf:li>Item 2</rdf:li>
                  <rdf:li>Item 3</rdf:li>
                </rdf:Bag>
              </ex:items>
            </rdf:Description>
            
            <!-- Seq container -->
            <rdf:Description rdf:about="http://example.org/container/seq">
              <ex:orderedItems>
                <rdf:Seq>
                  <rdf:li>First</rdf:li>
                  <rdf:li>Second</rdf:li>
                  <rdf:li>Third</rdf:li>
                </rdf:Seq>
              </ex:orderedItems>
            </rdf:Description>
            
            <!-- Alt container -->
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
        ''');

          final xmlContent = tempFile.readAsStringSync();

          // Standard parse
          final parser = RdfXmlParser(xmlContent);
          final standardTriples = parser.parse();

          // Stream parse
          final streamParser = RdfXmlParser(xmlContent);
          final streamTriples = await streamParser.parseAsStream().toList();

          // Compare results
          expect(streamTriples.length, equals(standardTriples.length));

          // Both methods should yield the same triples
          for (final triple in standardTriples) {
            expect(
              streamTriples,
              contains(triple),
              reason: 'Stream parsing should contain triple: $triple',
            );
          }

          // Verify we have all three container types
          final bagType = IriTerm(
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#Bag',
          );
          final seqType = IriTerm(
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#Seq',
          );
          final altType = IriTerm(
            'http://www.w3.org/1999/02/22-rdf-syntax-ns#Alt',
          );

          // Find the type triples for each container
          final bagTypeTriple = streamTriples.firstWhere(
            (t) => t.predicate == RdfTerms.type && t.object == bagType,
          );
          final seqTypeTriple = streamTriples.firstWhere(
            (t) => t.predicate == RdfTerms.type && t.object == seqType,
          );
          final altTypeTriple = streamTriples.firstWhere(
            (t) => t.predicate == RdfTerms.type && t.object == altType,
          );

          expect(bagTypeTriple, isNotNull);
          expect(seqTypeTriple, isNotNull);
          expect(altTypeTriple, isNotNull);

          // Get the container nodes
          final bagNode = bagTypeTriple.subject;
          final seqNode = seqTypeTriple.subject;
          final altNode = altTypeTriple.subject;

          // Check that each container has the expected items
          final bagItems = streamTriples.where(
            (t) =>
                t.subject == bagNode &&
                (t.predicate as IriTerm).iri.startsWith(
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                ),
          );
          expect(bagItems, hasLength(3));

          final seqItems = streamTriples.where(
            (t) =>
                t.subject == seqNode &&
                (t.predicate as IriTerm).iri.startsWith(
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                ),
          );
          expect(seqItems, hasLength(3));

          final altItems = streamTriples.where(
            (t) =>
                t.subject == altNode &&
                (t.predicate as IriTerm).iri.startsWith(
                  'http://www.w3.org/1999/02/22-rdf-syntax-ns#_',
                ),
          );
          expect(altItems, hasLength(3));
        } finally {
          // Clean up
          tempFile.deleteSync();
          tempDir.deleteSync();
        }
      },
    );
  });
}
