/// Configuration and options for RDF/XML processing
///
/// Provides immutable configuration objects for decoder and encoder options.
/// This module follows the immutable configuration pattern to ensure thread safety
/// and prevent unexpected changes to configuration during processing.
///
/// The configuration options allow fine-tuning of the RDF/XML processing behavior
/// without modifying the core implementation, following the Open/Closed Principle.
/// Predefined factory methods provide commonly used configuration profiles.
///
library rdfxml.configuration;

import 'package:rdf_core/rdf_core.dart';

/// Decoder options for RDF/XML processing
///
/// Immutable configuration for controlling decoder behavior.
final class RdfXmlDecoderOptions extends RdfGraphDecoderOptions {
  /// Whether to validate the RDF/XML structure strictly
  ///
  /// When true, the decoder enforces strict compliance with the RDF/XML specification.
  /// When false, the decoder attempts to handle common deviations from the spec.
  final bool strictMode;

  /// Whether to normalize whitespace in literal values
  ///
  /// When true, the decoder normalizes whitespace in literal values
  /// according to XML whitespace handling rules.
  final bool normalizeWhitespace;

  /// Whether to validate RDF/XML output triples
  ///
  /// When true, the decoder validates the generated triples for
  /// RDF compliance before returning them.
  final bool validateOutput;

  /// Maximum depth for nested RDF/XML structures
  ///
  /// Helps prevent stack overflows from deeply nested XML structures.
  /// A value of 0 means no limit.
  final int maxNestingDepth;

  /// Creates a new immutable decoder options object
  ///
  /// All parameters are optional with sensible defaults.
  const RdfXmlDecoderOptions({
    this.strictMode = false,
    this.normalizeWhitespace = true,
    this.validateOutput = true,
    this.maxNestingDepth = 100,
  });

  static RdfXmlDecoderOptions from(RdfGraphDecoderOptions options) =>
      switch (options) {
        RdfXmlDecoderOptions _ => options,
        _ => RdfXmlDecoderOptions(),
      };

  /// Creates a new options object with strict mode enabled
  ///
  /// Convenience factory for creating options with strict validation.
  factory RdfXmlDecoderOptions.strict() => const RdfXmlDecoderOptions(
    strictMode: true,
    normalizeWhitespace: true,
    validateOutput: true,
  );

  /// Creates a new options object with lenient parsing
  ///
  /// Convenience factory for creating options that try to parse
  /// even non-conformant RDF/XML.
  factory RdfXmlDecoderOptions.lenient() => const RdfXmlDecoderOptions(
    strictMode: false,
    normalizeWhitespace: true,
    validateOutput: false,
  );

  /// Creates a high-performance configuration with minimal validation
  ///
  /// For use when parsing large datasets where performance is critical
  /// and input validity is guaranteed.
  factory RdfXmlDecoderOptions.performance() => const RdfXmlDecoderOptions(
    strictMode: false,
    normalizeWhitespace: false,
    validateOutput: false,
    maxNestingDepth: 0, // Keine Tiefenprüfung für maximale Leistung
  );

  /// Creates a copy of this options object with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlDecoderOptions copyWith({
    bool? strictMode,
    bool? normalizeWhitespace,
    bool? validateOutput,
    int? maxNestingDepth,
  }) {
    return RdfXmlDecoderOptions(
      strictMode: strictMode ?? this.strictMode,
      normalizeWhitespace: normalizeWhitespace ?? this.normalizeWhitespace,
      validateOutput: validateOutput ?? this.validateOutput,
      maxNestingDepth: maxNestingDepth ?? this.maxNestingDepth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RdfXmlDecoderOptions &&
        other.strictMode == strictMode &&
        other.normalizeWhitespace == normalizeWhitespace &&
        other.validateOutput == validateOutput &&
        other.maxNestingDepth == maxNestingDepth;
  }

  @override
  int get hashCode => Object.hash(
    strictMode,
    normalizeWhitespace,
    validateOutput,
    maxNestingDepth,
  );

  @override
  String toString() =>
      'RdfXmlDecoderOptions('
      'strictMode: $strictMode, '
      'normalizeWhitespace: $normalizeWhitespace, '
      'validateOutput: $validateOutput, '
      'maxNestingDepth: $maxNestingDepth)';
}

/// Encoder options for RDF/XML output
///
/// Immutable configuration for controlling encoder behavior.
final class RdfXmlEncoderOptions extends RdfGraphEncoderOptions {
  /// Whether to use pretty-printing for the output XML
  ///
  /// Controls indentation and formatting of the output XML.
  final bool prettyPrint;

