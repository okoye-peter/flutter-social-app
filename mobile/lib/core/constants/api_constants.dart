import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => dotenv.get('API_BASE_URL');

  /// The server's public base URL (no trailing slash, no `/api` suffix) —
  /// for links outside the JSON API, e.g. a shared post's public preview
  /// page. Computed once and memoized — `API_BASE_URL` never changes for
  /// the life of the process.
  static final String appUrl = _computeAppUrl();

  static String _computeAppUrl() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL is not a valid absolute URL: $baseUrl');
    }
    final segments = [...uri.pathSegments]..removeWhere((s) => s.isEmpty);
    if (segments.isNotEmpty && segments.last == 'api') segments.removeLast();
    return uri
        .replace(pathSegments: segments, query: '', fragment: '')
        .toString();
  }
}
