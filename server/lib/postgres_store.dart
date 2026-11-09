import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart';

import 'store.dart';

class PostgresStore implements ScenoraStore {
  PostgresStore._(this._connection);

  static Future<PostgresStore> open(String connectionString) async {
    var url = connectionString.trim();
    if (!url.contains('sslmode=')) {
      url += url.contains('?') ? '&sslmode=require' : '?sslmode=require';
    }
    final connection = await Connection.openFromUrl(url);
    final store = PostgresStore._(connection);
    await store._load();
    return store;
  }

  final Connection _connection;
  final Random _random = Random.secure();
  Future<void> _saveQueue = Future.value();

  @override
  late Map<String, dynamic> data;

  @override
  List<Map<String, dynamic>> table(String name) =>
      (data[name] as List<dynamic>).cast<Map<String, dynamic>>();

  @override
  String id(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(0x7fffffff).toRadixString(36);
    return '${prefix}_$time$random';
  }

  @override
  Future<void> save() {
    final snapshot = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    final next = _saveQueue.then((_) => _persist(snapshot));
    _saveQueue = next.catchError((_) {});
    return next;
  }

  Future<void> close() async {
    await _saveQueue;
    await _connection.close();
  }

  Future<void> _load() async {
    data = {
      'users': await _query('''
        select id, username, email, display_name as "displayName", bio,
          location, avatar_url as "avatarUrl", cover_url as "coverUrl",
          password_salt as "passwordSalt", password_hash as "passwordHash",
          account_status as "accountStatus", created_at as "createdAt",
          updated_at as "updatedAt"
        from scenora.users order by created_at
      '''),
      'sessions': await _query('''
        select id, user_id as "userId", access_hash as "accessHash",
          refresh_hash as "refreshHash", access_expires_at as "accessExpiresAt",
          refresh_expires_at as "refreshExpiresAt"
        from scenora.sessions
      '''),
      'movies': await _query('''
        select id, title, year, genre, overview, tmdb_rating as "tmdbRating",
          poster_path as "posterPath", backdrop_path as "backdropPath"
        from scenora.movies order by title
      '''),
      'reviews': await _query('''
        select id, user_id as "userId", movie_id as "movieId", rating, text,
          contains_spoiler as "containsSpoiler", image_urls as "imageUrls",
          created_at as "createdAt", updated_at as "updatedAt"
        from scenora.reviews order by created_at
      '''),
      'reviewRatings': await _query('''
        select id, review_id as "reviewId", user_id as "userId", rating,
          created_at as "createdAt", updated_at as "updatedAt"
        from scenora.review_ratings order by created_at
      '''),
      'likes': await _query('''
        select id, review_id as "reviewId", user_id as "userId",
          created_at as "createdAt"
        from scenora.likes order by created_at
      '''),
      'comments': await _query('''
        select id, review_id as "reviewId", user_id as "userId", text,
          parent_comment_id as "parentCommentId", created_at as "createdAt",
          updated_at as "updatedAt"
        from scenora.comments order by created_at
      '''),
      'follows': await _query('''
        select id, follower_id as "followerId", following_id as "followingId",
          created_at as "createdAt"
        from scenora.follows order by created_at
      '''),
      'watchlist': await _query('''
        select id, user_id as "userId", movie_id as "movieId",
          created_at as "createdAt"
        from scenora.watchlist order by created_at
      '''),
      'messages': await _query('''
        select id, user_id as "userId", text, created_at as "createdAt"
        from scenora.messages order by created_at
      '''),
    };
  }

  Future<List<Map<String, dynamic>>> _query(String sql) async {
    final result = await _connection.execute(sql);
    return result.map((row) {
      final values = row.toColumnMap();
      return values.map((key, value) => MapEntry(key, _jsonValue(value)));
    }).toList();
  }

