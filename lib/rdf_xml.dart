/// RDF/XML Format Implementation for rdf_core
///
/// This library provides parsing and serialization support for the RDF/XML format
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
/// - Stream-based processing for large RDF/XML documents
///
/// To use this package, import it and either:
///
/// 1. Create parser/serializer instances directly:
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// // Create a parser directly
/// final parser = RdfXmlFormat().createParser();
/// final rdfGraph = parser.parse(rdfXmlContent);
///
/// // For large documents, use streaming parser
/// final streamingParser = RdfXmlFormat().createStreamingParser();
/// await for (final triple in streamingParser.parseAsStream(rdfXmlContent)) {
///   // Process each triple as it's parsed
///   processTriple(triple);
/// }
///
/// // Create a serializer directly
/// final serializer = RdfXmlFormat().createSerializer();
/// final rdfXml = serializer.write(rdfGraph);
/// ```
///
/// 2. Or register with the format registry for automatic format handling:
///
/// ```dart
/// import 'package:rdf_core/rdf_core.dart';
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// // Register the format
/// final registry = RdfFormatRegistry();
/// registry.registerFormat(const RdfXmlFormat());
///
/// // Use the registry to get the appropriate parser by MIME type
/// final parser = registry.getParser('application/rdf+xml');
/// final serializer = registry.getSerializer('application/rdf+xml');
/// ```
library rdf_xml;

export 'src/interfaces/xml_parsing.dart';
export 'src/rdfxml_format.dart' show RdfXmlFormat;
export 'src/configuration.dart';
export 'src/exceptions.dart';
