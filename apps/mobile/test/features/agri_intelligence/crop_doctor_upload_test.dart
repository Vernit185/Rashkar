import 'dart:async';
import 'dart:convert';
import 'package:cropnet_mobile/core/network/api_client.dart';
import 'package:cropnet_mobile/core/network/api_exception.dart';
import 'package:cropnet_mobile/features/agri_intelligence/data/agri_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Future<dynamic> upload(AgriIntelligenceRepository repo) =>
      repo.analyzeCropImage(
          bytes: [137, 80, 78, 71],
          fileName: 'leaf.png',
          mimeType: 'image/png');

  test('connection refusal becomes an actionable upload error', () async {
    final repo = AgriIntelligenceRepository(
        httpClient: MockClient(
            (_) async => throw http.ClientException('Failed to fetch')));
    await expectLater(
        upload(repo),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message',
            contains('Cannot reach Crop Doctor'))));
  });

  test('server model-unavailable explanation survives the upload boundary',
      () async {
    final repo = AgriIntelligenceRepository(
        httpClient: MockClient((_) async => http.Response(
            '{"detail":"Crop Doctor model is unavailable"}', 503)));
    await expectLater(
        upload(repo),
        throwsA(isA<ServerException>().having(
            (e) => e.message, 'message', 'Crop Doctor model is unavailable')));
  });

  test('HTML from the wrong server is not treated as a diagnosis', () async {
    final repo = AgriIntelligenceRepository(
        httpClient:
            MockClient((_) async => http.Response('<html>App</html>', 200)));
    await expectLater(upload(repo), throwsA(isA<JsonParseException>()));
  });

  test('valid multipart upload preserves filename, image, auth and prediction',
      () async {
    late http.Request sent;
    final transport = MockClient((request) async {
      sent = request;
      return http.Response(
          jsonEncode({
            'crop': 'Tomato',
            'diagnosis': 'Early blight',
            'confidence_percent': 93.2,
            'is_healthy': false,
            'actionable_advice': ['Check affected leaves.']
          }),
          200);
    });
    final repo = AgriIntelligenceRepository(
        client: ApiClient(bearerToken: 'test-token'), httpClient: transport);
    final result = await upload(repo);
    expect(sent.headers['Authorization'], 'Bearer test-token');
    expect(sent.headers['content-type'],
        startsWith('multipart/form-data; boundary='));
    expect(latin1.decode(sent.bodyBytes), contains('filename="leaf.png"'));
    expect(result.diagnosis, 'Early blight');
    expect(result.confidence, 93.2);
  });

  test('deadline covers the response body as well as response headers',
      () async {
    final body = StreamController<List<int>>();
    final repo = AgriIntelligenceRepository(
      uploadTimeout: const Duration(milliseconds: 20),
      httpClient: MockClient.streaming(
          (_, __) async => http.StreamedResponse(body.stream, 200)),
    );
    await expectLater(upload(repo), throwsA(isA<RequestTimeoutException>()));
    await body.close();
  });
}