  /// Number of spaces to use for indentation when pretty-printing
  ///
  /// Only used when prettyPrint is true.
  final int indentSpaces;

  /// Whether to use typed nodes for rdf:type triples
  ///
  /// When true, the serializer uses the type IRI as element name
  /// instead of using rdf:Description with an rdf:type property.
  final bool useTypedNodes;

  /// Whether to include base URI declarations in the output
  ///
  /// This option only applies when a baseUri is provided during encoding.
  /// When true and a baseUri is provided, the serializer includes the base URI
  /// as an xml:base attribute.
  /// When false, the baseUri is still used for URI relativization but not declared in the output.
  /// Has no effect if no baseUri is provided during encoding.
  final bool includeBaseDeclaration;

  /// Creates a new immutable serializer options object
  ///
  /// All parameters are optional with sensible defaults.
  const RdfXmlEncoderOptions({
    super.customPrefixes = const {},
    super.iriRelativization = const IriRelativizationOptions.local(),
    this.prettyPrint = true,
    this.indentSpaces = 2,
    this.useTypedNodes = true,
    this.includeBaseDeclaration = true,
  });

  static RdfXmlEncoderOptions from(RdfGraphEncoderOptions options) =>
      switch (options) {
        RdfXmlEncoderOptions _ => options,
        _ => RdfXmlEncoderOptions(
          customPrefixes: options.customPrefixes,
          includeBaseDeclaration: true, // Default to true for compatibility
        ),
      };

  /// Creates a new options object optimized for readability
  ///
  /// Convenience factory for creating options that produce
  /// human-readable RDF/XML output.
  factory RdfXmlEncoderOptions.readable() => const RdfXmlEncoderOptions(
    prettyPrint: true,
    indentSpaces: 2,
    useTypedNodes: true,
    includeBaseDeclaration: true,
  );

  /// Creates a new options object optimized for compact output
  ///
  /// Convenience factory for creating options that produce
  /// the most compact RDF/XML output.
  factory RdfXmlEncoderOptions.compact() => const RdfXmlEncoderOptions(
    prettyPrint: false,
    indentSpaces: 0,
    useTypedNodes: true,
    includeBaseDeclaration: false, // Don't include base for minimal output
  );

  /// Creates a new options object for maximum compatibility
  factory RdfXmlEncoderOptions.compatible() => const RdfXmlEncoderOptions(
    prettyPrint: true,
    indentSpaces: 2,
    useTypedNodes: false, // Verwendet nur rdf:Description mit rdf:type
    includeBaseDeclaration: true,
  );

  /// Creates a copy of this options object with the given values
  ///
  /// Returns a new instance with updated values.
  @override
  RdfXmlEncoderOptions copyWith({
    bool? prettyPrint,
    int? indentSpaces,
    bool? useTypedNodes,
    bool? includeBaseDeclaration,
    Map<String, String>? customPrefixes,
    IriRelativizationOptions? iriRelativization,
  }) {
    return RdfXmlEncoderOptions(
      prettyPrint: prettyPrint ?? this.prettyPrint,
      indentSpaces: indentSpaces ?? this.indentSpaces,
      useTypedNodes: useTypedNodes ?? this.useTypedNodes,
      includeBaseDeclaration:
          includeBaseDeclaration ?? this.includeBaseDeclaration,
      customPrefixes: customPrefixes ?? this.customPrefixes,
      iriRelativization: iriRelativization ?? this.iriRelativization,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RdfXmlEncoderOptions &&
        other.prettyPrint == prettyPrint &&
        other.indentSpaces == indentSpaces &&
        other.useTypedNodes == useTypedNodes &&
        other.includeBaseDeclaration == includeBaseDeclaration &&
        other.iriRelativization == iriRelativization;
  }

  @override
  int get hashCode => Object.hash(
    prettyPrint,
    indentSpaces,
    useTypedNodes,
    includeBaseDeclaration,
    iriRelativization,
  );

  @override
  String toString() =>
      'RdfXmlEncoderOptions('
      'prettyPrint: $prettyPrint, '
      'indentSpaces: $indentSpaces, '
      'useTypedNodes: $useTypedNodes, '
      'includeBaseDeclaration: $includeBaseDeclaration, '
      'customPrefixes(not part of equals/hashCode!): $customPrefixes, '
      'iriRelativization: $iriRelativization)';
}
