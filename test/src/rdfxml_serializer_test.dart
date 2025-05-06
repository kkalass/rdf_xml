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

    test('correctly handles language tags in nested resources', () {
      // Create a publication with multilingual title and abstract,
      // plus nested authors with multilingual names
      final publication = IriTerm('http://example.org/publication/1');
      final author1 = BlankNodeTerm();
      final author2 = IriTerm('http://example.org/person/jane');

      final triples = [
        // Publication metadata with language tags
        Triple(
          publication,
          RdfTerms.type,
          IriTerm('http://example.org/Publication'),
        ),
        Triple(
          publication,
          IriTerm('http://example.org/title'),
          LiteralTerm.withLanguage('Machine Learning Fundamentals', 'en'),
        ),
        Triple(
          publication,
          IriTerm('http://example.org/title'),
          LiteralTerm.withLanguage('Grundlagen des maschinellen Lernens', 'de'),
        ),

        // Link to authors
        Triple(publication, IriTerm('http://example.org/author'), author1),
        Triple(publication, IriTerm('http://example.org/author'), author2),

        // Author 1 (blank node) with multilingual names
        Triple(author1, RdfTerms.type, IriTerm('http://example.org/Person')),
        Triple(
          author1,
          IriTerm('http://example.org/name'),
          LiteralTerm.withLanguage('John Smith', 'en'),
        ),
        Triple(
          author1,
          IriTerm('http://example.org/name'),
          LiteralTerm.withLanguage('Johann Schmidt', 'de'),
        ),

        // Author 2 (IRI) with multilingual names
        Triple(author2, RdfTerms.type, IriTerm('http://example.org/Person')),
        Triple(
          author2,
          IriTerm('http://example.org/name'),
          LiteralTerm.withLanguage('Jane Doe', 'en'),
        ),
        Triple(
          author2,
          IriTerm('http://example.org/name'),
          LiteralTerm.withLanguage('Jana Musterfrau', 'de'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Uncomment to debug the XML structure
      // print('\n--- Generated XML ---\n$xml\n---------------------');

      // Parse the XML to validate
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

      // Check the publication titles
      final publicationElements = doc.findAllElements('$exPrefix:Publication');
      expect(publicationElements, hasLength(1));

      final titleElements = publicationElements.first.findElements(
        '$exPrefix:title',
      );
      expect(titleElements, hasLength(2));

      // Verify both language versions exist using any or where clauses to be more robust
      final englishTitles =
          titleElements
              .where((e) => e.getAttribute('xml:lang') == 'en')
              .toList();
      expect(
        englishTitles.isNotEmpty,
        isTrue,
        reason: 'No English title found',
      );
      expect(
        englishTitles.first.innerText,
        equals('Machine Learning Fundamentals'),
      );

      final germanTitles =
          titleElements
              .where((e) => e.getAttribute('xml:lang') == 'de')
              .toList();
      expect(germanTitles.isNotEmpty, isTrue, reason: 'No German title found');
      expect(
        germanTitles.first.innerText,
        equals('Grundlagen des maschinellen Lernens'),
      );

      // Check author elements
      final authorElements = publicationElements.first.findElements(
        '$exPrefix:author',
      );
      expect(authorElements, hasLength(2));

      // Find all Person elements that represent authors
      final personElements = doc.findAllElements('$exPrefix:Person');

      // Find Person elements with language tags
      bool foundEnglishName = false;
      bool foundGermanName = false;
      bool foundJaneDoe = false;
      bool foundJanaMusterfrau = false;

      // Check all person elements for multilingual names
      for (final person in personElements) {
        final nameElements = person.findElements('$exPrefix:name');

        for (final nameElem in nameElements) {
          final langAttr = nameElem.getAttribute('xml:lang');
          final nameText = nameElem.innerText;

          if (langAttr == 'en') {
            if (nameText == 'John Smith') foundEnglishName = true;
            if (nameText == 'Jane Doe') foundJaneDoe = true;
          } else if (langAttr == 'de') {
            if (nameText == 'Johann Schmidt') foundGermanName = true;
            if (nameText == 'Jana Musterfrau') foundJanaMusterfrau = true;
          }
        }
      }

      // Verify we found all expected multilingual names
      expect(
        foundEnglishName,
        isTrue,
        reason: 'English name "John Smith" not found',
      );
      expect(
        foundGermanName,
        isTrue,
        reason: 'German name "Johann Schmidt" not found',
      );
      expect(foundJaneDoe, isTrue, reason: 'English name "Jane Doe" not found');
      expect(
        foundJanaMusterfrau,
        isTrue,
        reason: 'German name "Jana Musterfrau" not found',
      );
    });

    test('serializes RDF collections', () {
      // Create a list subject
      final listSubject = IriTerm('http://example.org/list');

      // Create blank nodes for the collection structure
      final listNode1 = BlankNodeTerm();
      final listNode2 = BlankNodeTerm();
      final listNode3 = BlankNodeTerm();

      // Create collection item resources
      final item1 = IriTerm('http://example.org/item/1');
      final item2 = IriTerm('http://example.org/item/2');
      final item3 = IriTerm('http://example.org/item/3');

      // Create triples representing the RDF collection structure
      final triples = [
        // Connect list subject to the first node in the collection
        Triple(listSubject, IriTerm('http://example.org/items'), listNode1),

        // First item chain
        Triple(listNode1, RdfTerms.first, item1),
        Triple(listNode1, RdfTerms.rest, listNode2),

        // Second item chain
        Triple(listNode2, RdfTerms.first, item2),
        Triple(listNode2, RdfTerms.rest, listNode3),

        // Third item chain with termination
        Triple(listNode3, RdfTerms.first, item3),
        Triple(listNode3, RdfTerms.rest, RdfTerms.nil),

        // Add some properties to items to verify they're properly serialized
        Triple(
          item1,
          IriTerm('http://example.org/label'),
          LiteralTerm.string('First Item'),
        ),
        Triple(
          item2,
          IriTerm('http://example.org/label'),
          LiteralTerm.string('Second Item'),
        ),
        Triple(
          item3,
          IriTerm('http://example.org/label'),
          LiteralTerm.string('Third Item'),
        ),
      ];

      final graph = RdfGraph(triples: triples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML to validate
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

      // Find the list subject element
      final listElements = doc.findAllElements('rdf:Description');
      final listElement = listElements.firstWhere(
        (e) => e.getAttribute('rdf:about') == 'http://example.org/list',
      );

      // Find the items property element
      final itemsElements = listElement.findElements('$exPrefix:items');
      expect(itemsElements, hasLength(1));

      // Check that the items element has parseType="Collection"
      expect(
        itemsElements.first.getAttribute('rdf:parseType'),
        equals('Collection'),
      );

      // Verify that we have the correct number of child elements in the collection
      final collectionItems = itemsElements.first.childElements;
      expect(collectionItems, hasLength(3));

      // Verify that collection items are in the correct order with correct URIs
      final collectionItemUris =
          collectionItems.map((e) => e.getAttribute('rdf:about')).toList();

      expect(
        collectionItemUris,
        equals([
          'http://example.org/item/1',
          'http://example.org/item/2',
          'http://example.org/item/3',
        ]),
      );

      // Verify round-trip integrity by parsing back to RDF
      final parser = RdfXmlParser(xml);
      final parsedTriples = parser.parse();

      // Find the triples connecting the list subject to the first collection node
      final startTriples =
          parsedTriples
              .where(
                (t) =>
                    t.subject.toString() == listSubject.toString() &&
                    (t.predicate as IriTerm).iri == 'http://example.org/items',
              )
              .toList();

      expect(startTriples, hasLength(1));

      // Get the first collection node
      final firstNode = startTriples.first.object;
      expect(firstNode, isA<BlankNodeTerm>());

      // Follow the chain to verify the collection structure
      // Start with first node and follow the chain
      var currentNode = firstNode;
      final collectedItems = <RdfTerm>[];

      // Traverse the list until we hit rdf:nil
      while (currentNode != RdfTerms.nil) {
        // Find the rdf:first triple for this node
        final firstTriples =
            parsedTriples
                .where(
                  (t) =>
                      t.subject.toString() == currentNode.toString() &&
                      (t.predicate as IriTerm).iri == RdfTerms.first.iri,
                )
                .toList();

        expect(firstTriples, hasLength(1));
        collectedItems.add(firstTriples.first.object);

        // Find the rdf:rest triple for this node
        final restTriples =
            parsedTriples
                .where(
                  (t) =>
                      t.subject.toString() == currentNode.toString() &&
                      (t.predicate as IriTerm).iri == RdfTerms.rest.iri,
                )
                .toList();

        expect(restTriples, hasLength(1));
        currentNode = restTriples.first.object;
      }

      // Verify we have 3 items
      expect(collectedItems, hasLength(3));

      // Verify the items are in the correct order with correct URIs
      expect(
        collectedItems.map((e) => (e as IriTerm).iri).toList(),
        equals([
          'http://example.org/item/1',
          'http://example.org/item/2',
          'http://example.org/item/3',
        ]),
      );
    });

    test('serializes string literals in RDF collections', () {
      // Create a list subject
      final listSubject = IriTerm('http://example.org/subj1');

      // Create blank nodes for the collection structure
      final listNode1 = BlankNodeTerm();
      final listNode2 = BlankNodeTerm();

      // Create triples representing the RDF collection with string literals
      // This matches the example in the request: ex:subj1 ex:prop1 ("item1" "item2")
      final triples = [
        // Connect list subject to the first node in the collection
        Triple(listSubject, IriTerm('http://example.org/prop1'), listNode1),

        // First item (string literal)
        Triple(listNode1, RdfTerms.first, LiteralTerm.string('item1')),
        Triple(listNode1, RdfTerms.rest, listNode2),

        // Second item (string literal) with termination
        Triple(listNode2, RdfTerms.first, LiteralTerm.string('item2')),
        Triple(listNode2, RdfTerms.rest, RdfTerms.nil),
      ];

      final graph = RdfGraph(triples: triples);

      final serializer = RdfXmlSerializer();
      final xml = serializer.write(graph);

      // Parse the XML to validate
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

      // Find the list subject element
      final listElements = doc.findAllElements('rdf:Description');
      final listElement = listElements.firstWhere(
        (e) => e.getAttribute('rdf:about') == 'http://example.org/subj1',
      );

      // Find the prop1 property element
      final prop1Elements = listElement.findElements('$exPrefix:prop1');
      expect(prop1Elements, hasLength(1));

      // Check that the prop1 element has parseType="Collection"
      expect(
        prop1Elements.first.getAttribute('rdf:parseType'),
        equals('Collection'),
      );

      // Verify that we have the correct number of child elements in the collection
      final collectionItems = prop1Elements.first.childElements;
      expect(collectionItems, hasLength(2));

      // For string literals, we should have rdf:Description elements with text content
      final descriptions = prop1Elements.first.findAllElements(
        'rdf:Description',
      );
      expect(descriptions, hasLength(2));

      // Check the string values of the collection items
      final values = descriptions.map((e) => e.innerText).toList();

      expect(values, equals(['item1', 'item2']));

      // Verify round-trip integrity by parsing back to RDF
      final parser = RdfXmlParser(xml);
      final parsedTriples = parser.parse();

      expect(triples, equals(parsedTriples));
      // Find the triples connecting the list subject to the first collection node
      final startTriples =
          parsedTriples
              .where(
                (t) =>
                    t.subject.toString() == listSubject.toString() &&
                    (t.predicate as IriTerm).iri == 'http://example.org/prop1',
              )
              .toList();

      expect(startTriples, hasLength(1));

      // Get the first collection node
      final firstNode = startTriples.first.object;
      expect(firstNode, isA<BlankNodeTerm>());

      // Follow the chain to verify the collection structure with string literals
      var currentNode = firstNode;
      final collectedItems = <RdfTerm>[];

      // Traverse the list until we hit rdf:nil
      while (currentNode != RdfTerms.nil) {
        // Find the rdf:first triple for this node
        final firstTriples =
            parsedTriples
                .where(
                  (t) =>
                      t.subject.toString() == currentNode.toString() &&
                      (t.predicate as IriTerm).iri == RdfTerms.first.iri,
                )
                .toList();

        expect(firstTriples, hasLength(1));
        collectedItems.add(firstTriples.first.object);

        // Find the rdf:rest triple for this node
        final restTriples =
            parsedTriples
                .where(
                  (t) =>
                      t.subject.toString() == currentNode.toString() &&
                      (t.predicate as IriTerm).iri == RdfTerms.rest.iri,
                )
                .toList();

        expect(restTriples, hasLength(1));
        currentNode = restTriples.first.object;
      }

      // Verify we have 2 items
      expect(collectedItems, hasLength(2));

      // Verify the items are string literals with correct values
      expect(collectedItems[0], isA<LiteralTerm>());
      expect(collectedItems[1], isA<LiteralTerm>());
      expect((collectedItems[0] as LiteralTerm).value, equals('item1'));
      expect((collectedItems[1] as LiteralTerm).value, equals('item2'));
    });
  });
}
