import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlParser', () {
    test('parses basic RDF/XML', () {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <rdf:Description rdf:about="http://example.org/subject">
            <ex:predicate>Object</ex:predicate>
          </rdf:Description>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final triples = parser.parse();

      expect(triples, hasLength(1));
      expect(triples[0].subject, equals(IriTerm('http://example.org/subject')));
      expect(
        triples[0].predicate,
        equals(IriTerm('http://example.org/predicate')),
      );
      expect(triples[0].object, equals(LiteralTerm.string('Object')));
    });

    test('parses typed nodes', () {
      final xml = '''
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                 xmlns:ex="http://example.org/">
          <ex:Person rdf:about="http://example.org/person/1">
            <ex:name>John Doe</ex:name>
          </ex:Person>
        </rdf:RDF>
      ''';

      final parser = RdfXmlParser(xml);
      final triples = parser.parse();

      expect(triples, hasLength(2));

      // Find the type triple
      final typeTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == RdfTerms.type.iri,
      );

      expect(
        typeTriple.subject,
        equals(IriTerm('http://example.org/person/1')),
      );
      expect(typeTriple.predicate, equals(RdfTerms.type));
      expect(typeTriple.object, equals(IriTerm('http://example.org/Person')));

      // Find the name triple
      final nameTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == 'http://example.org/name',
      );

      expect(
        nameTriple.subject,
        equals(IriTerm('http://example.org/person/1')),
      );
      expect(nameTriple.predicate, equals(IriTerm('http://example.org/name')));
      expect(nameTriple.object, equals(LiteralTerm.string('John Doe')));
    });

    test('handles language tags', () {
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
      final triples = parser.parse();

      // Debug output to understand what triples we actually got
      for (final triple in triples) {
        print('Subject: ${triple.subject}');
        print('Predicate: ${triple.predicate}');
        print('Object: ${triple.object}');

        if (triple.object is LiteralTerm) {
          final literal = triple.object as LiteralTerm;
          print('  Language: ${literal.language}');
          print('  Datatype: ${literal.datatype}');
          print('  Value: ${literal.value}');
        }
        print('-----');
      }

      expect(triples, hasLength(2));

      final englishTitle = triples.firstWhere(
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

      final germanTitle = triples.firstWhere(
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

    test('handles nested resources', () {
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
      final triples = parser.parse();

      // Debug output to understand what triples we actually got
      print('Total triples: ${triples.length}');
      for (int i = 0; i < triples.length; i++) {
        final triple = triples[i];
        print('Triple $i:');
        print('  Subject: ${triple.subject}');
        print('  Predicate: ${triple.predicate}');
        print('  Object: ${triple.object}');
        print('-----');
      }

      expect(triples, hasLength(4));

      // Find the address triple that links the person to the address
      final addressTriple = triples.firstWhere(
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
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == RdfTerms.type.iri,
        orElse: () => throw StateError('No type triple found for address'),
      );

      expect(typeTriple.object, equals(IriTerm('http://example.org/Address')));

      // Find the street triple
      final streetTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == 'http://example.org/street',
        orElse: () => throw StateError('No street triple found for address'),
      );

      expect(streetTriple.object, equals(LiteralTerm.string('123 Main St')));

      // Find the city triple
      final cityTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == 'http://example.org/city',
        orElse: () => throw StateError('No city triple found for address'),
      );

      expect(cityTriple.object, equals(LiteralTerm.string('Springfield')));
    });

    test('handles RDF collections', () {
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
      final triples = parser.parse();

      // We expect:
      // 1. ex:list ex:items _:b1
      // 2. _:b1 rdf:first ex:item/1
      // 3. _:b1 rdf:rest _:b2
      // 4. _:b2 rdf:first ex:item/2
      // 5. _:b2 rdf:rest _:b3
      // 6. _:b3 rdf:first ex:item/3
      // 7. _:b3 rdf:rest rdf:nil
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
    });
  });
}
