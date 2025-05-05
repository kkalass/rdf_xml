import 'package:rdf_core/rdf_core.dart';

/// Helper class for RDF tests
class RdfTestUtils {
  /// Returns triples with the specified subject and predicate
  static List<Triple> triplesWithSubjectPredicate(
    RdfGraph graph,
    RdfSubject subject,
    RdfPredicate predicate,
  ) {
    return graph.triples
        .where((t) => t.subject == subject && t.predicate == predicate)
        .toList();
  }
}
