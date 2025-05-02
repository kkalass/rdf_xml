import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

void main() {
  group('RdfXmlParser', () {
    test('parses basic RDF/XML', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/subject">
    <ex:predicate>Object</ex:predicate>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/subject')));
      expect(triple.predicate, equals(IriTerm('http://example.org/predicate')));
      expect(triple.object, equals(LiteralTerm.string('Object')));
    });

    test('parses typed resources', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <ex:Person rdf:about="http://example.org/john">
    <ex:name>John</ex:name>
  </ex:Person>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(2));

      // Find the type triple
      final typeTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri == RdfPredicates.type.iri,
      );

      expect(typeTriple.subject, equals(IriTerm('http://example.org/john')));
      expect(typeTriple.predicate, equals(RdfPredicates.type));
      expect(typeTriple.object, equals(IriTerm('http://example.org/Person')));

      // Find the name triple
      final nameTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('name'),
      );

      expect(nameTriple.subject, equals(IriTerm('http://example.org/john')));
      expect(nameTriple.predicate, equals(IriTerm('http://example.org/name')));
      expect(nameTriple.object, equals(LiteralTerm.string('John')));
    });

    test('parses rdf:resource references', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:knows rdf:resource="http://example.org/jane"/>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/knows')));
      expect(triple.object, equals(IriTerm('http://example.org/jane')));
    });

    test('parses nested resource descriptions', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:address>
      <ex:Address>
        <ex:street>123 Main St</ex:street>
        <ex:city>Anytown</ex:city>
      </ex:Address>
    </ex:address>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(4));

      // Find the address triple
      final addressTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('address'),
      );

      expect(addressTriple.subject, equals(IriTerm('http://example.org/john')));
      expect(
        addressTriple.predicate,
        equals(IriTerm('http://example.org/address')),
      );
      expect(addressTriple.object, isA<BlankNodeTerm>());

      // Get the blank node for the address
      final addressNode = addressTriple.object as BlankNodeTerm;

      // Find the type triple for the address
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.type.iri,
      );

      expect(typeTriple.object, equals(IriTerm('http://example.org/Address')));

      // Find the street triple
      final streetTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri.endsWith('street'),
      );

      expect(
        streetTriple.predicate,
        equals(IriTerm('http://example.org/street')),
      );
      expect(streetTriple.object, equals(LiteralTerm.string('123 Main St')));

      // Find the city triple
      final cityTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri.endsWith('city'),
      );

      expect(cityTriple.predicate, equals(IriTerm('http://example.org/city')));
      expect(cityTriple.object, equals(LiteralTerm.string('Anytown')));
    });

    test('parses typed literals', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xmlns:xsd="http://www.w3.org/2001/XMLSchema#">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:age rdf:datatype="http://www.w3.org/2001/XMLSchema#integer">42</ex:age>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/age')));

      final literalObj = triple.object as LiteralTerm;
      expect(literalObj.value, equals('42'));
      expect(
        literalObj.datatype,
        equals(IriTerm('http://www.w3.org/2001/XMLSchema#integer')),
      );
    });

    test('parses language-tagged literals', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:greeting xml:lang="en">Hello</ex:greeting>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/greeting')));

      final literalObj = triple.object as LiteralTerm;
      expect(literalObj.value, equals('Hello'));
      expect(literalObj.language, equals('en'));
    });

    test('parses parseType="Resource"', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:address rdf:parseType="Resource">
      <ex:street>123 Main St</ex:street>
      <ex:city>Anytown</ex:city>
    </ex:address>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(3));

      // Find the address triple
      final addressTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('address'),
      );

      expect(addressTriple.subject, equals(IriTerm('http://example.org/john')));
      expect(
        addressTriple.predicate,
        equals(IriTerm('http://example.org/address')),
      );
      expect(addressTriple.object, isA<BlankNodeTerm>());

      // Get the blank node for the address
      final addressNode = addressTriple.object as BlankNodeTerm;

      // Find the street triple
      final streetTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri.endsWith('street'),
      );

      expect(
        streetTriple.predicate,
        equals(IriTerm('http://example.org/street')),
      );
      expect(streetTriple.object, equals(LiteralTerm.string('123 Main St')));

      // Find the city triple
      final cityTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).iri.endsWith('city'),
      );

      expect(cityTriple.predicate, equals(IriTerm('http://example.org/city')));
      expect(cityTriple.object, equals(LiteralTerm.string('Anytown')));
    });

    test('parses parseType="Literal"', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:html rdf:parseType="Literal">
      <strong>Hello</strong> <em>World</em>!
    </ex:html>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/html')));

      final literalObj = triple.object as LiteralTerm;
      expect(
        literalObj.value.trim().replaceAll(RegExp(r'\s+'), ' '),
        equals('<strong>Hello</strong> <em>World</em>!'),
      );
      expect(
        literalObj.datatype.iri,
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral'),
      );
    });

    test('parses parseType="Collection"', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:about="http://example.org/john">
    <ex:friends rdf:parseType="Collection">
      <rdf:Description rdf:about="http://example.org/jane"/>
      <rdf:Description rdf:about="http://example.org/bob"/>
      <rdf:Description rdf:about="http://example.org/alice"/>
    </ex:friends>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      // A collection with 3 items will generate:
      // - 1 triple linking subject to the first list node
      // - 3 rdf:first triples
      // - 3 rdf:rest triples (last one pointing to rdf:nil)
      expect(triples, hasLength(7));

      // Find the friends triple
      final friendsTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('friends'),
      );

      expect(friendsTriple.subject, equals(IriTerm('http://example.org/john')));
      expect(
        friendsTriple.predicate,
        equals(IriTerm('http://example.org/friends')),
      );
      expect(friendsTriple.object, isA<BlankNodeTerm>());

      // Get the first list node
      final firstListNode = friendsTriple.object as BlankNodeTerm;

      // Find the first item
      final firstItemTriple = triples.firstWhere(
        (t) =>
            t.subject == firstListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.first.iri,
      );

      expect(
        firstItemTriple.object,
        equals(IriTerm('http://example.org/jane')),
      );

      // Find the rest of the first list node
      final firstRestTriple = triples.firstWhere(
        (t) =>
            t.subject == firstListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.rest.iri,
      );

      expect(firstRestTriple.object, isA<BlankNodeTerm>());

      // Get the second list node
      final secondListNode = firstRestTriple.object as BlankNodeTerm;

      // Find the second item
      final secondItemTriple = triples.firstWhere(
        (t) =>
            t.subject == secondListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.first.iri,
      );

      expect(
        secondItemTriple.object,
        equals(IriTerm('http://example.org/bob')),
      );

      // Find the rest of the second list node
      final secondRestTriple = triples.firstWhere(
        (t) =>
            t.subject == secondListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.rest.iri,
      );

      expect(secondRestTriple.object, isA<BlankNodeTerm>());

      // Get the third list node
      final thirdListNode = secondRestTriple.object as BlankNodeTerm;

      // Find the third item
      final thirdItemTriple = triples.firstWhere(
        (t) =>
            t.subject == thirdListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.first.iri,
      );

      expect(
        thirdItemTriple.object,
        equals(IriTerm('http://example.org/alice')),
      );

      // Find the rest of the third list node (should be rdf:nil)
      final thirdRestTriple = triples.firstWhere(
        (t) =>
            t.subject == thirdListNode &&
            (t.predicate as IriTerm).iri == RdfPredicates.rest.iri,
      );

      expect(thirdRestTriple.object, equals(RdfResources.nil));
    });

    test('parses rdf:ID attribute', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/"
         xml:base="http://example.org/doc">
  <rdf:Description rdf:ID="john">
    <ex:name>John</ex:name>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(1));

      final triple = triples.first;
      expect(triple.subject, equals(IriTerm('http://example.org/doc#john')));
      expect(triple.predicate, equals(IriTerm('http://example.org/name')));
      expect(triple.object, equals(LiteralTerm.string('John')));
    });

    test('parses rdf:nodeID attribute', () {
      final rdfXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:ex="http://example.org/">
  <rdf:Description rdf:nodeID="n1">
    <ex:name>John</ex:name>
  </rdf:Description>
  <rdf:Description rdf:about="http://example.org/group">
    <ex:member rdf:nodeID="n1"/>
  </rdf:Description>
</rdf:RDF>
''';

      final parser = RdfXmlParser(rdfXml);
      final triples = parser.parse();

      expect(triples, hasLength(2));

      // Find the name triple
      final nameTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('name'),
      );

      expect(nameTriple.subject, isA<BlankNodeTerm>());
      expect(nameTriple.predicate, equals(IriTerm('http://example.org/name')));
      expect(nameTriple.object, equals(LiteralTerm.string('John')));

      // Find the member triple
      final memberTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).iri.endsWith('member'),
      );

      expect(memberTriple.subject, equals(IriTerm('http://example.org/group')));
      expect(
        memberTriple.predicate,
        equals(IriTerm('http://example.org/member')),
      );

      // The blank node should be the same in both triples
      expect(memberTriple.object, equals(nameTriple.subject));
    });
  });
}
