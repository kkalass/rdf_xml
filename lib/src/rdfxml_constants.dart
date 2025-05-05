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
  static const IriTerm type = IriTerm.prevalidated('${rdfNamespace}type');

  /// The rdf:first predicate (used in RDF lists)
  static const IriTerm first = IriTerm.prevalidated('${rdfNamespace}first');

  /// The rdf:rest predicate (used in RDF lists)
  static const IriTerm rest = IriTerm.prevalidated('${rdfNamespace}rest');

  /// The rdf:nil resource (terminator for RDF lists)
  static const IriTerm nil = IriTerm.prevalidated('${rdfNamespace}nil');

  /// The rdf:XMLLiteral datatype
  static const IriTerm xmlLiteral = IriTerm.prevalidated(
    '${rdfNamespace}XMLLiteral',
  );

  /// The xsd:string datatype
  static const IriTerm string = IriTerm.prevalidated('${xsdNamespace}string');

  /// The rdf:Statement resource (for reification)
  static const IriTerm Statement = IriTerm.prevalidated(
    '${rdfNamespace}Statement',
  );

  /// The rdf:subject predicate (for reification)
  static const IriTerm subject = IriTerm.prevalidated('${rdfNamespace}subject');

  /// The rdf:predicate predicate (for reification)
  static const IriTerm predicate = IriTerm.prevalidated(
    '${rdfNamespace}predicate',
  );

  /// The rdf:object predicate (for reification)
  static const IriTerm object = IriTerm.prevalidated('${rdfNamespace}object');

  static const IriTerm Bag = IriTerm.prevalidated('${rdfNamespace}Bag');
  static const IriTerm Seq = IriTerm.prevalidated('${rdfNamespace}Seq');
  static const IriTerm Alt = IriTerm.prevalidated('${rdfNamespace}Alt');

  /// Private constructor to prevent instantiation
  RdfTerms._();
}
