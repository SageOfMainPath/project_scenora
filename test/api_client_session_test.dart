import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scenora/core/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production server replaces stale URL and session survives restart',
    () async {
      HttpOverrides.global = null;
      var refreshCount = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/auth/refresh');
        final body =
            jsonDecode(await utf8.decodeStream(request))
                as Map<String, dynamic>;
        refreshCount++;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'accessToken': 'access-$refreshCount',
              'refreshToken': 'refresh-$refreshCount',
              'user': {
                'id': 'usr_test',
                'username': 'session_test',
                'displayName': 'Session Test',
              },
              'receivedRefreshToken': body['refreshToken'],
            }),
          );
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      SharedPreferences.setMockInitialValues({
        'scenora_server_url': 'https://expired-demo.trycloudflare.com',
      });
      FlutterSecureStorage.setMockInitialValues({
        'scenora_access_token': 'old-access',
        'scenora_refresh_token': 'initial-refresh',
      });

      final productionUrl = 'http://127.0.0.1:${server.port}';
      final firstLaunch = ScenoraApiClient(productionBaseUrl: productionUrl);
      expect(await firstLaunch.initialize(), isTrue);
      expect(firstLaunch.baseUrl, productionUrl);
      expect(firstLaunch.currentUser?['username'], 'session_test');
      expect(firstLaunch.refreshToken, 'refresh-1');

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('scenora_server_url'), isFalse);

      final restartedApp = ScenoraApiClient(productionBaseUrl: productionUrl);
      expect(await restartedApp.initialize(), isTrue);
      expect(restartedApp.currentUser?['username'], 'session_test');
      expect(restartedApp.refreshToken, 'refresh-2');
      expect(refreshCount, 2);
    },
  );

  test(
    'review feed accepts PostgreSQL numeric values encoded as strings',
    () async {
      HttpOverrides.global = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/reviews');
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'items': [
                {
                  'id': 'review-1',
                  'userId': 'user-1',
                  'rating': '4',
                  'text': 'Persisted review',
                  'likeCount': '2',
                  'commentCount': '1',
                  'reviewRating': '4.5',
                  'reviewRatingCount': '2',
                  'user': {'username': 'tester', 'displayName': 'Tester'},
                  'movie': {
                    'id': 'movie-1',
                    'title': 'Persisted Movie',
                    'year': '2026',
                    'genre': 'Drama',
                    'tmdbRating': '7.8',
                    'scenoraRating': '4.0',
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final client = ScenoraApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        productionBaseUrl: '',
      );
      final reviews = await client.reviews();

      expect(reviews, hasLength(1));
      expect(reviews.single.movie.score, 7.8);
      expect(reviews.single.reviewRating, 4.5);
      expect(reviews.single.rating, 4);
      expect(reviews.single.likes, 2);
    },
  );
}
