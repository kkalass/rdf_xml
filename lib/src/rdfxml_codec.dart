/// RDF/XML Codec Implementation
///
/// Defines the codec plugin for RDF/XML encoding and decoding.
///
/// Example usage:
/// ```dart
/// import 'package:rdf_xml/rdf_xml.dart';
///
/// final graph = rdfxml.decode(rdfXmlString);
/// ```
library;

import 'package:rdf_core/rdf_core.dart';

import 'configuration.dart';
import 'implementations/parsing_impl.dart';
import 'implementations/serialization_impl.dart';
import 'interfaces/serialization.dart';
import 'interfaces/xml_parsing.dart';
import 'rdfxml_parser.dart';
import 'rdfxml_serializer.dart';

/// Codec plugin for RDF/XML
///
/// Extends the [RdfGraphCodec] base class for the RDF/XML mimetype.
final class RdfXmlCodec extends RdfGraphCodec {
  /// MIME type for RDF/XML
  static const String mimeType = 'application/rdf+xml';

  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  final RdfNamespaceMappings _namespaceMappings;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Parser options for configuring parser behavior
  final RdfXmlDecoderOptions _decoderOptions;

  /// Serializer options for configuring serializer behavior
  final RdfXmlEncoderOptions _encoderOptions;

  final IriTermFactory _iriTermFactory;

