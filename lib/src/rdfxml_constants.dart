/// Constants used in RDF/XML parsing and serialization
///
/// This file contains the core RDF vocabulary terms needed for
/// the RDF/XML format implementation.
library rdfxml_constants;

import 'package:rdf_core/rdf_core.dart';

/// Core RDF vocabulary predicates, private to the RDF/XML implementation.
class RdfTerms {
  /// The RDF namespace
  static const String rdfNamespace =
      'http://www.w3.org/1999/02/22-rdf-syntax-ns#';

  static const IriTerm langString = const IriTerm('${rdfNamespace}langString');

  /// The XSD namespace
  static const String xsdNamespace = 'http://www.w3.org/2001/XMLSchema#';

  /// The rdf:type predicate
  static const IriTerm type = const IriTerm('${rdfNamespace}type');

  /// The rdf:first predicate (used in RDF lists)
  static const IriTerm first = const IriTerm('${rdfNamespace}first');

  /// The rdf:rest predicate (used in RDF lists)
  static const IriTerm rest = const IriTerm('${rdfNamespace}rest');

  /// The rdf:nil resource (terminator for RDF lists)
  static const IriTerm nil = const IriTerm('${rdfNamespace}nil');

  /// The rdf:XMLLiteral datatype
  static const IriTerm xmlLiteral = const IriTerm('${rdfNamespace}XMLLiteral');

  /// The xsd:string datatype
  static const IriTerm string = const IriTerm('${xsdNamespace}string');

  /// The rdf:Statement resource (for reification)
  static const IriTerm Statement = const IriTerm('${rdfNamespace}Statement');

  /// The rdf:subject predicate (for reification)
  static const IriTerm subject = const IriTerm('${rdfNamespace}subject');

  /// The rdf:predicate predicate (for reification)
  static const IriTerm predicate = const IriTerm('${rdfNamespace}predicate');

  /// The rdf:object predicate (for reification)
  static const IriTerm object = const IriTerm('${rdfNamespace}object');

  static const IriTerm Bag = const IriTerm('${rdfNamespace}Bag');
  static const IriTerm Seq = const IriTerm('${rdfNamespace}Seq');
  static const IriTerm Alt = const IriTerm('${rdfNamespace}Alt');

  /// Private constructor to prevent instantiation
  RdfTerms._();
}
