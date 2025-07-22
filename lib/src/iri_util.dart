import 'package:rdf_core/rdf_core.dart';

String relativizeIri(String iri, String baseUri) {
  // FIXME: must not throw exceptions for non-uri iris.
  // Ensure the IRI is absolute before attempting to relativize
  if (!Uri.parse(iri).isAbsolute) {
    return iri; // Return as is if not absolute
  }

  // Use the RFC 3986 compliant relativization logic
  return _relativizeUri(iri, baseUri);
}

/// Relativizes a URI against a base URI using RFC 3986 compliant logic
///
/// This method ensures that relativizing a URI and then resolving it back
/// produces the original URI, maintaining consistency with the parser.
String _relativizeUri(String iri, String baseUri) {
  try {
    final baseUriParsed = Uri.parse(baseUri);
    final iriParsed = Uri.parse(iri);

    // Only relativize if both URIs have scheme and authority
    if (baseUriParsed.scheme.isEmpty ||
        iriParsed.scheme.isEmpty ||
        !baseUriParsed.hasAuthority ||
        !iriParsed.hasAuthority) {
      return iri;
    }

    if (baseUriParsed.scheme != iriParsed.scheme ||
        baseUriParsed.authority != iriParsed.authority) {
      return iri;
    }

    // Special case: if URIs are identical, return empty string
    if (iri == baseUri) {
      return '';
    }

    // Check for fragment-only differences (most optimal case)
    if (baseUriParsed.path == iriParsed.path &&
        baseUriParsed.query == iriParsed.query &&
        iriParsed.hasFragment) {
      // Only the fragment differs, return just the fragment
      final fragmentRef = '#${iriParsed.fragment}';
      final resolvedBack = baseUriParsed.resolveUri(Uri.parse(fragmentRef));
      if (resolvedBack.toString() == iri) {
        return fragmentRef;
      }
    }

    // Try simple path-based relativization
    if (!baseUriParsed.hasQuery && !baseUriParsed.hasFragment) {
      final basePath = baseUriParsed.path;
      final iriPath = iriParsed.path;

      // For simple cases where base ends with / and IRI starts with base path
      if (basePath.endsWith('/') && iriPath.startsWith(basePath)) {
        final relativePath = iriPath.substring(basePath.length);

        // Construct candidate relative URI
        var relativeUri = relativePath;
        if (iriParsed.hasQuery) {
          relativeUri += '?${iriParsed.query}';
        }
        if (iriParsed.hasFragment) {
          relativeUri += '#${iriParsed.fragment}';
        }

        // Verify roundtrip: resolve relative URI against base should give original
        final resolvedBack = baseUriParsed.resolveUri(Uri.parse(relativeUri));
        if (resolvedBack.toString() == iri) {
          return relativeUri;
        }
      }
    }

    // Try filename-only relativization (for cases like http://my.host/foo vs http://my.host/path#)
    if (iriParsed.pathSegments.isNotEmpty) {
      final filename = iriParsed.pathSegments.last;
      if (filename.isNotEmpty) {
        var candidate = filename;
        if (iriParsed.hasQuery) {
          candidate += '?${iriParsed.query}';
        }
        if (iriParsed.hasFragment) {
          candidate += '#${iriParsed.fragment}';
        }

        final resolvedBack = baseUriParsed.resolveUri(Uri.parse(candidate));
        if (resolvedBack.toString() == iri) {
          return candidate;
        }
      }
    }

    // If no safe relativization found, return absolute URI
    return iri;
  } catch (e) {
    // If any parsing fails, return the absolute URI
    return iri;
  }
}

class BaseUriRequiredException extends RdfDecoderException {
  final String relativeUri;

  /// Creates a new base URI required exception
  ///
  /// Parameters:
  /// - [relativeUri] The relative URI that could not be resolved
  /// - [sourceContext] Optional source context where the error occurred
  const BaseUriRequiredException({required this.relativeUri})
    : super(
        'Base URI is required to resolve relative URI: $relativeUri',
        format: 'uri',
      );
}

@override
String resolveIri(String iri, String? baseUri) {
  // FIXME: do not fail for non-Uri IRIs
  // Return absolute URIs immediately
  if (_isAbsoluteUri(iri)) {
    return iri;
  }

  // Handle empty base URI cases
  if (baseUri == null || baseUri.isEmpty) {
    throw BaseUriRequiredException(relativeUri: iri);
  }

  // Handle standard cases using Uri class when possible for robustness
  try {
    // For relative URIs, use the Dart URI resolution
    final base = Uri.parse(baseUri);
    final resolved = base.resolveUri(Uri.parse(iri));
    return resolved.toString();
  } catch (e) {
    // Fall back to manual resolution if URI parsing fails
    return _manualResolveUri(iri, baseUri);
  }
}

/// Determines if a URI is absolute (has a scheme)
bool _isAbsoluteUri(String uri) {
  // Check for URI scheme (e.g., http:, https:, file:)
  // More efficient than regex for this simple case
  final colonPos = uri.indexOf(':');
  if (colonPos <= 0) return false;

  // Check that characters before colon are valid scheme characters
  for (int i = 0; i < colonPos; i++) {
    final char = uri.codeUnitAt(i);
    // Valid scheme chars are a-z, A-Z, 0-9, +, -, .
    final isValidSchemeChar =
        (char >= 97 && char <= 122) || // a-z
        (char >= 65 && char <= 90) || // A-Z
        (char >= 48 && char <= 57) || // 0-9
        char == 43 || // +
        char == 45 || // -
        char == 46; // .

    if (!isValidSchemeChar) return false;
  }

  return true;
}

/// Manual URI resolution logic for cases where Uri.resolveUri fails
String _manualResolveUri(String uri, String baseUri) {
  // Fragment identifier
  if (uri.startsWith('#')) {
    final baseWithoutFragment =
        baseUri.contains('#')
            ? baseUri.substring(0, baseUri.indexOf('#'))
            : baseUri;
    return '$baseWithoutFragment$uri';
  }

  // Absolute path
  if (uri.startsWith('/')) {
    final schemeEnd = baseUri.indexOf('://');
    if (schemeEnd >= 0) {
      final pathStart = baseUri.indexOf('/', schemeEnd + 3);
      if (pathStart >= 0) {
        return '${baseUri.substring(0, pathStart)}$uri';
      }
    }
    // If we can't parse the base URI properly, concat with care
    return baseUri.endsWith('/')
        ? '${baseUri.substring(0, baseUri.length - 1)}$uri'
        : '$baseUri$uri';
  }

  // Relative path
  final lastSlashPos = baseUri.lastIndexOf('/');
  if (lastSlashPos >= 0) {
    return '${baseUri.substring(0, lastSlashPos + 1)}$uri';
  } else {
    return '$baseUri/$uri';
  }
}
