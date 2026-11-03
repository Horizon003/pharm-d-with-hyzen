import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/errors/app_error.dart';
import '../domain/drive.dart';

class DocumentRequest {
  const DocumentRequest(
    this.uri, {
    this.headers = const {},
    this.mimeType,
    this.name,
    this.size,
    this.version,
    this.thumbnailUrl,
    this.publicFallback = false,
  });
  final Uri uri;
  final Map<String, String> headers;
  final String? mimeType, name, version, thumbnailUrl;
  final int? size;
  final bool publicFallback;
}

/// OAuth access tokens stay in memory/the Google platform account service.
/// Public API keys identify the app, never grant private-file access.
class DriveGateway {
  DriveGateway({
    http.Client? client,
    this.apiKey = const String.fromEnvironment('HYZEN_DRIVE_API_KEY'),
  }) : _client = client ?? http.Client();
  static final instance = DriveGateway();
  final http.Client _client;
  final String apiKey;
  GoogleSignIn? _google;
  GoogleSignIn get google => _google ??= GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/drive.readonly'],
    clientId: const String.fromEnvironment('HYZEN_GOOGLE_WEB_CLIENT_ID').isEmpty
        ? null
        : const String.fromEnvironment('HYZEN_GOOGLE_WEB_CLIENT_ID'),
  );
  Map<String, String> _authorization = {};
  DateTime? _authorizedAt;
  bool _apiUnavailable = false;
  final _requests = <String, Future<DocumentRequest>>{};

  Future<void> connect() async {
    try {
      final account = await google.signIn();
      if (account == null) {
        throw FriendlyException('Google connection cancelled.');
      }
      _authorization = await account.authHeaders;
      _authorizedAt = DateTime.now();
      _apiUnavailable = false;
      _requests.clear();
    } on FriendlyException {
      rethrow;
    } catch (_) {
      throw FriendlyException(
        'Google Drive connection is not configured yet. Contact support.',
      );
    }
  }

  Future<void> disconnect() async {
    _authorization = {};
    _authorizedAt = null;
    _apiUnavailable = false;
    _requests.clear();
    if (_google != null) await google.signOut();
  }

  static Uri endpoint(String source, {String? apiKey, bool metadata = false}) {
    final id = DriveLinks.fileId(source);
    if (id.isEmpty) return Uri.parse(source);
    final kind = DriveLinks.kindOf(source);
    final export =
        !metadata &&
        {DocKind.document, DocKind.sheet, DocKind.slides}.contains(kind);
    return Uri.https(
      'www.googleapis.com',
      '/drive/v3/files/$id${export ? '/export' : ''}',
      {
        if (metadata)
          'fields':
              'id,name,mimeType,size,version,modifiedTime,thumbnailLink,capabilities(canDownload)',
        if (!metadata && !export) 'alt': 'media',
        if (export) 'mimeType': 'application/pdf',
        if (apiKey != null && apiKey.isNotEmpty) 'key': apiKey,
      },
    );
  }

  Future<DocumentRequest> resolve(String source, {bool refresh = false}) async {
    if (DriveLinks.fileId(source).isEmpty) {
      return DocumentRequest(Uri.parse(source));
    }
    if (refresh) {
      _requests.remove(source);
      _apiUnavailable = false;
    }
    // Never retain stale bearer headers beyond the access-token refresh window.
    if (_authorizedAt != null &&
        DateTime.now().difference(_authorizedAt!).inMinutes >= 45) {
      _requests.clear();
      try {
        final account = await google.signInSilently(reAuthenticate: true);
        _authorization = account == null ? {} : await account.authHeaders;
        _authorizedAt = DateTime.now();
      } catch (_) {
        _authorization = {};
      }
    }
    final task = _requests.putIfAbsent(source, () => _resolve(source));
    try {
      return await task;
    } finally {
      _requests.remove(source);
    }
  }

  Future<DocumentRequest> _resolve(String source) async {
    final id = DriveLinks.fileId(source);
    if ((_authorization.isEmpty && apiKey.isEmpty) || _apiUnavailable) {
      return publicRequest(source);
    }
    final key = Uri.tryParse(source)?.queryParameters['resourcekey'];
    final headers = <String, String>{
      ..._authorization,
      if (key != null) 'X-Goog-Drive-Resource-Keys': '$id/$key',
    };
    final preferences = await SharedPreferences.getInstance();
    final cacheKey =
        'drive_metadata_v1_${_google?.currentUser?.id ?? 'public'}_$id';
    Map<String, dynamic>? metadata;
    final raw = preferences.getString(cacheKey);
    if (raw != null) {
      try {
        final cached = jsonDecode(raw) as Map<String, dynamic>;
        final fetched = DateTime.parse(cached['cachedAt'] as String);
        if (DateTime.now().difference(fetched).inMinutes < 5) {
          metadata = (cached['metadata'] as Map).cast<String, dynamic>();
        }
      } catch (_) {
        /* Ignore corrupt cache. */
      }
    }
    if (metadata == null) {
      final response = await _client
          .get(
            endpoint(source, apiKey: apiKey, metadata: true),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        final error = errorFor(response.statusCode, response.body);
        if (error.code == 'drive-config') {
          _apiUnavailable = true;
          return publicRequest(source);
        }
        throw error;
      }
      metadata = (jsonDecode(response.body) as Map).cast<String, dynamic>();
      if ((metadata['capabilities'] as Map?)?['canDownload'] == false) {
        throw FriendlyException('The file owner has disabled downloading.');
      }
      await preferences.setString(
        cacheKey,
        jsonEncode({
          'cachedAt': DateTime.now().toIso8601String(),
          'metadata': metadata,
        }),
      );
    }
    final mime = '${metadata['mimeType'] ?? ''}';
    // Workspace file URLs can also arrive as /file/d/...; use actual metadata.
    final isWorkspace = mime.startsWith('application/vnd.google-apps.');
    final media = isWorkspace
        ? Uri.https('www.googleapis.com', '/drive/v3/files/$id/export', {
            'mimeType': 'application/pdf',
            if (apiKey.isNotEmpty) 'key': apiKey,
          })
        : Uri.https('www.googleapis.com', '/drive/v3/files/$id', {
            'alt': 'media',
            if (apiKey.isNotEmpty) 'key': apiKey,
          });
    return DocumentRequest(
      media,
      headers: headers,
      mimeType: isWorkspace ? 'application/pdf' : mime,
      name: metadata['name'] as String?,
      size: int.tryParse('${metadata['size']}'),
      version: '${metadata['version'] ?? metadata['modifiedTime'] ?? ''}',
      thumbnailUrl: metadata['thumbnailLink'] as String?,
    );
  }

  /// Existing public sharing still works when the app's Cloud setup is absent.
  /// Never carry OAuth headers to these browser/download endpoints. Google still
  /// enforces the file owner's sharing and download settings.
  static DocumentRequest publicRequest(String source) => DocumentRequest(
    Uri.parse(DriveLinks.downloadUrl(source)),
    publicFallback: true,
  );

  static FriendlyException errorFor(int status, [String body = '']) {
    if (body.contains('accessNotConfigured') ||
        body.contains('SERVICE_DISABLED') ||
        body.contains('API_KEY_SERVICE_BLOCKED') ||
        body.contains('API_KEY_INVALID') ||
        body.contains('API key not valid') ||
        body.contains('are blocked')) {
      return FriendlyException(
        'Google Drive is not enabled for this app yet. Contact support.',
        code: 'drive-config',
      );
    }
    if (status == 401 || status == 403) {
      return FriendlyException(
        'Connect a Google account that can access this file.',
        code: 'drive-connect',
      );
    }
    if (status == 404) {
      return FriendlyException(
        'This file is unavailable or you do not have access.',
      );
    }
    if (status == 429) {
      return FriendlyException('Google Drive is busy. Try again shortly.');
    }
    return FriendlyException('Could not open this file. Please retry.');
  }
}
