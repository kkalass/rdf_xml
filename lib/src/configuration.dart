/// Configuration and options for RDF/XML processing
///
/// Provides immutable configuration objects for parser and serializer options.
library rdfxml.configuration;

/// Parser options for RDF/XML processing
///
/// Immutable configuration for controlling parser behavior.
final class RdfXmlParserOptions {
  /// Whether to validate the RDF/XML structure strictly
  ///
  /// When true, the parser enforces strict compliance with the RDF/XML specification.
  /// When false, the parser attempts to handle common deviations from the spec.
  final bool strictMode;

  /// Whether to normalize whitespace in literal values
  ///
  /// When true, the parser normalizes whitespace in literal values
  /// according to XML whitespace handling rules.
  final bool normalizeWhitespace;

  /// Whether to validate RDF/XML output triples
  ///
  /// When true, the parser validates the generated triples for
  /// RDF compliance before returning them.
  final bool validateOutput;

  /// Maximum depth for nested RDF/XML structures
  ///
  /// Helps prevent stack overflows from deeply nested XML structures.
  /// A value of 0 means no limit.
  final int maxNestingDepth;

  /// Creates a new immutable parser options object
  ///
  /// All parameters are optional with sensible defaults.
  const RdfXmlParserOptions({
    this.strictMode = false,
    this.normalizeWhitespace = true,
    this.validateOutput = true,
    this.maxNestingDepth = 100,
  });

  /// Creates a new options object with strict mode enabled
  ///
  /// Convenience factory for creating options with strict validation.
  factory RdfXmlParserOptions.strict() => const RdfXmlParserOptions(
    strictMode: true,
    normalizeWhitespace: true,
    validateOutput: true,
  );

  /// Creates a new options object with lenient parsing
  ///
  /// Convenience factory for creating options that try to parse
  /// even non-conformant RDF/XML.
  factory RdfXmlParserOptions.lenient() => const RdfXmlParserOptions(
    strictMode: false,
    normalizeWhitespace: true,
    validateOutput: false,
  );

  /// Creates a copy of this options object with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlParserOptions copyWith({
    bool? strictMode,
    bool? normalizeWhitespace,
    bool? validateOutput,
    int? maxNestingDepth,
  }) {
    return RdfXmlParserOptions(
      strictMode: strictMode ?? this.strictMode,
      normalizeWhitespace: normalizeWhitespace ?? this.normalizeWhitespace,
      validateOutput: validateOutput ?? this.validateOutput,
      maxNestingDepth: maxNestingDepth ?? this.maxNestingDepth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RdfXmlParserOptions &&
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
}

/// Serializer options for RDF/XML output
///
/// Immutable configuration for controlling serializer behavior.
final class RdfXmlSerializerOptions {
  /// Whether to use pretty-printing for the output XML
  ///
  /// Controls indentation and formatting of the output XML.
  final bool prettyPrint;

  /// Number of spaces to use for indentation when pretty-printing
  ///
  /// Only used when prettyPrint is true.
  final int indentSpaces;

  /// Whether to use XML namespaces to create compact output
  ///
  /// When true, the serializer uses namespace prefixes to create more compact output.
  /// When false, it uses full URIs for all elements and attributes.
  final bool useNamespaces;

  /// Whether to use typed nodes for rdf:type triples
  ///
  /// When true, the serializer uses the type IRI as element name
  /// instead of using rdf:Description with an rdf:type property.
  final bool useTypedNodes;

  /// Creates a new immutable serializer options object
  ///
  /// All parameters are optional with sensible defaults.
  const RdfXmlSerializerOptions({
    this.prettyPrint = true,
    this.indentSpaces = 2,
    this.useNamespaces = true,
    this.useTypedNodes = true,
  });

  /// Creates a new options object optimized for readability
  ///
  /// Convenience factory for creating options that produce
  /// human-readable RDF/XML output.
  factory RdfXmlSerializerOptions.readable() => const RdfXmlSerializerOptions(
    prettyPrint: true,
    indentSpaces: 2,
    useNamespaces: true,
    useTypedNodes: true,
  );

  /// Creates a new options object optimized for compact output
  ///
  /// Convenience factory for creating options that produce
  /// the most compact RDF/XML output.
  factory RdfXmlSerializerOptions.compact() => const RdfXmlSerializerOptions(
    prettyPrint: false,
    indentSpaces: 0,
    useNamespaces: true,
    useTypedNodes: true,
  );

  /// Creates a copy of this options object with the given values
  ///
  /// Returns a new instance with updated values.
  RdfXmlSerializerOptions copyWith({
    bool? prettyPrint,
    int? indentSpaces,
    bool? useNamespaces,
    bool? useTypedNodes,
  }) {
    return RdfXmlSerializerOptions(
      prettyPrint: prettyPrint ?? this.prettyPrint,
      indentSpaces: indentSpaces ?? this.indentSpaces,
      useNamespaces: useNamespaces ?? this.useNamespaces,
      useTypedNodes: useTypedNodes ?? this.useTypedNodes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RdfXmlSerializerOptions &&
        other.prettyPrint == prettyPrint &&
        other.indentSpaces == indentSpaces &&
        other.useNamespaces == useNamespaces &&
        other.useTypedNodes == useTypedNodes;
  }

  @override
  int get hashCode =>
      Object.hash(prettyPrint, indentSpaces, useNamespaces, useTypedNodes);
}
