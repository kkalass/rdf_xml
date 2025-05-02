import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:rdf_xml/src/rdfxml_serializer.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  group('RdfXmlSerializer', () {
    test('serializes a basic triple', () {
      final serializer = RdfXmlSerializer();

      // Create a simple triple
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = LiteralTerm.string('Object');
      final triple = Triple(subject, predicate, object);

      // Create a graph with the triple
      final graph = RdfGraph.fromTriples([triple]);

      // Serialize to RDF/XML
      final rdfXml = serializer.write(graph);

      // Basic validation of the XML structure
      final document = XmlDocument.parse(rdfXml);
      expect(document.rootElement.name.qualified, equals('rdf:RDF'));
      expect(
        document.rootElement.getAttribute('xmlns:rdf'),
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
      );

      // Find the Description element
      final description = document.findAllElements('rdf:Description').first;
      expect(
        description.getAttribute('rdf:about'),
        equals('http://example.org/subject'),
      );

      // Verify that the predicate and object are correctly serialized
      final predicateElement = description.findElements('*').first;
      expect(predicateElement.name.qualified.endsWith('predicate'), isTrue);
      expect(predicateElement.innerText, equals('Object'));

      // Round-trip: Parse the serialized output to verify it produces the original triple
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(1));
      final parsedTriple = parsedTriples.first;
      expect(parsedTriple.subject, equals(subject));
      expect(parsedTriple.predicate, equals(predicate));
      expect(parsedTriple.object, equals(object));
    });

    test('serializes typed resources', () {
      final serializer = RdfXmlSerializer();

      // Create a resource with a type and a property
      final subject = IriTerm('http://example.org/john');
      final typeTriple = Triple(
        subject,
        RdfPredicates.type,
        IriTerm('http://example.org/Person'),
      );
      final nameTriple = Triple(
        subject,
        IriTerm('http://example.org/name'),
        LiteralTerm.string('John'),
      );

      // Create a graph with the triples
      final graph = RdfGraph.fromTriples([typeTriple, nameTriple]);

      // Serialize to RDF/XML
      final rdfXml = serializer.write(graph);

      // Parse the XML to verify the structure
      final document = XmlDocument.parse(rdfXml);

      // In RDF/XML, types can be represented as element names
      // Depending on the serializer implementation, it might use either:
      // <ex:Person rdf:about="http://example.org/john">...</ex:Person>
      // or
      // <rdf:Description rdf:about="http://example.org/john"><rdf:type rdf:resource="http://example.org/Person"/>...</rdf:Description>

      // Round-trip: Parse the serialized output
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(2));

      // Find the type triple
      final parsedTypeTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('type'),
      );

      expect(parsedTypeTriple.subject, equals(subject));
      expect(parsedTypeTriple.predicate, equals(RdfPredicates.type));
      expect(
        (parsedTypeTriple.object as IriTerm).iri,
        equals('http://example.org/Person'),
      );

      // Find the name triple
      final parsedNameTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('name'),
      );

      expect(parsedNameTriple.subject, equals(subject));
      expect(
        (parsedNameTriple.predicate as IriTerm).iri,
        equals('http://example.org/name'),
      );
      expect((parsedNameTriple.object as LiteralTerm).value, equals('John'));
    });

    test('serializes blank nodes', () {
      final serializer = RdfXmlSerializer();

      // Create a resource with a blank node object
      final subject = IriTerm('http://example.org/john');
      final blankNode = BlankNodeTerm();
      final knowsTriple = Triple(
        subject,
        IriTerm('http://example.org/knows'),
        blankNode,
      );
      final nameTriple = Triple(
        blankNode,
        IriTerm('http://example.org/name'),
        LiteralTerm.string('Jane'),
      );

      // Create a graph with the triples
      final graph = RdfGraph.fromTriples([knowsTriple, nameTriple]);

      // Serialize to RDF/XML
      final rdfXml = serializer.write(graph);

      // Round-trip: Parse the serialized output
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(2));

      // Find the knows triple
      final parsedKnowsTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('knows'),
      );

      expect(parsedKnowsTriple.subject, equals(subject));
      expect(parsedKnowsTriple.object, isA<BlankNodeTerm>());

      // Find the name triple
      final parsedNameTriple = parsedTriples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('name'),
      );

      expect(parsedNameTriple.subject, equals(parsedKnowsTriple.object));
      expect((parsedNameTriple.object as LiteralTerm).value, equals('Jane'));
    });

    test('serializes typed literals', () {
      final serializer = RdfXmlSerializer();

      // Create a triple with a typed literal
      final subject = IriTerm('http://example.org/john');
      final predicate = IriTerm('http://example.org/age');
      final object = LiteralTerm(
        '42',
        datatype: IriTerm('http://www.w3.org/2001/XMLSchema#integer'),
      );
      final triple = Triple(subject, predicate, object);

      // Create a graph with the triple
      final graph = RdfGraph.fromTriples([triple]);

      // Serialize to RDF/XML
      final rdfXml = serializer.write(graph);

      // Parse the XML to verify the structure
      final document = XmlDocument.parse(rdfXml);
      final description = document.findAllElements('rdf:Description').first;
      final ageElement = description.findElements('*').first;

      expect(ageElement.name.qualified.endsWith('age'), isTrue);
      expect(ageElement.innerText, equals('42'));
      expect(
        ageElement.getAttribute('rdf:datatype'),
        equals('http://www.w3.org/2001/XMLSchema#integer'),
      );

      // Round-trip: Parse the serialized output
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(1));
      final parsedTriple = parsedTriples.first;

      expect(parsedTriple.subject, equals(subject));
      expect(parsedTriple.predicate, equals(predicate));
      expect((parsedTriple.object as LiteralTerm).value, equals('42'));
      expect(
        (parsedTriple.object as LiteralTerm).datatype.iri,
        equals('http://www.w3.org/2001/XMLSchema#integer'),
      );
    });

    test('serializes language-tagged literals', () {
      final serializer = RdfXmlSerializer();

      // Create a triple with a language-tagged literal
      final subject = IriTerm('http://example.org/john');
      final predicate = IriTerm('http://example.org/greeting');
      final object = LiteralTerm.withLanguage('Hello', 'en');
      final triple = Triple(subject, predicate, object);

      // Create a graph with the triple
      final graph = RdfGraph.fromTriples([triple]);

      // Serialize to RDF/XML
      final rdfXml = serializer.write(graph);

      // Parse the XML to verify the structure
      final document = XmlDocument.parse(rdfXml);
      final description = document.findAllElements('rdf:Description').first;
      final greetingElement = description.findElements('*').first;

      expect(greetingElement.name.qualified.endsWith('greeting'), isTrue);
      expect(greetingElement.innerText, equals('Hello'));
      expect(greetingElement.getAttribute('xml:lang'), equals('en'));

      // Round-trip: Parse the serialized output
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(1));
      final parsedTriple = parsedTriples.first;

      expect(parsedTriple.subject, equals(subject));
      expect(parsedTriple.predicate, equals(predicate));
      expect((parsedTriple.object as LiteralTerm).value, equals('Hello'));
      expect((parsedTriple.object as LiteralTerm).language, equals('en'));
    });

    test('handles custom namespace prefixes', () {
      final serializer = RdfXmlSerializer();

      // Create a triple
      final subject = IriTerm('http://example.org/subject');
      final predicate = IriTerm('http://example.org/predicate');
      final object = LiteralTerm.string('Object');
      final triple = Triple(subject, predicate, object);

      // Create a graph with the triple
      final graph = RdfGraph.fromTriples([triple]);

      // Custom prefix mappings
      final customPrefixes = {'ex': 'http://example.org/'};

      // Serialize to RDF/XML with custom prefixes
      final rdfXml = serializer.write(graph, customPrefixes: customPrefixes);

      // Parse the XML to verify the structure
      final document = XmlDocument.parse(rdfXml);

      // Verify that the custom prefix is used
      expect(
        document.rootElement.getAttribute('xmlns:ex'),
        equals('http://example.org/'),
      );

      // Round-trip: Parse the serialized output
      final parser = RdfXmlParser(rdfXml);
      final parsedTriples = parser.parse();

      expect(parsedTriples, hasLength(1));
      final parsedTriple = parsedTriples.first;

      expect(parsedTriple.subject, equals(subject));
      expect(parsedTriple.predicate, equals(predicate));
      expect(parsedTriple.object, equals(object));
    });
  });
}