  Object? _jsonValue(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is List) return value.map(_jsonValue).toList();
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', _jsonValue(item)));
    }
    return value;
  }

  Future<void> _persist(Map<String, dynamic> snapshot) async {
    await _connection.runTx((tx) async {
      for (final table in const [
        'comments',
        'review_ratings',
        'likes',
        'sessions',
        'messages',
        'watchlist',
        'follows',
        'reviews',
        'movies',
        'users',
      ]) {
        await tx.execute('delete from scenora.$table');
      }

      await _insert(tx, snapshot['users'] as List<dynamic>, '''
        insert into scenora.users
          (id, username, email, display_name, bio, location, avatar_url,
           cover_url, password_salt, password_hash, account_status, created_at,
           updated_at)
        select id, username, email, "displayName", bio, location, "avatarUrl",
          "coverUrl", "passwordSalt", "passwordHash", "accountStatus",
          "createdAt"::timestamptz, "updatedAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, username text, email text, "displayName" text, bio text,
          location text, "avatarUrl" text, "coverUrl" text,
          "passwordSalt" text, "passwordHash" text, "accountStatus" text,
          "createdAt" text, "updatedAt" text)
      ''');
      await _insert(tx, snapshot['movies'] as List<dynamic>, '''
        insert into scenora.movies
          (id, title, year, genre, overview, tmdb_rating, poster_path, backdrop_path)
        select id, title, year, genre, overview, "tmdbRating", "posterPath",
          "backdropPath"
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, title text, year integer, genre text, overview text,
          "tmdbRating" numeric, "posterPath" text, "backdropPath" text)
      ''');
      await _insert(tx, snapshot['sessions'] as List<dynamic>, '''
        insert into scenora.sessions
          (id, user_id, access_hash, refresh_hash, access_expires_at,
           refresh_expires_at)
        select id, "userId", "accessHash", "refreshHash",
          "accessExpiresAt"::timestamptz, "refreshExpiresAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "userId" text, "accessHash" text, "refreshHash" text,
          "accessExpiresAt" text, "refreshExpiresAt" text)
      ''');
      await _insert(tx, snapshot['reviews'] as List<dynamic>, '''
        insert into scenora.reviews
          (id, user_id, movie_id, rating, text, contains_spoiler, image_urls,
           created_at, updated_at)
        select id, "userId", "movieId", rating, text, "containsSpoiler",
          "imageUrls", "createdAt"::timestamptz, "updatedAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "userId" text, "movieId" text, rating integer, text text,
          "containsSpoiler" boolean, "imageUrls" jsonb, "createdAt" text,
          "updatedAt" text)
      ''');
      await _insert(tx, snapshot['reviewRatings'] as List<dynamic>, '''
        insert into scenora.review_ratings
          (id, review_id, user_id, rating, created_at, updated_at)
        select id, "reviewId", "userId", rating, "createdAt"::timestamptz,
          "updatedAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "reviewId" text, "userId" text, rating integer,
          "createdAt" text, "updatedAt" text)
      ''');
      await _insert(tx, snapshot['likes'] as List<dynamic>, '''
        insert into scenora.likes (id, review_id, user_id, created_at)
        select id, "reviewId", "userId", "createdAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "reviewId" text, "userId" text, "createdAt" text)
      ''');
      await _insert(tx, snapshot['comments'] as List<dynamic>, '''
        insert into scenora.comments
          (id, review_id, user_id, text, parent_comment_id, created_at, updated_at)
        select id, "reviewId", "userId", text, "parentCommentId",
          "createdAt"::timestamptz, "updatedAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "reviewId" text, "userId" text, text text,
          "parentCommentId" text, "createdAt" text, "updatedAt" text)
      ''');
      await _insert(tx, snapshot['follows'] as List<dynamic>, '''
        insert into scenora.follows
          (id, follower_id, following_id, created_at)
        select id, "followerId", "followingId", "createdAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "followerId" text, "followingId" text, "createdAt" text)
      ''');
      await _insert(tx, snapshot['watchlist'] as List<dynamic>, '''
        insert into scenora.watchlist (id, user_id, movie_id, created_at)
        select id, "userId", "movieId", "createdAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "userId" text, "movieId" text, "createdAt" text)
      ''');
      await _insert(tx, snapshot['messages'] as List<dynamic>, '''
        insert into scenora.messages (id, user_id, text, created_at)
        select id, "userId", text, "createdAt"::timestamptz
        from jsonb_to_recordset(cast(@rows as jsonb)) as x(
          id text, "userId" text, text text, "createdAt" text)
      ''');
    });
  }

  Future<void> _insert(TxSession tx, List<dynamic> rows, String sql) async {
    if (rows.isEmpty) return;
    await tx.execute(Sql.named(sql), parameters: {'rows': jsonEncode(rows)});
  }
}
