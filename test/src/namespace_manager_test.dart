import 'package:rdf_core/rdf_core.dart';
import 'package:rdf_xml/src/interfaces/serialization.dart';
import 'package:rdf_xml/src/implementations/serialization_impl.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultNamespaceManager', () {
    late DefaultNamespaceManager namespaceManager;

    setUp(() {
      namespaceManager = const DefaultNamespaceManager();
    });

    test('generates meaningful prefixes from domain-based namespaces', () {
      // Erstellen eines Test-Graphs mit verschiedenen IRIs
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/resource1'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Test'),
        ),
        Triple(
          IriTerm('http://dbpedia.org/resource/Berlin'),
          IriTerm('http://purl.org/dc/terms/title'),
          LiteralTerm.string('Berlin'),
        ),
        Triple(
          IriTerm('http://www.w3.org/2004/02/skos/core#Concept'),
          IriTerm('http://www.w3.org/2000/01/rdf-schema#label'),
          LiteralTerm.string('Concept'),
        ),
      ]);

      // Generiere Namespace-Deklarationen
      final namespaces = namespaceManager.buildNamespaceDeclarations(graph, {});

      // Überprüfe, ob sinnvolle Präfixe generiert wurden
      expect(namespaces.containsKey('ex'), isTrue);
      expect(namespaces.containsValue('http://example.org/'), isTrue);

      // Überprüfe Standardnamespaces
      expect(
        namespaces['rdf'],
        equals('http://www.w3.org/1999/02/22-rdf-syntax-ns#'),
      );
      expect(
        namespaces['rdfs'],
        equals('http://www.w3.org/2000/01/rdf-schema#'),
      );
      expect(namespaces['dcterms'], equals('http://purl.org/dc/terms/'));
    });

    test('respects custom prefixes over auto-generated ones', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/resource1'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Test'),
        ),
      ]);

      // Füge eigene Präfixe hinzu
      final customPrefixes = {'ex': 'http://example.org/'};

      final namespaces = namespaceManager.buildNamespaceDeclarations(
        graph,
        customPrefixes,
      );

      // Überprüfe, ob der benutzerdefinierte Präfix verwendet wurde
      expect(namespaces['ex'], equals('http://example.org/'));

      // Stelle sicher, dass kein "example"-Präfix erzeugt wurde
      expect(namespaces.containsKey('example'), isFalse);
    });

    test('iriToQName converts IRIs to qualified names correctly', () {
      final namespaces = {
        'ex': 'http://example.org/',
        'skos': 'http://www.w3.org/2004/02/skos/core#',
      };

      // Test für einfache URI mit Pfad
      expect(
        namespaceManager.iriToQName('http://example.org/resource', namespaces),
        equals('ex:resource'),
      );

      // Test für URI mit Hash-Fragment
      expect(
        namespaceManager.iriToQName(
          'http://www.w3.org/2004/02/skos/core#Concept',
          namespaces,
        ),
        equals('skos:Concept'),
      );

      // Test für URI, die keinem Namespace entspricht
      expect(
        namespaceManager.iriToQName('http://unknown.org/term', namespaces),
        isNull,
      );

      // Test für ungültigen lokalen Namen
      expect(
        namespaceManager.iriToQName(
          'http://example.org/invalid name',
          namespaces,
        ),
        isNull,
      );
    });

    test('debugging namespace generation', () {
      final graph = RdfGraph.fromTriples([
        Triple(
          IriTerm('http://example.org/resource1'),
          IriTerm('http://example.org/predicate'),
          LiteralTerm.string('Test'),
        ),
      ]);

      // Generiere Namespace-Deklarationen
      final namespaces = namespaceManager.buildNamespaceDeclarations(graph, {});

      // Ausgabe aller generierten Namespaces
      print('Generated namespaces:');
      namespaces.forEach((prefix, uri) {
        print('$prefix: $uri');
      });

      // Keine Assertion, nur zur Diagnose
      expect(true, isTrue);
    });
  });
}
