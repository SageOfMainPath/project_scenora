import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scenora_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ScenoraApiClient {
  ScenoraApiClient({String? baseUrl, String? productionBaseUrl})
    : _productionBaseUrl = productionBaseUrl ?? _compiledBaseUrl,
      _baseUrl =
          baseUrl ??
          ((productionBaseUrl ?? _compiledBaseUrl).isNotEmpty
              ? (productionBaseUrl ?? _compiledBaseUrl)
              : 'http://192.168.206.103:8080');

  static const _serverUrlKey = 'scenora_server_url';
  static const _accessTokenKey = 'scenora_access_token';
  static const _refreshTokenKey = 'scenora_refresh_token';
  static const _compiledBaseUrl = String.fromEnvironment('SCENORA_API_URL');
  static const _secureStorage = FlutterSecureStorage();

  String _baseUrl;
  final String _productionBaseUrl;
  String get baseUrl => _baseUrl;
  bool get isProductionServerLocked => _productionBaseUrl.isNotEmpty;
  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? currentUser;
  Future<void>? _refreshFuture;

  bool get isLoggedIn => accessToken != null;

  Future<bool> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    if (isProductionServerLocked) {
      // APK upgrades retain SharedPreferences. Remove old demo IP/Cloudflare
      // addresses so a production build always talks to the Render backend.
      _baseUrl = _productionBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      await preferences.remove(_serverUrlKey);
    } else {
      _baseUrl = preferences.getString(_serverUrlKey) ?? _baseUrl;
    }
    try {
      accessToken = await _secureStorage.read(key: _accessTokenKey);
      refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken!.isEmpty) return false;
      await _refreshSession();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearSession();
        return false;
      }
      // Keep a previously valid session during a temporary outage or while a
      // free hosting instance is waking up. The next request will retry it.
      return accessToken != null || refreshToken != null;
    } on Object {
      return accessToken != null || refreshToken != null;
    }
  }

  Future<void> updateBaseUrl(String value) async {
    if (isProductionServerLocked) {
      throw const ApiException(
        'This release is permanently connected to the SCENORA cloud server.',
      );
    }
    var normalized = value.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    normalized = normalized.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty || !uri.hasScheme) {
      throw const ApiException('Enter a valid server address.');
    }
    await _checkHealth(normalized);
    _baseUrl = normalized;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_serverUrlKey, normalized);
    } catch (_) {
      throw const ApiException('Could not save the server address.');
    }
    await _clearSession();
  }

  Future<void> _checkHealth(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final response = await (await client.getUrl(
        Uri.parse('$url/health'),
      )).close();
      final body = await utf8.decodeStream(response);
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['status'] != 'ok') {
        throw const ApiException('This is not a working SCENORA server.');
      }
    } on ApiException {
      rethrow;
    } on Object {
      throw ApiException('Cannot connect to $url. Check the IP and firewall.');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> login(String email, String password) async {
    final result = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _saveSession(result);
  }

  Future<void> loginWithGoogle(String supabaseAccessToken) async {
    final result = await _request(
      'POST',
      '/auth/google',
      body: {'accessToken': supabaseAccessToken},
    );
    await _saveSession(result);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final result = await _request(
      'POST',
      '/auth/register',
      body: {
        'username': username,
        'displayName': username,
        'email': email,
        'password': password,
      },
    );
    await _saveSession(result);
  }

  Future<void> logout() async {
    try {
      await _request('POST', '/auth/logout', authenticated: true);
    } finally {
      await _clearSession();
    }
  }

  Future<List<Movie>> searchMovies(String query) async {
    final result = await _request(
      'GET',
      '/movies/search?q=${Uri.encodeQueryComponent(query)}',
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _movie(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Movie>> popularMovies() async {
    final result = await _request('GET', '/movies/popular');
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _movie(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Movie>> watchlist() async {
    final result = await _request('GET', '/watchlist', authenticated: true);
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _movie(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> toggleWatchlist(String movieId) async {
    final result = await _request(
      'POST',
      '/watchlist/$movieId',
      authenticated: true,
    );
    return result['saved'] == true;
  }

  Future<List<ChatMessage>> messages() async {
    final result = await _request('GET', '/messages?limit=50');
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _message(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(String text) async {
    final result = await _request(
      'POST',
      '/messages',
      authenticated: true,
      body: {'text': text},
    );
    return _message(result['message'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    required String bio,
    required String location,
    String? avatarUrl,
  }) async {
    final result = await _request(
      'PATCH',
      '/users/me',
      authenticated: true,
      body: {
        'displayName': displayName,
        'bio': bio,
        'location': location,
        'avatarUrl': avatarUrl,
      },
    );
    currentUser = result['user'] as Map<String, dynamic>;
    return currentUser!;
  }

  Future<List<Review>> reviews() async {
    final result = await _request(
      'GET',
      '/reviews?limit=50',
      authenticated: isLoggedIn,
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _review(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Review>> reviewsForMovie(String movieId) async {
    final result = await _request(
      'GET',
      '/reviews?movieId=${Uri.encodeQueryComponent(movieId)}&limit=50',
      authenticated: isLoggedIn,
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _review(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Review>> reviewsForUser(String userId) async {
    final result = await _request(
      'GET',
      '/reviews?userId=${Uri.encodeQueryComponent(userId)}&limit=100',
      authenticated: isLoggedIn,
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _review(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Review>> searchReviews(String query) async {
    final result = await _request(
      'GET',
      '/reviews?q=${Uri.encodeQueryComponent(query)}&limit=100',
      authenticated: isLoggedIn,
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _review(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> profile() async {
    final result = await _request('GET', '/users/me', authenticated: true);
    currentUser = result['user'] as Map<String, dynamic>;
    return currentUser!;
  }

  Future<List<ActivityItem>> activity() async {
    final result = await _request('GET', '/activity', authenticated: true);
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => _activity(item as Map<String, dynamic>))
        .toList();
  }

  Future<Review> createReview({
    required Movie movie,
    required int rating,
    required String text,
    required bool containsSpoiler,
  }) async {
    if (movie.id == null) {
      throw const ApiException('This movie has no backend ID.');
    }
    final result = await _request(
      'POST',
      '/reviews',
      authenticated: true,
      body: {
        'movieId': movie.id,
        'rating': rating,
        'text': text,
        'containsSpoiler': containsSpoiler,
      },
    );
    return _review(result['review'] as Map<String, dynamic>);
  }

  Future<({bool liked, int likeCount})> toggleLike(String reviewId) async {
    final result = await _request(
      'POST',
      '/reviews/$reviewId/like',
      authenticated: true,
    );
    return (
      liked: result['liked'] == true,
      likeCount: (result['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> toggleFollow(String userId) async {
    final result = await _request(
      'POST',
      '/users/$userId/follow',
      authenticated: true,
    );
    return result['following'] == true;
  }

  Future<List<Map<String, dynamic>>> followers(String userId) =>
      _connections(userId, 'followers');

  Future<List<Map<String, dynamic>>> following(String userId) =>
      _connections(userId, 'following');

  Future<List<Map<String, dynamic>>> _connections(
    String userId,
    String relationship,
  ) async {
    final result = await _request(
      'GET',
      '/users/${Uri.encodeComponent(userId)}/$relationship',
      authenticated: isLoggedIn,
    );
    return (result['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Review> updateReview({
    required String reviewId,
    required int rating,
    required String text,
    required bool containsSpoiler,
  }) async {
    final result = await _request(
      'PATCH',
      '/reviews/$reviewId',
      authenticated: true,
      body: {
        'rating': rating,
        'text': text,
        'containsSpoiler': containsSpoiler,
      },
    );
    return _review(result['review'] as Map<String, dynamic>);
  }

  Future<void> deleteReview(String reviewId) async {
    await _request('DELETE', '/reviews/$reviewId', authenticated: true);
  }

  Future<({double score, int count, int viewerRating})> rateReview(
    String reviewId,
    int rating,
  ) async {
    final result = await _request(
      'POST',
      '/reviews/$reviewId/rating',
      authenticated: true,
      body: {'rating': rating},
    );
    return (
      score: (result['reviewRating'] as num?)?.toDouble() ?? 0,
      count: (result['reviewRatingCount'] as num?)?.toInt() ?? 0,
      viewerRating: (result['viewerRating'] as num?)?.toInt() ?? rating,
    );
  }

  Future<List<Map<String, dynamic>>> comments(String reviewId) async {
    final result = await _request('GET', '/reviews/$reviewId/comments');
    return (result['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addComment(String reviewId, String text) async {
    final result = await _request(
      'POST',
      '/reviews/$reviewId/comments',
      authenticated: true,
      body: {'text': text},
    );
    return result['comment'] as Map<String, dynamic>;
  }

  Future<void> _saveSession(Map<String, dynamic> result) async {
    final nextAccessToken = result['accessToken'] as String?;
    final nextRefreshToken = result['refreshToken'] as String?;
    if (nextAccessToken != null && nextAccessToken.isNotEmpty) {
      accessToken = nextAccessToken;
    }
    if (nextRefreshToken != null && nextRefreshToken.isNotEmpty) {
      refreshToken = nextRefreshToken;
    }
    if (result['user'] case final Map<String, dynamic> user) {
      currentUser = user;
    }
    if (accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> _refreshSession() {
    final pending = _refreshFuture;
    if (pending != null) return pending;
    final token = refreshToken;
    if (token == null || token.isEmpty) {
      return Future<void>.error(const ApiException('Please log in first.'));
    }
    final operation = () async {
      final result = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': token},
        retryAuthentication: false,
      );
      await _saveSession(result);
    }();
    _refreshFuture = operation;
    return operation.whenComplete(() {
      if (identical(_refreshFuture, operation)) _refreshFuture = null;
    });
  }

  Future<void> _clearSession() async {
    accessToken = null;
    refreshToken = null;
    currentUser = null;
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (_) {
      // In-memory session is still cleared when secure storage is unavailable.
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    bool retryAuthentication = true,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (authenticated) {
        if (accessToken == null) {
          throw const ApiException('Please log in first.');
        }
        request.headers.set('authorization', 'Bearer $accessToken');
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final responseText = await utf8.decodeStream(response);
      final decoded = responseText.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseText) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 &&
            authenticated &&
            retryAuthentication &&
            refreshToken != null) {
          await _refreshSession();
          return await _request(
            method,
            path,
            body: body,
            authenticated: true,
            retryAuthentication: false,
          );
        }
        throw ApiException(
          '${decoded['error'] ?? 'Backend request failed.'}',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on SocketException {
      throw ApiException(
        'Cannot reach the SCENORA server at $baseUrl. Keep the PC server running and connect the phone to the same Wi-Fi.',
      );
    } on HandshakeException {
      throw const ApiException(
        'Could not establish a secure server connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Movie _movie(Map<String, dynamic> json) {
    final title = '${json['title'] ?? 'Untitled'}';
    final posterPath = '${json['posterPath'] ?? ''}'.trim();
    final palette = _palette(title);
    final words = title.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return Movie(
      id: '${json['id']}',
      posterUrl: posterPath.isEmpty
          ? null
          : posterPath.startsWith('http')
          ? posterPath
          : 'https://image.tmdb.org/t/p/w500$posterPath',
      title: title,
      year: (json['year'] as num?)?.toInt() ?? 0,
      genre: '${json['genre'] ?? 'Movie · TMDB'}',
      score: (json['tmdbRating'] as num?)?.toDouble() ?? 0,
      communityScore: (json['scenoraRating'] as num?)?.toDouble() ?? 0,
      colors: palette,
      initials: initials.isEmpty ? 'M' : initials,
      synopsis: '${json['overview'] ?? 'No storyline is available yet.'}',
    );
  }

  Review _review(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final movie = json['movie'] as Map<String, dynamic>? ?? const {};
    final name = '${user['displayName'] ?? user['username'] ?? 'SCENORA user'}';
    return Review(
      id: '${json['id']}',
      userId: '${json['userId']}',
      user: name,
      handle: '@${user['username'] ?? 'member'}',
      avatarColor: _palette(name).first,
      avatarUrl: '${user['avatarUrl'] ?? ''}'.trim().isEmpty
          ? null
          : '${user['avatarUrl']}',
      movie: _movie(movie),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: '${json['text'] ?? ''}',
      time: 'now',
      likes: (json['likeCount'] as num?)?.toInt() ?? 0,
      comments: (json['commentCount'] as num?)?.toInt() ?? 0,
      liked: json['liked'] == true,
      spoiler: json['containsSpoiler'] == true,
      reviewRating: (json['reviewRating'] as num?)?.toDouble() ?? 0,
      reviewRatingCount: (json['reviewRatingCount'] as num?)?.toInt() ?? 0,
      viewerRating: (json['viewerRating'] as num?)?.toInt(),
      isFollowing: user['isFollowing'] == true,
    );
  }

  ActivityItem _activity(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>? ?? const {};
    final actorName =
        '${actor['displayName'] ?? actor['username'] ?? 'Someone'}';
    final type = '${json['type']}';
    final movieTitle = '${json['movieTitle'] ?? 'your movie'}';
    return ActivityItem(
      icon: switch (type) {
        'like' => Icons.favorite_rounded,
        'comment' => Icons.chat_bubble_rounded,
        'follow' => Icons.person_add_alt_1_rounded,
        _ => Icons.notifications_rounded,
      },
      color: switch (type) {
        'like' => const Color(0xFFE5384F),
        'comment' => const Color(0xFF4B8DF8),
        'follow' => const Color(0xFF25B487),
        _ => const Color(0xFF9C6ADE),
      },
      title: switch (type) {
        'like' => '$actorName liked your review',
        'comment' => '$actorName commented on your review',
        'follow' => '$actorName started following you',
        _ => 'New activity',
      },
      subtitle: type == 'follow'
          ? '@${actor['username'] ?? 'member'}'
          : type == 'comment'
          ? '${json['text'] ?? movieTitle}'
          : movieTitle,
      time: _relativeTime('${json['createdAt'] ?? ''}'),
    );
  }

  ChatMessage _message(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final userId = '${json['userId'] ?? ''}';
    final name = '${user['displayName'] ?? user['username'] ?? 'Member'}';
    return ChatMessage(
      id: '${json['id']}',
      userId: userId,
      user: name,
      text: '${json['text'] ?? ''}',
      time: _relativeTime('${json['createdAt'] ?? ''}'),
      color: _palette(name).first,
      isMine: userId.isNotEmpty && userId == '${currentUser?['id'] ?? ''}',
    );
  }

  String _relativeTime(String value) {
    final timestamp = DateTime.tryParse(value)?.toLocal();
    if (timestamp == null) return 'now';
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  List<Color> _palette(String seed) {
    const palettes = [
      [Color(0xFFE19355), Color(0xFF4A241A)],
      [Color(0xFF5F6BEA), Color(0xFF292D66)],
      [Color(0xFFE5384F), Color(0xFF4A1420)],
      [Color(0xFF2BAA82), Color(0xFF153E35)],
      [Color(0xFF8C48E8), Color(0xFFEC3B61)],
    ];
    return palettes[seed.hashCode.abs() % palettes.length];
  }
}
