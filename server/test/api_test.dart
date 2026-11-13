import 'dart:convert';
import 'dart:io';

import 'package:scenora_backend/api.dart';
import 'package:scenora_backend/security.dart';
import 'package:scenora_backend/store.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

late Uri baseUrl;

void main() {
  late Directory temporaryDirectory;
  late HttpServer server;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'scenora_api_test_',
    );
    final store = JsonStore('${temporaryDirectory.path}/db.json');
    final api = ScenoraApi(
      store: store,
      security: SecurityService(pepper: 'automated-test-pepper'),
    );
    server = await shelf_io.serve(api.handler, InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDownAll(() async {
    await server.close(force: true);
    await temporaryDirectory.delete(recursive: true);
  });

  test('health endpoint is available', () async {
    final response = await request('GET', '/health');
    expect(response.status, 200);
    expect(response.body['status'], 'ok');
  });

  test(
    'auth, profiles, movies, reviews, likes, comments, and follows',
    () async {
      final alice = await request(
        'POST',
        '/auth/register',
        body: {
          'username': 'alice_reviews',
          'email': 'alice@example.com',
          'password': 'password123',
          'displayName': 'Alice Reviewer',
        },
      );
      expect(alice.status, 201);
      var aliceToken = alice.body['accessToken'] as String;
      final aliceRefresh = alice.body['refreshToken'] as String;
      final aliceId =
          (alice.body['user'] as Map<String, dynamic>)['id'] as String;

      final bob = await request(
        'POST',
        '/auth/register',
        body: {
          'username': 'bob_movies',
          'email': 'bob@example.com',
          'password': 'password123',
          'displayName': 'Bob Movies',
        },
      );
      expect(bob.status, 201);
      final bobToken = bob.body['accessToken'] as String;
      final bobId = (bob.body['user'] as Map<String, dynamic>)['id'] as String;

      final login = await request(
        'POST',
        '/auth/login',
        body: {'email': 'alice@example.com', 'password': 'password123'},
      );
      expect(login.status, 200);
      expect(login.body['accessToken'], isNotEmpty);

      final refreshed = await request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': aliceRefresh},
      );
      expect(refreshed.status, 200);
      aliceToken = refreshed.body['accessToken'] as String;
      expect(
        (refreshed.body['user'] as Map<String, dynamic>)['username'],
        'alice_reviews',
      );

      final profile = await request(
        'PATCH',
        '/users/me',
        token: aliceToken,
        body: {
          'bio': 'Cinema is my favourite language.',
          'location': 'Dhaka',
          'avatarUrl': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB',
        },
      );
      expect(profile.status, 200);
      expect(
        (profile.body['user'] as Map<String, dynamic>)['location'],
        'Dhaka',
      );
      expect(
        (profile.body['user'] as Map<String, dynamic>)['avatarUrl'],
        startsWith('data:image/png;base64,'),
      );

      final movies = await request('GET', '/movies/search?q=Dune');
      expect(movies.status, 200);
      expect(movies.body['source'], 'demo-cache');
      expect(movies.body['items'], isNotEmpty);

      final savedMovie = await request(
        'POST',
        '/watchlist/693134',
        token: aliceToken,
      );
      expect(savedMovie.status, 200);
      expect(savedMovie.body['saved'], true);

      final watchlist = await request('GET', '/watchlist', token: aliceToken);
      expect(watchlist.status, 200);
      expect((watchlist.body['items'] as List<dynamic>).length, 1);

      final message = await request(
        'POST',
        '/messages',
        token: aliceToken,
        body: {'text': 'Hello from the backend shoutbox!'},
      );
      expect(message.status, 201);

      final messages = await request('GET', '/messages');
      expect(messages.status, 200);
      expect((messages.body['items'] as List<dynamic>).length, 1);

      final review = await request(
        'POST',
        '/reviews',
        token: aliceToken,
        body: {
          'movieId': '693134',
          'rating': 5,
          'text': 'A spectacular cinematic experience.',
          'containsSpoiler': false,
        },
      );
      expect(review.status, 201);
      final reviewId =
          (review.body['review'] as Map<String, dynamic>)['id'] as String;
      final ownReviews = await request(
        'GET',
        '/reviews?userId=$aliceId&limit=100',
        token: aliceToken,
      );
      expect(ownReviews.status, 200);
      expect((ownReviews.body['items'] as List<dynamic>).length, 1);
      expect(
        ((ownReviews.body['items'] as List<dynamic>).first
            as Map<String, dynamic>)['userId'],
        aliceId,
      );

      final unauthorizedLike = await request('POST', '/reviews/$reviewId/like');
      expect(unauthorizedLike.status, 401);

      final like = await request(
        'POST',
        '/reviews/$reviewId/like',
        token: bobToken,
      );
      expect(like.status, 200);
      expect(like.body['liked'], true);
      expect(like.body['likeCount'], 1);

      final ownRating = await request(
        'POST',
        '/reviews/$reviewId/rating',
        token: aliceToken,
        body: {'rating': 5},
      );
      expect(ownRating.status, 400);

      final rating = await request(
        'POST',
        '/reviews/$reviewId/rating',
        token: bobToken,
        body: {'rating': 4},
      );
      expect(rating.status, 200);
      expect(rating.body['reviewRating'], 4.0);
      expect(rating.body['reviewRatingCount'], 1);
      expect(rating.body['viewerRating'], 4);

      final changedRating = await request(
        'POST',
        '/reviews/$reviewId/rating',
        token: bobToken,
        body: {'rating': 5},
      );
      expect(changedRating.status, 200);
      expect(changedRating.body['reviewRating'], 5.0);
      expect(changedRating.body['reviewRatingCount'], 1);

      final rankedReviews = await request(
        'GET',
        '/reviews?movieId=693134',
        token: bobToken,
      );
      final rankedReview =
          (rankedReviews.body['items'] as List<dynamic>).first
              as Map<String, dynamic>;
      expect(rankedReview['id'], reviewId);
      expect(rankedReview['viewerRating'], 5);

      final searchedReviews = await request('GET', '/reviews?q=dune');
      expect(searchedReviews.status, 200);
      expect(
        (searchedReviews.body['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((item) => item['id']),
        contains(reviewId),
      );

      final missingReviews = await request(
        'GET',
        '/reviews?q=definitely-not-a-movie',
      );
      expect(missingReviews.status, 200);
      expect(missingReviews.body['items'], isEmpty);

      final comment = await request(
        'POST',
        '/reviews/$reviewId/comments',
        token: bobToken,
        body: {'text': 'I completely agree!'},
      );
      expect(comment.status, 201);

      final comments = await request('GET', '/reviews/$reviewId/comments');
      expect(comments.status, 200);
      expect((comments.body['items'] as List<dynamic>).length, 1);

      final follow = await request(
        'POST',
        '/users/$aliceId/follow',
        token: bobToken,
      );
      expect(follow.status, 200);
      expect(follow.body['following'], true);

      final followingReviews = await request(
        'GET',
        '/reviews',
        token: bobToken,
      );
      final followedReview =
          (followingReviews.body['items'] as List<dynamic>).firstWhere(
                (item) => (item as Map<String, dynamic>)['id'] == reviewId,
              )
              as Map<String, dynamic>;
      final followedAuthor = followedReview['user'] as Map<String, dynamic>;
      expect(followedAuthor['isFollowing'], true);

      final activity = await request('GET', '/activity', token: aliceToken);
      expect(activity.status, 200);
      final activityItems = activity.body['items'] as List<dynamic>;
      expect(activityItems.length, 3);
      expect(
        activityItems.map((item) => (item as Map<String, dynamic>)['type']),
        containsAll(['like', 'comment', 'follow']),
      );

      final followers = await request(
        'GET',
        '/users/$aliceId/followers',
        token: aliceToken,
      );
      expect(followers.status, 200);
      final followerItems = followers.body['items'] as List<dynamic>;
      expect(followerItems.length, 1);
      expect((followerItems.first as Map<String, dynamic>)['id'], bobId);

      final following = await request(
        'GET',
        '/users/$bobId/following',
        token: bobToken,
      );
      expect(following.status, 200);
      final followingUser =
          (following.body['items'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(followingUser['id'], aliceId);
      expect(followingUser['isFollowing'], true);

      final publicProfile = await request('GET', '/users/$aliceId');
      expect(publicProfile.status, 200);
      final publicUser = publicProfile.body['user'] as Map<String, dynamic>;
      expect(publicUser['followerCount'], 1);
      expect(publicUser['reviewCount'], 1);
      expect(publicUser.containsKey('passwordHash'), false);
    },
  );
}

Future<ApiResponse> request(
  String method,
  String path, {
  String? token,
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();
  try {
    final url = baseUrl.resolve(path);
    final request = await client.openUrl(method, url);
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    return ApiResponse(
      response.statusCode,
      text.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(text) as Map<String, dynamic>,
    );
  } finally {
    client.close(force: true);
  }
}

class ApiResponse {
  const ApiResponse(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}
