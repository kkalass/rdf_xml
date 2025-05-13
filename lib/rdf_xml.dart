/// RDF/XML Codec Implementation for rdf_core
///
/// This library provides decoding and encoding support for the RDF/XML format
/// as defined by the W3C Recommendation. RDF/XML is the original standard format
/// for representing RDF data as XML, allowing semantic web data to be exchanged
/// in an XML-compatible syntax.
///
/// The implementation handles key RDF/XML features including:
/// - Resource descriptions with rdf:about, rdf:ID, and rdf:resource attributes
/// - Literal properties with language tags and datatypes
/// - Container elements (rdf:Bag, rdf:Seq, rdf:Alt)
/// - Collection elements (rdf:List)
/// - Blank nodes and reification
///
/// To use this package, import it and either:
///
/// 1. Use the pre-defined global codec (similar to dart:convert's json):
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// // Use the global rdfxml codec
/// final rdfGraph = rdfxml.decode(rdfXmlContent);
///
/// final rdfXml = rdfxml.encode(rdfGraph);
/// ```
///
/// 2. Or register with the format registry for automatic format handling:
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// // Use RdfCore with standard codecs plus RdfXmlCodec
/// final rdfCore = RdfCore.withStandardCodecs(additionalCodecs: [RdfXmlCodec()]);
///
/// // Decode RDF/XML content
/// final rdfGraph = rdfCore.decode(rdfXmlContent);
///
/// // Encode a graph as RDF/XML
/// final rdfXml = rdfCore.encode(rdfGraph, contentType: "application/rdf+xml");
/// ```
library rdf_xml;

export 'src/interfaces/xml_parsing.dart';
export 'src/interfaces/serialization.dart';
export 'src/rdfxml_codec.dart' show RdfXmlCodec, rdfxml;
export 'src/configuration.dart';
export 'src/exceptions.dart';
