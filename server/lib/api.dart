import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'security.dart';
import 'store.dart';

class ScenoraApi {
  ScenoraApi({
    required this.store,
    SecurityService? security,
    this.tmdbApiKey,
    this.tmdbReadAccessToken,
    this.supabaseUrl,
    this.supabasePublishableKey,
  }) : security = security ?? SecurityService();

  final ScenoraStore store;
  final SecurityService security;
  final String? tmdbApiKey;
  final String? tmdbReadAccessToken;
  final String? supabaseUrl;
  final String? supabasePublishableKey;

  Handler get handler {
    final router = Router()
      ..get('/health', _health)
      ..post('/auth/register', _register)
      ..post('/auth/login', _login)
      ..post('/auth/google', _googleLogin)
      ..post('/auth/refresh', _refresh)
      ..post('/auth/logout', _logout)
      ..get('/users/me', _getMe)
      ..patch('/users/me', _updateMe)
      ..get('/users/<id>', _getUser)
      ..post('/users/<id>/follow', _toggleFollow)
      ..get('/users/<id>/followers', _followers)
      ..get('/users/<id>/following', _following)
      ..get('/movies/search', _searchMovies)
      ..get('/movies/popular', _popularMovies)
      ..get('/movies/<id>', _getMovie)
      ..get('/watchlist', _watchlist)
      ..post('/watchlist/<movieId>', _toggleWatchlist)
      ..get('/messages', _listMessages)
      ..post('/messages', _createMessage)
      ..get('/reviews', _listReviews)
      ..get('/activity', _activity)
      ..post('/reviews', _createReview)
      ..get('/reviews/<id>', _getReview)
      ..patch('/reviews/<id>', _updateReview)
      ..delete('/reviews/<id>', _deleteReview)
      ..post('/reviews/<id>/rating', _rateReview)
      ..post('/reviews/<id>/like', _toggleLike)
      ..get('/reviews/<id>/comments', _listComments)
      ..post('/reviews/<id>/comments', _createComment)
      ..patch('/comments/<id>', _updateComment)
      ..delete('/comments/<id>', _deleteComment);

    return Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_cors())
        .addHandler(router.call);
  }

  Middleware _cors() =>
      (inner) => (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {...response.headers, ..._corsHeaders});
      };

  static const _corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
  };

  Response _health(Request request) => _ok({
    'status': 'ok',
    'service': 'scenora-backend',
    'version': '1.4.0',
    'time': DateTime.now().toUtc().toIso8601String(),
  });

  Future<Response> _register(Request request) async {
    final body = await _body(request);
    final username = '${body['username'] ?? ''}'.trim().toLowerCase();
    final email = '${body['email'] ?? ''}'.trim().toLowerCase();
    final password = '${body['password'] ?? ''}';
    final displayName = '${body['displayName'] ?? username}'.trim();
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      return _error(
        400,
        'Username must be 3–24 letters, numbers, or underscores.',
      );
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return _error(400, 'A valid email address is required.');
    }
    if (password.length < 8) {
      return _error(400, 'Password must be at least 8 characters.');
    }
    final users = store.table('users');
    if (users.any((u) => u['email'] == email || u['username'] == username)) {
      return _error(409, 'Email or username is already registered.');
    }
    final passwordHash = security.hashPassword(password);
    final now = _now();
    final user = <String, dynamic>{
      'id': store.id('usr'),
      'username': username,
      'email': email,
      'displayName': displayName,
      'bio': '',
      'location': '',
      'avatarUrl': null,
      'coverUrl': null,
      'passwordSalt': passwordHash.salt,
      'passwordHash': passwordHash.hash,
      'accountStatus': 'active',
      'createdAt': now,
      'updatedAt': now,
    };
    users.add(user);
    final tokens = _createSession(user['id'] as String);
    await store.save();
    return _json(201, {'user': _publicUser(user), ...tokens});
  }

  Future<Response> _login(Request request) async {
    final body = await _body(request);
    final email = '${body['email'] ?? ''}'.trim().toLowerCase();
    final password = '${body['password'] ?? ''}';
    final user = _firstOrNull(
      store.table('users').where((u) => u['email'] == email),
    );
    if (user == null ||
        !security.verifyPassword(
          password,
          user['passwordSalt'] as String,
          user['passwordHash'] as String,
        )) {
      return _error(401, 'Invalid email or password.');
    }
    if (user['accountStatus'] != 'active') {
      return _error(403, 'This account is not active.');
    }
    final tokens = _createSession(user['id'] as String);
    await store.save();
    return _ok({'user': _publicUser(user), ...tokens});
  }

  Future<Response> _googleLogin(Request request) async {
    final body = await _body(request);
    final accessToken = '${body['accessToken'] ?? ''}'.trim();
    final projectUrl = supabaseUrl?.trim().replaceFirst(RegExp(r'/+$'), '');
    final publishableKey = supabasePublishableKey?.trim();
    if (projectUrl == null ||
        projectUrl.isEmpty ||
        publishableKey == null ||
        publishableKey.isEmpty) {
      return _error(503, 'Google Sign-In is not configured on the server.');
    }
    if (accessToken.isEmpty) {
      return _error(400, 'A Google authentication token is required.');
    }

    Map<String, dynamic> identity;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final authRequest = await client.getUrl(
        Uri.parse('$projectUrl/auth/v1/user'),
      );
      authRequest.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..set('apikey', publishableKey);
      final authResponse = await authRequest.close();
      final responseText = await utf8.decodeStream(authResponse);
      if (authResponse.statusCode != HttpStatus.ok) {
        return _error(401, 'Google authentication could not be verified.');
      }
      identity = jsonDecode(responseText) as Map<String, dynamic>;
    } on Object {
      return _error(502, 'Could not contact the authentication service.');
    } finally {
      client.close(force: true);
    }

    final email = '${identity['email'] ?? ''}'.trim().toLowerCase();
    if (email.isEmpty || identity['email_confirmed_at'] == null) {
      return _error(401, 'Google did not provide a verified email address.');
    }
    final users = store.table('users');
    var user = _firstOrNull(users.where((item) => item['email'] == email));
    if (user == null) {
      final metadata =
          identity['user_metadata'] as Map<String, dynamic>? ?? const {};
      final displayName =
          '${metadata['full_name'] ?? metadata['name'] ?? email.split('@').first}'
              .trim();
      var username = email
          .split('@')
          .first
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      if (username.length < 3) username = 'google_user';
      if (username.length > 20) username = username.substring(0, 20);
      final base = username;
      var suffix = 1;
      while (users.any((item) => item['username'] == username)) {
        username = '${base}_${suffix++}';
      }
      final passwordHash = security.hashPassword(security.randomToken());
      final now = _now();
      user = <String, dynamic>{
        'id': store.id('usr'),
        'username': username,
        'email': email,
        'displayName': displayName.isEmpty ? username : displayName,
        'bio': '',
        'location': '',
        'avatarUrl': metadata['avatar_url'] ?? metadata['picture'],
        'coverUrl': null,
        'passwordSalt': passwordHash.salt,
        'passwordHash': passwordHash.hash,
        'accountStatus': 'active',
        'createdAt': now,
        'updatedAt': now,
      };
      users.add(user);
    }
    if (user['accountStatus'] != 'active') {
      return _error(403, 'This account is not active.');
    }
    final tokens = _createSession('${user['id']}');
    await store.save();
    return _ok({'user': _publicUser(user), ...tokens});
  }

  Future<Response> _refresh(Request request) async {
    final body = await _body(request);
    final refreshToken = '${body['refreshToken'] ?? ''}';
    final session = _sessionFor(refreshToken, refresh: true);
    if (session == null) {
      return _error(401, 'Invalid or expired refresh token.');
    }
    store.table('sessions').remove(session);
    final user = _userById('${session['userId']}');
    if (user == null) return _error(401, 'The account no longer exists.');
    final tokens = _createSession('${user['id']}');
    await store.save();
    return _ok({'user': _publicUser(user), ...tokens});
  }

  Future<Response> _logout(Request request) async {
    final token = _bearer(request);
    if (token != null) {
      store
          .table('sessions')
          .removeWhere(
            (session) => session['accessHash'] == security.tokenHash(token),
          );
      await store.save();
    }
    return Response(204, headers: _corsHeaders);
  }

  Response _getMe(Request request) {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    return _ok({'user': _publicUser(user, viewerId: user['id'] as String)});
  }

  Future<Response> _updateMe(Request request) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final body = await _body(request);
    const allowed = ['displayName', 'bio', 'location', 'avatarUrl', 'coverUrl'];
    for (final field in allowed) {
      if (body.containsKey(field)) user[field] = body[field];
    }
    if ('${user['bio']}'.length > 300) return _error(400, 'Bio is too long.');
    user['updatedAt'] = _now();
    await store.save();
    return _ok({'user': _publicUser(user, viewerId: user['id'] as String)});
  }

  Response _getUser(Request request, String id) {
    final user = _userById(id);
    if (user == null) return _error(404, 'User not found.');
    final viewer = _authenticatedUser(request);
    return _ok({'user': _publicUser(user, viewerId: viewer?['id'] as String?)});
  }

  Future<Response> _toggleFollow(Request request, String id) async {
    final viewer = _authenticatedUser(request);
    if (viewer == null) return _error(401, 'Authentication required.');
    if (_userById(id) == null) return _error(404, 'User not found.');
    if (viewer['id'] == id) return _error(400, 'You cannot follow yourself.');
    final follows = store.table('follows');
    final existing = _firstOrNull(
      follows.where(
        (f) => f['followerId'] == viewer['id'] && f['followingId'] == id,
      ),
    );
    final following = existing == null;
    if (existing == null) {
      follows.add({
        'id': store.id('fol'),
        'followerId': viewer['id'],
        'followingId': id,
        'createdAt': _now(),
      });
    } else {
      follows.remove(existing);
    }
    await store.save();
    return _ok({
      'following': following,
      'user': _publicUser(_userById(id)!, viewerId: '${viewer['id']}'),
    });
  }

  Response _followers(Request request, String id) {
    if (_userById(id) == null) return _error(404, 'User not found.');
    final ids = store
        .table('follows')
        .where((f) => f['followingId'] == id)
        .map((f) => f['followerId']);
    return _ok({
      'items': ids.map((id) => _publicUser(_userById('$id')!)).toList(),
    });
  }

  Response _following(Request request, String id) {
    if (_userById(id) == null) return _error(404, 'User not found.');
    final ids = store
        .table('follows')
        .where((f) => f['followerId'] == id)
        .map((f) => f['followingId']);
    return _ok({
      'items': ids.map((id) => _publicUser(_userById('$id')!)).toList(),
    });
  }

  Future<Response> _searchMovies(Request request) async {
    final query = request.url.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) return _error(400, 'Search query is required.');
    final remote = await _tmdb('/search/movie', {'query': query});
    if (remote != null) {
      await _cacheMovies(remote);
      return _ok({'source': 'tmdb', 'items': remote});
    }
    final result = store
        .table('movies')
        .where(
          (m) => '${m['title']}'.toLowerCase().contains(query.toLowerCase()),
        );
    return _ok({'source': 'demo-cache', 'items': result.toList()});
  }

  Future<Response> _popularMovies(Request request) async {
    final remote = await _tmdb('/movie/popular', const {});
    if (remote != null) await _cacheMovies(remote);
    return _ok({
      'source': remote == null ? 'demo-cache' : 'tmdb',
      'items': remote ?? store.table('movies'),
    });
  }

  Future<Response> _getMovie(Request request, String id) async {
    final movie = _firstOrNull(
      store.table('movies').where((m) => '${m['id']}' == id),
    );
    if (movie != null) {
      return _ok({'source': 'cache', 'movie': _movieWithRating(movie)});
    }
    final remote = await _tmdb('/movie/$id', const {}, single: true);
    if (remote == null) return _error(404, 'Movie not found.');
    await _cacheMovies(remote);
    return _ok({'source': 'tmdb', 'movie': remote});
  }

  Response _watchlist(Request request) {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final movieIds = store
        .table('watchlist')
        .where((item) => item['userId'] == user['id'])
        .map((item) => '${item['movieId']}')
        .toSet();
    final items = store
        .table('movies')
        .where((movie) => movieIds.contains('${movie['id']}'))
        .map(_movieWithRating)
        .toList();
    return _ok({'items': items});
  }

  Future<Response> _toggleWatchlist(Request request, String movieId) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final movie = _firstOrNull(
      store.table('movies').where((item) => '${item['id']}' == movieId),
    );
    if (movie == null) return _error(404, 'Movie not found.');
    final watchlist = store.table('watchlist');
    final existing = _firstOrNull(
      watchlist.where(
        (item) => item['userId'] == user['id'] && item['movieId'] == movieId,
      ),
    );
    final saved = existing == null;
    if (saved) {
      watchlist.add({
        'id': store.id('wat'),
        'userId': user['id'],
        'movieId': movieId,
        'createdAt': _now(),
      });
    } else {
      watchlist.remove(existing);
    }
    await store.save();
    return _ok({'saved': saved, 'movie': _movieWithRating(movie)});
  }

  Response _listMessages(Request request) {
    final limit = _limit(request);
    final messages = store.table('messages');
    final start = messages.length > limit ? messages.length - limit : 0;
    return _ok({'items': messages.skip(start).map(_messageView).toList()});
  }

  Future<Response> _createMessage(Request request) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final body = await _body(request);
    final text = '${body['text'] ?? ''}'.trim();
    if (text.isEmpty || text.length > 500) {
      return _error(400, 'Message must be 1–500 characters.');
    }
    final message = <String, dynamic>{
      'id': store.id('msg'),
      'userId': user['id'],
      'text': text,
      'createdAt': _now(),
    };
    store.table('messages').add(message);
    await store.save();
    return _json(201, {'message': _messageView(message)});
  }

  Future<void> _cacheMovies(List<Map<String, dynamic>> movies) async {
    final cached = store.table('movies');
    for (final movie in movies) {
      final existing = _firstOrNull(
        cached.where((item) => '${item['id']}' == '${movie['id']}'),
      );
      if (existing == null) {
        cached.add(movie);
      } else {
        existing.addAll(movie);
      }
    }
    await store.save();
  }

  Response _listReviews(Request request) {
    final movieId = request.url.queryParameters['movieId'];
    final userId = request.url.queryParameters['userId'];
    final query = request.url.queryParameters['q']?.trim().toLowerCase();
    final limit = _limit(request);
    Iterable<Map<String, dynamic>> reviews = store.table('reviews');
    if (movieId != null) {
      reviews = reviews.where((r) => r['movieId'] == movieId);
    }
    if (userId != null) reviews = reviews.where((r) => r['userId'] == userId);
    if (query != null && query.isNotEmpty) {
      reviews = reviews.where((review) {
        final movie = _firstOrNull(
          store
              .table('movies')
              .where((item) => '${item['id']}' == '${review['movieId']}'),
        );
        final author = _userById('${review['userId']}');
        return '${movie?['title'] ?? ''}'.toLowerCase().contains(query) ||
            '${review['text'] ?? ''}'.toLowerCase().contains(query) ||
            '${author?['displayName'] ?? ''}'.toLowerCase().contains(query) ||
            '${author?['username'] ?? ''}'.toLowerCase().contains(query);
      });
    }
    final viewerId = _authenticatedUser(request)?['id'] as String?;
    final items =
        reviews
            .map((review) => _reviewView(review, viewerId: viewerId))
            .toList()
          ..sort((a, b) {
            final score = (b['reviewRating'] as num).compareTo(
              a['reviewRating'] as num,
            );
            if (score != 0) return score;
            final count = (b['reviewRatingCount'] as int).compareTo(
              a['reviewRatingCount'] as int,
            );
            if (count != 0) return count;
            return '${b['createdAt']}'.compareTo('${a['createdAt']}');
          });
    return _ok({'items': items.take(limit).toList()});
  }

  Response _activity(Request request) {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final userId = user['id'];
    final ownReviews = {
      for (final review in store.table('reviews'))
        if (review['userId'] == userId) '${review['id']}': review,
    };
    final events = <Map<String, dynamic>>[];

    for (final like in store.table('likes')) {
      final review = ownReviews['${like['reviewId']}'];
      if (review == null || like['userId'] == userId) continue;
      events.add(_activityView('like', like, review: review));
    }
    for (final comment in store.table('comments')) {
      final review = ownReviews['${comment['reviewId']}'];
      if (review == null || comment['userId'] == userId) continue;
      events.add(
        _activityView(
          'comment',
          comment,
          review: review,
          text: '${comment['text']}',
        ),
      );
    }
    for (final follow in store.table('follows')) {
      if (follow['followingId'] != userId) continue;
      events.add(_activityView('follow', follow));
    }
    events.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return _ok({'items': events.take(_limit(request)).toList()});
  }

  Map<String, dynamic> _activityView(
    String type,
    Map<String, dynamic> source, {
    Map<String, dynamic>? review,
    String? text,
  }) {
    final actorId = type == 'follow' ? source['followerId'] : source['userId'];
    final movie = review == null
        ? null
        : _firstOrNull(
            store
                .table('movies')
                .where((item) => '${item['id']}' == '${review['movieId']}'),
          );
    return {
      'id': source['id'],
      'type': type,
      'actor': _publicUser(_userById('$actorId')!),
      'reviewId': review?['id'],
      'movieTitle': movie?['title'],
      'text': text,
      'createdAt': source['createdAt'],
    };
  }

  Future<Response> _createReview(Request request) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final body = await _body(request);
    final movieId = '${body['movieId'] ?? ''}';
    final rating = body['rating'];
    final text = '${body['text'] ?? ''}'.trim();
    if (_firstOrNull(
          store.table('movies').where((m) => '${m['id']}' == movieId),
        ) ==
        null) {
      return _error(404, 'Movie not found.');
    }
    if (rating is! num || rating < 1 || rating > 5) {
      return _error(400, 'Rating must be between 1 and 5.');
    }
    if (text.isEmpty || text.length > 2000) {
      return _error(400, 'Review text must be 1–2000 characters.');
    }
    final now = _now();
    final review = <String, dynamic>{
      'id': store.id('rev'),
      'userId': user['id'],
      'movieId': movieId,
      'rating': rating.toInt(),
      'text': text,
      'containsSpoiler': body['containsSpoiler'] == true,
      'imageUrls': (body['imageUrls'] as List<dynamic>?) ?? <dynamic>[],
      'createdAt': now,
      'updatedAt': now,
    };
    store.table('reviews').add(review);
    await store.save();
    return _json(201, {
      'review': _reviewView(review, viewerId: '${user['id']}'),
    });
  }

  Response _getReview(Request request, String id) {
    final review = _reviewById(id);
    return review == null
        ? _error(404, 'Review not found.')
        : _ok({
            'review': _reviewView(
              review,
              viewerId: _authenticatedUser(request)?['id'] as String?,
            ),
          });
  }

  Future<Response> _updateReview(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final review = _reviewById(id);
    if (review == null) return _error(404, 'Review not found.');
    if (review['userId'] != user['id']) {
      return _error(403, 'You do not own this review.');
    }
    final body = await _body(request);
    if (body['rating'] case final num rating when rating >= 1 && rating <= 5) {
      review['rating'] = rating.toInt();
    }
    if (body.containsKey('text')) {
      final text = '${body['text']}'.trim();
      if (text.isEmpty || text.length > 2000) {
        return _error(400, 'Invalid review text.');
      }
      review['text'] = text;
    }
    if (body.containsKey('containsSpoiler')) {
      review['containsSpoiler'] = body['containsSpoiler'] == true;
    }
    review['updatedAt'] = _now();
    await store.save();
    return _ok({'review': _reviewView(review, viewerId: '${user['id']}')});
  }

  Future<Response> _deleteReview(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final review = _reviewById(id);
    if (review == null) return _error(404, 'Review not found.');
    if (review['userId'] != user['id']) {
      return _error(403, 'You do not own this review.');
    }
    store.table('reviews').remove(review);
    store.table('reviewRatings').removeWhere((r) => r['reviewId'] == id);
    store.table('likes').removeWhere((l) => l['reviewId'] == id);
    store.table('comments').removeWhere((c) => c['reviewId'] == id);
    await store.save();
    return Response(204, headers: _corsHeaders);
  }

  Future<Response> _rateReview(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final review = _reviewById(id);
    if (review == null) return _error(404, 'Review not found.');
    if (review['userId'] == user['id']) {
      return _error(400, 'You cannot rate your own review.');
    }
    final body = await _body(request);
    final rating = body['rating'];
    if (rating is! num ||
        rating.toInt() != rating ||
        rating < 1 ||
        rating > 5) {
      return _error(400, 'Review rating must be between 1 and 5.');
    }
    final ratings = store.table('reviewRatings');
    final existing = _firstOrNull(
      ratings.where(
        (item) => item['reviewId'] == id && item['userId'] == user['id'],
      ),
    );
    final now = _now();
    if (existing == null) {
      ratings.add({
        'id': store.id('rrt'),
        'reviewId': id,
        'userId': user['id'],
        'rating': rating.toInt(),
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      existing['rating'] = rating.toInt();
      existing['updatedAt'] = now;
    }
    await store.save();
    return _ok(_reviewRatingStats(id, viewerId: '${user['id']}'));
  }

  Future<Response> _toggleLike(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    if (_reviewById(id) == null) return _error(404, 'Review not found.');
    final likes = store.table('likes');
    final existing = _firstOrNull(
      likes.where((l) => l['reviewId'] == id && l['userId'] == user['id']),
    );
    final liked = existing == null;
    if (existing == null) {
      likes.add({
        'id': store.id('lik'),
        'reviewId': id,
        'userId': user['id'],
        'createdAt': _now(),
      });
    } else {
      likes.remove(existing);
    }
    await store.save();
    return _ok({
      'liked': liked,
      'likeCount': likes.where((l) => l['reviewId'] == id).length,
    });
  }

  Response _listComments(Request request, String id) {
    if (_reviewById(id) == null) return _error(404, 'Review not found.');
    final comments = store.table('comments').where((c) => c['reviewId'] == id);
    return _ok({'items': comments.map(_commentView).toList()});
  }

  Future<Response> _createComment(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    if (_reviewById(id) == null) return _error(404, 'Review not found.');
    final body = await _body(request);
    final text = '${body['text'] ?? ''}'.trim();
    if (text.isEmpty || text.length > 1000) {
      return _error(400, 'Comment must be 1–1000 characters.');
    }
    final comment = <String, dynamic>{
      'id': store.id('com'),
      'reviewId': id,
      'userId': user['id'],
      'text': text,
      'parentCommentId': body['parentCommentId'],
      'createdAt': _now(),
      'updatedAt': _now(),
    };
    store.table('comments').add(comment);
    await store.save();
    return _json(201, {'comment': _commentView(comment)});
  }

  Future<Response> _updateComment(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final comment = _firstOrNull(
      store.table('comments').where((c) => c['id'] == id),
    );
    if (comment == null) return _error(404, 'Comment not found.');
    if (comment['userId'] != user['id']) {
      return _error(403, 'You do not own this comment.');
    }
    final body = await _body(request);
    final text = '${body['text'] ?? ''}'.trim();
    if (text.isEmpty || text.length > 1000) {
      return _error(400, 'Invalid comment text.');
    }
    comment['text'] = text;
    comment['updatedAt'] = _now();
    await store.save();
    return _ok({'comment': _commentView(comment)});
  }

  Future<Response> _deleteComment(Request request, String id) async {
    final user = _authenticatedUser(request);
    if (user == null) return _error(401, 'Authentication required.');
    final comment = _firstOrNull(
      store.table('comments').where((c) => c['id'] == id),
    );
    if (comment == null) return _error(404, 'Comment not found.');
    if (comment['userId'] != user['id']) {
      return _error(403, 'You do not own this comment.');
    }
    store.table('comments').remove(comment);
    await store.save();
    return Response(204, headers: _corsHeaders);
  }

  Map<String, dynamic> _createSession(String userId) {
    final accessToken = security.randomToken();
    final refreshToken = security.randomToken(48);
    final now = DateTime.now().toUtc();
    store
        .table('sessions')
        .removeWhere(
          (s) => DateTime.parse('${s['refreshExpiresAt']}').isBefore(now),
        );
    store.table('sessions').add({
      'id': store.id('ses'),
      'userId': userId,
      'accessHash': security.tokenHash(accessToken),
      'refreshHash': security.tokenHash(refreshToken),
      'accessExpiresAt': now.add(const Duration(minutes: 15)).toIso8601String(),
      'refreshExpiresAt': now.add(const Duration(days: 30)).toIso8601String(),
    });
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': 900,
    };
  }

  Map<String, dynamic>? _sessionFor(String token, {bool refresh = false}) {
    final hash = security.tokenHash(token);
    final field = refresh ? 'refreshHash' : 'accessHash';
    final expiry = refresh ? 'refreshExpiresAt' : 'accessExpiresAt';
    return _firstOrNull(
      store
          .table('sessions')
          .where(
            (s) =>
                s[field] == hash &&
                DateTime.parse('${s[expiry]}').isAfter(DateTime.now().toUtc()),
          ),
    );
  }

  Map<String, dynamic>? _authenticatedUser(Request request) {
    final token = _bearer(request);
    if (token == null) return null;
    final session = _sessionFor(token);
    return session == null ? null : _userById('${session['userId']}');
  }

  String? _bearer(Request request) {
    final value = request.headers['authorization'];
    if (value == null || !value.startsWith('Bearer ')) return null;
    return value.substring(7).trim();
  }

  Map<String, dynamic>? _userById(String id) =>
      _firstOrNull(store.table('users').where((u) => u['id'] == id));

  Map<String, dynamic>? _reviewById(String id) =>
      _firstOrNull(store.table('reviews').where((r) => r['id'] == id));

  Map<String, dynamic> _publicUser(
    Map<String, dynamic> user, {
    String? viewerId,
  }) {
    final userId = user['id'];
    final follows = store.table('follows');
    return {
      'id': userId,
      'username': user['username'],
      'displayName': user['displayName'],
      'bio': user['bio'],
      'location': user['location'],
      'avatarUrl': user['avatarUrl'],
      'coverUrl': user['coverUrl'],
      'followerCount': follows.where((f) => f['followingId'] == userId).length,
      'followingCount': follows.where((f) => f['followerId'] == userId).length,
      'reviewCount': store
          .table('reviews')
          .where((r) => r['userId'] == userId)
          .length,
      'isFollowing': viewerId == null
          ? false
          : follows.any(
              (f) => f['followerId'] == viewerId && f['followingId'] == userId,
            ),
      'createdAt': user['createdAt'],
    };
  }

  Map<String, dynamic> _reviewView(
    Map<String, dynamic> review, {
    String? viewerId,
  }) {
    final id = review['id'];
    final movie = _firstOrNull(
      store.table('movies').where((m) => '${m['id']}' == review['movieId']),
    );
    return {
      ...review,
      'user': _publicUser(
        _userById('${review['userId']}')!,
        viewerId: viewerId,
      ),
      'movie': movie,
      'likeCount': store
          .table('likes')
          .where((l) => l['reviewId'] == id)
          .length,
      'commentCount': store
          .table('comments')
          .where((c) => c['reviewId'] == id)
          .length,
      'liked':
          viewerId != null &&
          store
              .table('likes')
              .any(
                (like) => like['reviewId'] == id && like['userId'] == viewerId,
              ),
      ..._reviewRatingStats('$id', viewerId: viewerId),
    };
  }

  Map<String, dynamic> _reviewRatingStats(String reviewId, {String? viewerId}) {
    final ratings = store
        .table('reviewRatings')
        .where((item) => item['reviewId'] == reviewId)
        .toList();
    final total = ratings.fold<int>(
      0,
      (sum, item) => sum + (item['rating'] as num).toInt(),
    );
    final viewerRating = viewerId == null
        ? null
        : _firstOrNull(
            ratings.where((item) => item['userId'] == viewerId),
          )?['rating'];
    return {
      'reviewRating': ratings.isEmpty ? 0.0 : total / ratings.length,
      'reviewRatingCount': ratings.length,
      'viewerRating': viewerRating,
    };
  }

  Map<String, dynamic> _commentView(Map<String, dynamic> comment) => {
    ...comment,
    'user': _publicUser(_userById('${comment['userId']}')!),
  };

  Map<String, dynamic> _messageView(Map<String, dynamic> message) => {
    ...message,
    'user': _publicUser(_userById('${message['userId']}')!),
  };

  Map<String, dynamic> _movieWithRating(Map<String, dynamic> movie) {
    final ratings = store
        .table('reviews')
        .where((r) => r['movieId'] == '${movie['id']}')
        .map((r) => (r['rating'] as num).toDouble())
        .toList();
    return {
      ...movie,
      'scenoraRating': ratings.isEmpty
          ? 0
          : ratings.reduce((a, b) => a + b) / ratings.length,
      'reviewCount': ratings.length,
    };
  }

  Future<List<Map<String, dynamic>>?> _tmdb(
    String path,
    Map<String, String> parameters, {
    bool single = false,
  }) async {
    final key = tmdbApiKey?.trim();
    final token = tmdbReadAccessToken?.trim();
    if ((key == null || key.isEmpty) && (token == null || token.isEmpty)) {
      return null;
    }
    final uri = Uri.https('api.themoviedb.org', '/3$path', {
      if (key != null && key.isNotEmpty) 'api_key': key,
      ...parameters,
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(await utf8.decodeStream(response));
      final rawItems = single
          ? [decoded]
          : (decoded['results'] as List<dynamic>);
      return rawItems.map<Map<String, dynamic>>((item) {
        final map = item as Map<String, dynamic>;
        final date = '${map['release_date'] ?? ''}';
        return {
          'id': '${map['id']}',
          'title': map['title'] ?? map['name'],
          'year': date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null,
          'overview': map['overview'],
          'tmdbRating': map['vote_average'],
          'posterPath': map['poster_path'],
          'backdropPath': map['backdrop_path'],
        };
      }).toList();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _body(Request request) async {
    try {
      final decoded = jsonDecode(await request.readAsString());
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  int _limit(Request request) {
    final value =
        int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
    return value.clamp(1, 50);
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

  Response _ok(Object body) => _json(200, body);

  Response _error(int status, String message) =>
      _json(status, {'error': message});

  Response _json(int status, Object body) => Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ..._corsHeaders,
    },
  );
}
