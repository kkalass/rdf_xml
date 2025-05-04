/// RDF/XML Format Implementation for rdf_core
///
/// This library provides parsing and serialization support for the RDF/XML format
/// as defined by the W3C Recommendation.
///
/// To use this package, import it and register the format with the format registry:
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// // Create a parser directly
/// final parser = RdfXmlFormat().createParser();
/// final rdfGraph = parser.parse(rdfXmlContent);
///
/// // Create a serializer directly
/// final serializer = RdfXmlFormat().createSerializer();
/// final rdfXml = serializer.write(rdfGraph);
/// ```
library rdf_xml;

export 'src/rdfxml_constants.dart';
export 'src/rdfxml_format.dart';
export 'src/rdfxml_parser.dart';
export 'src/rdfxml_serializer.dart';
