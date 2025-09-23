import 'package:logging/logging.dart';
import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/rdfxml_constants.dart';
import 'package:rdf_xml/src/rdfxml_parser.dart';
import 'package:test/test.dart';

final _log = Logger('RdfXmlParserTest');

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
      expect(
        triples[0].subject,
        equals(const IriTerm('http://example.org/subject')),
      );
      expect(
        triples[0].predicate,
        equals(const IriTerm('http://example.org/predicate')),
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
        (t) => (t.predicate as IriTerm).value == RdfTerms.type.value,
      );

      expect(
        typeTriple.subject,
        equals(const IriTerm('http://example.org/person/1')),
      );
      expect(typeTriple.predicate, equals(RdfTerms.type));
      expect(
        typeTriple.object,
        equals(const IriTerm('http://example.org/Person')),
      );

      // Find the name triple
      final nameTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).value == 'http://example.org/name',
      );

      expect(
        nameTriple.subject,
        equals(const IriTerm('http://example.org/person/1')),
      );
      expect(
        nameTriple.predicate,
        equals(const IriTerm('http://example.org/name')),
      );
      expect(nameTriple.object, equals(LiteralTerm.string('John Doe')));
    });

    test('handles language tags in dc:description', () {
      final xmlContent = '''
    <?xml version="1.0" encoding="UTF-8"?>
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:dc="http://purl.org/dc/elements/1.1/"
             xml:base="http://example.org/data/">
      
      <!-- Resource with multiple properties -->
      <rdf:Description rdf:about="resource1">
        <dc:description xml:lang="en">An example showing configuration options</dc:description>
      </rdf:Description>
      
    </rdf:RDF>
  ''';
      final parser = RdfXmlParser(xmlContent);
      final triples = parser.parse();
      expect(triples.length, equals(1));
      expect(
        triples[0].subject,
        equals(const IriTerm('http://example.org/data/resource1')),
      );
      expect(
        triples[0].predicate,
        equals(const IriTerm('http://purl.org/dc/elements/1.1/description')),
      );
      expect(triples[0].object, isA<LiteralTerm>());
      expect(
        (triples[0].object as LiteralTerm).value,
        equals('An example showing configuration options'),
      );
      expect((triples[0].object as LiteralTerm).language, equals('en'));
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

      expect(triples, hasLength(4));

      // Find the address triple that links the person to the address
      final addressTriple = triples.firstWhere(
        (t) => (t.predicate as IriTerm).value == 'http://example.org/address',
        orElse: () => throw StateError('No address triple found'),
      );

      expect(
        addressTriple.subject,
        equals(const IriTerm('http://example.org/person/1')),
      );
      final addressNode = addressTriple.object;
      expect(addressNode, isA<BlankNodeTerm>());

      // Find the type triple for the address
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).value == RdfTerms.type.value,
        orElse: () => throw StateError('No type triple found for address'),
      );

      expect(
        typeTriple.object,
        equals(const IriTerm('http://example.org/Address')),
      );

      // Find the street triple
      final streetTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).value == 'http://example.org/street',
        orElse: () => throw StateError('No street triple found for address'),
      );

      expect(streetTriple.object, equals(LiteralTerm.string('123 Main St')));

      // Find the city triple
      final cityTriple = triples.firstWhere(
        (t) =>
            t.subject == addressNode &&
            (t.predicate as IriTerm).value == 'http://example.org/city',
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
            t.subject == const IriTerm('http://example.org/list') &&
            (t.predicate as IriTerm).value == 'http://example.org/items',
      );

      final firstListNode = itemsTriple.object as BlankNodeTerm;

      // Find the first item (item/1)
      final firstItemTriple = triples.firstWhere(
        (t) =>
            t.subject == firstListNode &&
            (t.predicate as IriTerm).value == RdfTerms.first.value,
      );

      expect(
        firstItemTriple.object,
        equals(const IriTerm('http://example.org/item/1')),
      );

      // Find the rest link from first to second node
      final firstRestTriple = triples.firstWhere(
        (t) =>
            t.subject == firstListNode &&
            (t.predicate as IriTerm).value == RdfTerms.rest.value,
      );

      final secondListNode = firstRestTriple.object as BlankNodeTerm;

      // Find the second item (item/2)
      final secondItemTriple = triples.firstWhere(
        (t) =>
            t.subject == secondListNode &&
            (t.predicate as IriTerm).value == RdfTerms.first.value,
      );

      expect(
        secondItemTriple.object,
        equals(const IriTerm('http://example.org/item/2')),
      );

      // Find the rest link from second to third node
      final secondRestTriple = triples.firstWhere(
        (t) =>
            t.subject == secondListNode &&
            (t.predicate as IriTerm).value == RdfTerms.rest.value,
      );

      final thirdListNode = secondRestTriple.object as BlankNodeTerm;

      // Find the third item (item/3)
      final thirdItemTriple = triples.firstWhere(
        (t) =>
            t.subject == thirdListNode &&
            (t.predicate as IriTerm).value == RdfTerms.first.value,
      );

      expect(
        thirdItemTriple.object,
        equals(const IriTerm('http://example.org/item/3')),
      );

      // Find the rest link from third node to nil
      final thirdRestTriple = triples.firstWhere(
        (t) =>
            t.subject == thirdListNode &&
            (t.predicate as IriTerm).value == RdfTerms.rest.value,
      );

      expect(thirdRestTriple.object, equals(RdfTerms.nil));
    });

    test('parses FOAF Person class with nested subClassOf correctly', () {
      final xml = '''
    <rdfs:Class rdf:about="http://xmlns.com/foaf/0.1/Person" rdfs:label="Person" rdfs:comment="A person." vs:term_status="stable">
      <rdf:type rdf:resource="http://www.w3.org/2002/07/owl#Class" />
      <owl:equivalentClass rdf:resource="http://schema.org/Person" />
      <owl:equivalentClass rdf:resource="http://www.w3.org/2000/10/swap/pim/contact#Person" />
  <!--    <rdfs:subClassOf><owl:Class rdf:about="http://xmlns.com/wordnet/1.6/Person"/></rdfs:subClassOf> -->
      <rdfs:subClassOf><owl:Class rdf:about="http://xmlns.com/foaf/0.1/Agent"/></rdfs:subClassOf>
  <!--    <rdfs:subClassOf><owl:Class rdf:about="http://xmlns.com/wordnet/1.6/Agent"/></rdfs:subClassOf> -->
      <rdfs:subClassOf><owl:Class rdf:about="http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing" rdfs:label="Spatial Thing"/></rdfs:subClassOf>
      <!-- aside: 
    are spatial things always spatially located? 
    Person includes imaginary people... discuss... -->
      <rdfs:isDefinedBy rdf:resource="http://xmlns.com/foaf/0.1/"/>

  <!--    <owl:disjointWith rdf:resource="http://xmlns.com/foaf/0.1/Document"/> this was a mistake; tattoo'd people, for example. -->

      <owl:disjointWith rdf:resource="http://xmlns.com/foaf/0.1/Organization"/>
      <owl:disjointWith rdf:resource="http://xmlns.com/foaf/0.1/Project"/>
    </rdfs:Class>
  ''';

      // Hinzufügen der notwendigen Namensräume
      final completeXml = '''
    <rdf:RDF 
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
      xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
      xmlns:owl="http://www.w3.org/2002/07/owl#" 
      xmlns:vs="http://www.w3.org/2003/06/sw-vocab-status/ns#">
      $xml
    </rdf:RDF>
  ''';

      final parser = RdfXmlParser(completeXml);
      final triples = parser.parse();

      // Überprüfe, dass Triples generiert wurden
      expect(triples, isNotEmpty);

      // Definiere wichtige URIs
      final foafPerson = const IriTerm('http://xmlns.com/foaf/0.1/Person');
      final rdfType = const IriTerm(
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
      );
      final owlClass = const IriTerm('http://www.w3.org/2002/07/owl#Class');
      final rdfsSubClassOf = const IriTerm(
        'http://www.w3.org/2000/01/rdf-schema#subClassOf',
      );
      final foafAgent = const IriTerm('http://xmlns.com/foaf/0.1/Agent');
      final spatialThing = const IriTerm(
        'http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing',
      );
      final rdfsLabel = const IriTerm(
        'http://www.w3.org/2000/01/rdf-schema#label',
      );

      // Überprüfe, dass Person eine Klasse ist
      final typeTriple = triples.firstWhere(
        (t) =>
            t.subject == foafPerson &&
            t.predicate == rdfType &&
            t.object == owlClass,
        orElse:
            () =>
                throw StateError(
                  'No rdf:type owl:Class triple found for foaf:Person',
                ),
      );
      expect(typeTriple, isNotNull);

      // Finde alle subClassOf Tripel mit foaf:Person als Subjekt
      final subClassOfTriples =
          triples
              .where(
                (t) => t.subject == foafPerson && t.predicate == rdfsSubClassOf,
              )
              .toList();

      // Es sollten 2 subClassOf-Beziehungen vorhanden sein
      expect(subClassOfTriples, hasLength(2));

      // Überprüfe direkte Beziehungen zu Agent und SpatialThing
      expect(
        subClassOfTriples.any((t) => t.object == foafAgent),
        isTrue,
        reason: 'foaf:Person should be directly related to foaf:Agent',
      );

      expect(
        subClassOfTriples.any((t) => t.object == spatialThing),
        isTrue,
        reason: 'foaf:Person should be directly related to geo:SpatialThing',
      );

      // Überprüfe, dass die referenzierten Klassen auch als owl:Class definiert sind
      expect(
        triples.any(
          (t) =>
              t.subject == foafAgent &&
              t.predicate == rdfType &&
              t.object == owlClass,
        ),
        isTrue,
        reason: 'foaf:Agent should be defined as owl:Class',
      );

      expect(
        triples.any(
          (t) =>
              t.subject == spatialThing &&
              t.predicate == rdfType &&
              t.object == owlClass,
        ),
        isTrue,
        reason: 'geo:SpatialThing should be defined as owl:Class',
      );

      // Überprüfe, dass SpatialThing das richtige Label hat
      final labelTriple = triples.firstWhere(
        (t) => t.subject == spatialThing && t.predicate == rdfsLabel,
        orElse:
            () => throw StateError('No rdfs:label for geo:SpatialThing found'),
      );
      expect(labelTriple.object, isA<LiteralTerm>());
      expect(
        (labelTriple.object as LiteralTerm).value,
        equals('Spatial Thing'),
      );

      // This corresponds to the semantic content in Turtle equivalent:
      // foaf:Person
      //   rdfs:subClassOf foaf:Agent, geo:SpatialThing ;
      //   a owl:Class .
      // foaf:Agent a owl:Class .
      // geo:SpatialThing
      //   a owl:Class ;
      //   rdfs:label "Spatial Thing" .
    });
  });

  test('parses FOAF Person class with nested subClassOf correctly', () {
    final expectedTurtle = """
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

geo:SpatialThing a owl:Class;
    rdfs:label "Spatial Thing" .

foaf:Person a rdfs:Class;
    rdfs:subClassOf geo:SpatialThing .
""";
    final xml = '''
    <rdfs:Class rdf:about="http://xmlns.com/foaf/0.1/Person" >
      <rdfs:subClassOf><owl:Class rdf:about="http://www.w3.org/2003/01/geo/wgs84_pos#SpatialThing" rdfs:label="Spatial Thing"/></rdfs:subClassOf>
    </rdfs:Class>
  ''';

    // Hinzufügen der notwendigen Namensräume
    final completeXml = '''
    <rdf:RDF 
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
      xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" 
      xmlns:owl="http://www.w3.org/2002/07/owl#" 
      xmlns:vs="http://www.w3.org/2003/06/sw-vocab-status/ns#">
      $xml
    </rdf:RDF>
  ''';

    final parser = RdfXmlParser(completeXml);
    final triples = parser.parse();

    final turtleData = turtle.encode(RdfGraph(triples: triples));
    _log.finest(turtleData);
    expect(turtleData, equalsIgnoringWhitespace(expectedTurtle));
  });
}
