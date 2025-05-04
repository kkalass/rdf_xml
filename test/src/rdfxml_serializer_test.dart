import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('RdfXmlSerializer', () {
    test('serializes basic triples to RDF/XML', () {
      final triple = Triple(
        IriTerm('http://example.org/subject'),
        IriTerm('http://example.org/predicate'),
        LiteralTerm.string('Object'),
      );

      final graph = RdfGraph(triples: [triple]);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML to check it
      final doc = XmlDocument.parse(xml);

      // Check that we have the right root element
      expect(doc.rootElement.name.qualified, equals('rdf:RDF'));

      // Check that we have the right namespace
      expect(
        doc.rootElement.getAttribute('xmlns:rdf'),
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
      );

      // Find the example.org namespace prefix
      String? exPrefix;
      for (final attr in doc.rootElement.attributes) {
        if (attr.name.prefix == 'xmlns' &&
            attr.value == 'http://example.org/') {
          exPrefix = attr.name.local;
          break;
        }
      }
      expect(
        exPrefix,
        isNotNull,
        reason: 'No namespace found for http://example.org/',
      );

      // Check that we have a description element
      final descriptions = doc.findAllElements('rdf:Description');
      expect(descriptions, hasLength(1));

      // Check that it has the right subject
      expect(
        descriptions.first.getAttribute('rdf:about'),
        equals('http://example.org/subject'),
      );

      // Check that it has a predicate element
      final predicates = descriptions.first.findElements('$exPrefix:predicate');
      expect(predicates, hasLength(1));

      // Check the predicate content
      expect(predicates.first.innerText, equals('Object'));
    });

    test('serializes typed resources', () {
      final subject = IriTerm('http://example.org/person/1');

      final inputTriples = [
        Triple(subject, RdfTerms.type, IriTerm('http://example.org/Person')),
        Triple(
          subject,
          IriTerm('http://example.org/name'),
          LiteralTerm.string('John Doe'),
        ),
      ];

      final graph = RdfGraph(triples: inputTriples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse back to RDF to check round-trip conversion
      final parser = RdfXmlParser(xml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(2));

      // Check the type triple
      final typeTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == RdfTerms.type.iri,
      );
      expect(typeTriple.subject, equals(subject));
      expect(typeTriple.object, equals(IriTerm('http://example.org/Person')));

      // Check the name triple
      final nameTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/name',
      );
      expect(nameTriple.subject, equals(subject));
      expect(nameTriple.object, equals(LiteralTerm.string('John Doe')));

      // Also check the XML structure - it should use the type as element name
      final doc = XmlDocument.parse(xml);

      // Find the example.org namespace prefix
      String? exPrefix;
      for (final attr in doc.rootElement.attributes) {
        if (attr.name.prefix == 'xmlns' &&
            attr.value == 'http://example.org/') {
          exPrefix = attr.name.local;
          break;
        }
      }
      expect(
        exPrefix,
        isNotNull,
        reason: 'No namespace found for http://example.org/',
      );

      final personElements = doc.findAllElements('$exPrefix:Person');
      expect(personElements, hasLength(1));
      expect(
        personElements.first.getAttribute('rdf:about'),
        equals('http://example.org/person/1'),
      );
    });

    test('serializes language-tagged literals', () {
      final subject = IriTerm('http://example.org/book/1');

      final triples = [
        Triple(
          subject,
          IriTerm('http://example.org/title'),
          LiteralTerm.withLanguage('The Lord of the Rings', 'en'),
        ),
        Triple(
          subject,
          IriTerm('http://example.org/title'),
          LiteralTerm.withLanguage('Der Herr der Ringe', 'de'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML
      final doc = XmlDocument.parse(xml);

      // Find the example.org namespace prefix
      String? exPrefix;
      for (final attr in doc.rootElement.attributes) {
        if (attr.name.prefix == 'xmlns' &&
            attr.value == 'http://example.org/') {
          exPrefix = attr.name.local;
          break;
        }
      }
      expect(
        exPrefix,
        isNotNull,
        reason: 'No namespace found for http://example.org/',
      );

      final titleElements = doc.findAllElements('$exPrefix:title');
      expect(titleElements, hasLength(2));

      // Find both language versions
      final englishTitle = titleElements.firstWhere(
        (e) => e.getAttribute('xml:lang') == 'en',
      );
      expect(englishTitle.innerText, equals('The Lord of the Rings'));

      final germanTitle = titleElements.firstWhere(
        (e) => e.getAttribute('xml:lang') == 'de',
      );
      expect(germanTitle.innerText, equals('Der Herr der Ringe'));
    });

    test('serializes datatyped literals', () {
      final subject = IriTerm('http://example.org/person/1');

      final triple = Triple(
        subject,
        IriTerm('http://example.org/age'),
        LiteralTerm(
          '42',
          datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
        ),
      );

      final graph = RdfGraph(triples: [triple]);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML
      final doc = XmlDocument.parse(xml);

      // Find the example.org namespace prefix
      String? exPrefix;
      for (final attr in doc.rootElement.attributes) {
        if (attr.name.prefix == 'xmlns' &&
            attr.value == 'http://example.org/') {
          exPrefix = attr.name.local;
          break;
        }
      }
      expect(
        exPrefix,
        isNotNull,
        reason: 'No namespace found for http://example.org/',
      );

      final ageElements = doc.findAllElements('$exPrefix:age');
      expect(ageElements, hasLength(1));

      // Check datatype
      expect(
        ageElements.first.getAttribute('rdf:datatype'),
        equals('http://www.w3.org/2001/XMLSchema#integer'),
      );
      expect(ageElements.first.innerText, equals('42'));
    });

    test('handles nested resources', () {
      final person = IriTerm('http://example.org/person/1');
      final address = BlankNodeTerm();

      final triples = [
        // Link person to address
        Triple(person, IriTerm('http://example.org/address'), address),

        // Add address properties
        Triple(address, RdfTerms.type, IriTerm('http://example.org/Address')),
        Triple(
          address,
          IriTerm('http://example.org/street'),
          LiteralTerm.string('123 Main St'),
        ),
        Triple(
          address,
          IriTerm('http://example.org/city'),
          LiteralTerm.string('Springfield'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML
      final doc = XmlDocument.parse(xml);

      // Find the example.org namespace prefix
      String? exPrefix;
      for (final attr in doc.rootElement.attributes) {
        if (attr.name.prefix == 'xmlns' &&
            attr.value == 'http://example.org/') {
          exPrefix = attr.name.local;
          break;
        }
      }
      expect(
        exPrefix,
        isNotNull,
        reason: 'No namespace found for http://example.org/',
      );

      // The document should have a Description element for the person
      final personElements = doc.findAllElements('rdf:Description');
      expect(personElements, hasLength(1));

      // It should have an address element
      final addressElements = personElements.first.findElements(
        '$exPrefix:address',
      );
      expect(addressElements, hasLength(1));

      // The address should have a nodeID reference
      expect(addressElements.first.getAttribute('rdf:nodeID'), isNotNull);

      // There should be an Address element
      final addressTypeElements = doc.findAllElements('$exPrefix:Address');
      expect(addressTypeElements, hasLength(1));

      // It should have the same nodeID
      expect(
        addressTypeElements.first.getAttribute('rdf:nodeID'),
        equals(addressElements.first.getAttribute('rdf:nodeID')),
      );

      // Check for street and city
      final streetElements = addressTypeElements.first.findElements(
        '$exPrefix:street',
      );
      expect(streetElements, hasLength(1));
      expect(streetElements.first.innerText, equals('123 Main St'));

      final cityElements = addressTypeElements.first.findElements(
        '$exPrefix:city',
      );
      expect(cityElements, hasLength(1));
      expect(cityElements.first.innerText, equals('Springfield'));
    });
  });
}
