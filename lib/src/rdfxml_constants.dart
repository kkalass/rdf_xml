/// Constants used in RDF/XML parsing and serialization
///
/// This file contains the core RDF vocabulary terms needed for
/// the RDF/XML format implementation.
library rdfxml_constants;

import 'package:rdf_core/rdf_core.dart';

/// Core RDF vocabulary predicates
class RdfTerms {
  /// The RDF namespace
  static const String rdfNamespace =
      'http://www.w3.org/1999/02/22-rdf-syntax-ns#';

  /// The XSD namespace
  static const String xsdNamespace = 'http://www.w3.org/2001/XMLSchema#';

  /// The rdf:type predicate
  static final IriTerm type = IriTerm.prevalidated('${rdfNamespace}type');

  /// The rdf:first predicate (used in RDF lists)
  static final IriTerm first = IriTerm.prevalidated('${rdfNamespace}first');

  /// The rdf:rest predicate (used in RDF lists)
  static final IriTerm rest = IriTerm.prevalidated('${rdfNamespace}rest');

  /// The rdf:nil resource (terminator for RDF lists)
  static final IriTerm nil = IriTerm.prevalidated('${rdfNamespace}nil');

  /// The rdf:XMLLiteral datatype
  static final IriTerm xmlLiteral = IriTerm.prevalidated(
    '${rdfNamespace}XMLLiteral',
  );

  /// The xsd:string datatype
  static final IriTerm string = IriTerm.prevalidated('${xsdNamespace}string');

  /// Standard namespaces used in RDF
  static final Map<String, String> standardNamespaces = {
    'rdf': rdfNamespace,
    'xsd': xsdNamespace,
    'rdfs': 'http://www.w3.org/2000/01/rdf-schema#',
    'owl': 'http://www.w3.org/2002/07/owl#',
    'dc': 'http://purl.org/dc/elements/1.1/',
    'dcterms': 'http://purl.org/dc/terms/',
    'foaf': 'http://xmlns.com/foaf/0.1/',
    'ex': 'http://example.org/',
  };

  /// Private constructor to prevent instantiation
  RdfTerms._();
}