  /// Creates a new RDF/XML format plugin with optional dependencies
  ///
  /// Parameters:
  /// - [xmlDocumentProvider] Optional XML document provider
  /// - [uriResolver] Optional URI resolver
  /// - [namespaceMappings] Optional namespace mappings
  /// - [xmlBuilder] Optional XML builder
  /// - [decoderOptions] Optional decoder options
  /// - [encoderOptions] Optional encoder options
  RdfXmlCodec({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlDecoderOptions? decoderOptions,
    RdfXmlEncoderOptions? encoderOptions,
    RdfNamespaceMappings? namespaceMappings,
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) : _xmlDocumentProvider =
           xmlDocumentProvider ?? const DefaultXmlDocumentProvider(),
       _uriResolver = uriResolver ?? const DefaultUriResolver(),
       _namespaceMappings = namespaceMappings ?? const RdfNamespaceMappings(),
       _xmlBuilder = xmlBuilder ?? DefaultRdfXmlBuilder(),
       _iriTermFactory = iriTermFactory,
       _decoderOptions = decoderOptions ?? const RdfXmlDecoderOptions(),
       _encoderOptions = encoderOptions ?? const RdfXmlEncoderOptions();

  @override
  String get primaryMimeType => mimeType;

  @override
  Set<String> get supportedMimeTypes => {
    mimeType,
    'application/xml',
    'text/xml',
  };

  @override
  RdfGraphDecoder get decoder {
    return RdfXmlDecoder(
      xmlDocumentProvider: _xmlDocumentProvider,
      rdfNamespaceMappings: _namespaceMappings,
      uriResolver: _uriResolver,
      options: _decoderOptions,
      iriTermFactory: _iriTermFactory,
    );
  }

  @override
  RdfGraphEncoder get encoder {
    return RdfXmlEncoder(
      namespaceMappings: _namespaceMappings,
      xmlBuilder: _xmlBuilder,
      options: _encoderOptions,
    );
  }

  @override
  RdfGraphCodec withOptions({
    RdfGraphEncoderOptions? encoder,
    RdfGraphDecoderOptions? decoder,
    IriTermFactory? iriTermFactory,
  }) => RdfXmlCodec(
    xmlDocumentProvider: _xmlDocumentProvider,
    uriResolver: _uriResolver,
    namespaceMappings: _namespaceMappings,
    xmlBuilder: _xmlBuilder,
    decoderOptions: RdfXmlDecoderOptions.from(decoder ?? _decoderOptions),
    encoderOptions: RdfXmlEncoderOptions.from(encoder ?? _encoderOptions),
    iriTermFactory: iriTermFactory ?? _iriTermFactory,
  );

  @override
  bool canParse(String content) {
    // Check if content appears to be RDF/XML
    return content.contains('<rdf:RDF') ||
        (content.contains(
              'xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"',
            ) &&
            content.contains('<rdf:Description'));
  }

  /// Creates a new RDF/XML codec with strict decoder options
  ///
  /// Convenience factory for creating a codec that enforces strict compliance
  /// with the RDF/XML specification.
  factory RdfXmlCodec.strict({
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) => RdfXmlCodec(
    decoderOptions: RdfXmlDecoderOptions.strict(),
    iriTermFactory: iriTermFactory,
  );

  /// Creates a new RDF/XML codec with lenient decoder options
  ///
  /// Convenience factory for creating a codec that tries to parse
  /// even non-conformant RDF/XML.
  factory RdfXmlCodec.lenient({
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) => RdfXmlCodec(
    decoderOptions: RdfXmlDecoderOptions.lenient(),
    iriTermFactory: iriTermFactory,
  );

  /// Creates a new RDF/XML codec optimized for readability
  ///
  /// Convenience factory for creating a codec that produces
  /// human-readable RDF/XML output.
  factory RdfXmlCodec.readable({
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) => RdfXmlCodec(
    encoderOptions: RdfXmlEncoderOptions.readable(),
    iriTermFactory: iriTermFactory,
  );

  /// Creates a new RDF/XML codec optimized for compact output
  ///
  /// Convenience factory for creating a codec that produces
  /// the most compact RDF/XML output.
  factory RdfXmlCodec.compact({
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) => RdfXmlCodec(
    encoderOptions: RdfXmlEncoderOptions.compact(),
    iriTermFactory: iriTermFactory,
  );

  /// Creates a copy of this codec with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlCodec copyWith({
    IXmlDocumentProvider? xmlDocumentProvider,
    IUriResolver? uriResolver,
    RdfNamespaceMappings? namespaceMappings,
    IRdfXmlBuilder? xmlBuilder,
    RdfXmlDecoderOptions? decoderOptions,
    RdfXmlEncoderOptions? encoderOptions,
    IriTermFactory? iriTermFactory,
  }) {
    return RdfXmlCodec(
      xmlDocumentProvider: xmlDocumentProvider ?? _xmlDocumentProvider,
      uriResolver: uriResolver ?? _uriResolver,
      namespaceMappings: namespaceMappings ?? _namespaceMappings,
      xmlBuilder: xmlBuilder ?? _xmlBuilder,
      decoderOptions: decoderOptions ?? _decoderOptions,
      encoderOptions: encoderOptions ?? _encoderOptions,
      iriTermFactory: iriTermFactory ?? _iriTermFactory,
    );
  }
}

/// Adapter class to make RdfXmlParser compatible with the RdfGraphDecoder interface
final class RdfXmlDecoder extends RdfGraphDecoder {
  /// XML document provider for parsing XML
  final IXmlDocumentProvider _xmlDocumentProvider;

  /// URI resolver for handling URI resolution
  final IUriResolver _uriResolver;

  /// Decoder options for configuring behavior
  final RdfXmlDecoderOptions _options;

  final RdfNamespaceMappings _rdfNamespaceMappings;

  final IriTermFactory _iriTermFactory;

  /// Creates a new adapter for RdfXmlParser
  const RdfXmlDecoder({
    required IXmlDocumentProvider xmlDocumentProvider,
    required IUriResolver uriResolver,
    required RdfXmlDecoderOptions options,
    required RdfNamespaceMappings rdfNamespaceMappings,
    IriTermFactory iriTermFactory = IriTerm.validated,
  }) : _xmlDocumentProvider = xmlDocumentProvider,
       _rdfNamespaceMappings = rdfNamespaceMappings,
       _uriResolver = uriResolver,
       _options = options,
       _iriTermFactory = iriTermFactory;

  @override
  RdfXmlDecoder withOptions(
    RdfGraphDecoderOptions options, {
    IriTermFactory? iriTermFactory,
  }) => RdfXmlDecoder(
    xmlDocumentProvider: _xmlDocumentProvider,
    uriResolver: _uriResolver,
    options: RdfXmlDecoderOptions.from(options),
    rdfNamespaceMappings: _rdfNamespaceMappings,
    iriTermFactory: iriTermFactory ?? _iriTermFactory,
  );

  @override
  RdfGraph convert(String input, {String? documentUrl}) {
    final parser = RdfXmlParser(
      input,
      namespaceMappings: _rdfNamespaceMappings,
      baseUri: documentUrl,
      xmlDocumentProvider: _xmlDocumentProvider,
      uriResolver: _uriResolver,
      options: _options,
      iriTermFactory: _iriTermFactory,
    );
    final triples = parser.parse();
    return RdfGraph.fromTriples(triples);
  }
}

/// Adapter class to make RdfXmlSerializer compatible with the RdfGraphEncoder interface
final class RdfXmlEncoder extends RdfGraphEncoder {
  /// Namespace manager for handling namespace declarations
  final RdfNamespaceMappings _namespaceMappings;

  /// XML builder for creating XML documents
  final IRdfXmlBuilder _xmlBuilder;

  /// Serializer options for configuring behavior
  final RdfXmlEncoderOptions _options;

  /// Creates a new adapter for RdfXmlSerializer
  const RdfXmlEncoder({
    required RdfNamespaceMappings namespaceMappings,
    required IRdfXmlBuilder xmlBuilder,
    required RdfXmlEncoderOptions options,
  }) : _namespaceMappings = namespaceMappings,
       _xmlBuilder = xmlBuilder,
       _options = options;

  @override
  RdfGraphEncoder withOptions(RdfGraphEncoderOptions options) => RdfXmlEncoder(
    namespaceMappings: _namespaceMappings,
    xmlBuilder: _xmlBuilder,
    options: RdfXmlEncoderOptions.from(options),
  );

  @override
  String convert(RdfGraph graph, {String? baseUri}) {
    final serializer = RdfXmlSerializer(
      namespaceMappings: _namespaceMappings,
      xmlBuilder: _xmlBuilder,
      options: _options,
    );
    return serializer.write(
      graph,
      baseUri: baseUri,
      customPrefixes: _options.customPrefixes,
    );
  }
}

/// Global convenience variable for working with RDF/XML format
///
/// This variable provides direct access to RDF/XML codec for easy
/// encoding and decoding of RDF/XML data.
///
/// Example:
/// ```dart
/// final graph = rdfxml.decode(rdfxmlString);
/// final rdfxmlString2 = rdfxml.encode(graph);
/// ```
final rdfxml = RdfXmlCodec();
