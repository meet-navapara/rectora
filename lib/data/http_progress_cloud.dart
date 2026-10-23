import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rectora/domain/account/cloud_types.dart';

class _Reply {
  const _Reply(this.status, this.body);

  final int status;
  final String body;
}

class HttpProgressCloud implements ProgressCloud {
  HttpProgressCloud(this.baseUrl);

  final String baseUrl;

  @override
  bool get configured => baseUrl.startsWith('https://');

  @override
  Future<CloudFetch> download(String idToken) async {
    final reply = await _request(method: 'GET', idToken: idToken);
    if (reply == null) return const CloudUnavailable(offline: true);
    if (reply.status < 0) return const CloudUnavailable(offline: false);
    if (reply.status == 404) return const CloudEmpty();
    final record = _record(reply.body);
    if (reply.status == 200 && record != null) return CloudFound(record);
    return const CloudUnavailable(offline: false);
  }

  @override
  Future<CloudWrite> upload({
    required String idToken,
    required String payload,
    required int baseRevision,
  }) async {
    final reply = await _request(
      method: 'PUT',
      idToken: idToken,
      body: jsonEncode({'baseRevision': baseRevision, 'payload': payload}),
    );
    if (reply == null) return const CloudWrite(ok: false, offline: true);
    if (reply.status < 0) return const CloudWrite(ok: false);
    final record = _record(reply.body);
    if ((reply.status == 200 || reply.status == 201) && record != null) {
      return CloudWrite(ok: true, record: record);
    }
    if (reply.status == 409 && record != null) {
      return CloudWrite(ok: false, conflict: true, record: record);
    }
    return const CloudWrite(ok: false);
  }

  @override
  Future<bool> deleteAccount(String idToken) async {
    final reply = await _request(
      method: 'DELETE',
      idToken: idToken,
      path: '/v1/account',
    );
    if (reply == null) return false;
    return reply.status == 200 || reply.status == 204;
  }

  Future<_Reply?> _request({
    required String method,
    required String idToken,
    String path = '/v1/progress',
    String? body,
  }) async {
    if (!configured || idToken.isEmpty) return const _Reply(-1, '');
    final client = HttpClient();
    try {
      final request = await client
          .openUrl(method, Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final raw = await response.transform(utf8.decoder).join();
      return _Reply(response.statusCode, raw);
    } on SocketException {
      return null;
    } on TimeoutException {
      return null;
    } on HttpException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  CloudRecord? _record(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final revision = decoded['revision'];
      final payload = decoded['payload'];
      if (revision is! int || payload is! String) return null;
      return CloudRecord(revision: revision, payload: payload);
    } catch (_) {
      return null;
    }
  }
}
