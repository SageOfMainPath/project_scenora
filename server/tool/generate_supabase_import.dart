import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final input = arguments.isEmpty ? 'data/db.json' : arguments.first;
  final output = arguments.length < 2
      ? 'data/supabase_import.generated.sql'
      : arguments[1];
  final data =
      jsonDecode(File(input).readAsStringSync()) as Map<String, dynamic>;
  final sql = StringBuffer('begin;\n');

  writeTable(sql, data, 'users', [
    field('id'),
    field('username'),
    field('email'),
    field('displayName', 'display_name'),
    field('bio'),
    field('location'),
    field('avatarUrl', 'avatar_url'),
    field('coverUrl', 'cover_url'),
    field('passwordSalt', 'password_salt'),
    field('passwordHash', 'password_hash'),
    field('accountStatus', 'account_status'),
    field('createdAt', 'created_at'),
    field('updatedAt', 'updated_at'),
  ]);
  writeTable(sql, data, 'movies', [
    field('id'),
    field('title'),
    field('year'),
    field('genre'),
    field('overview'),
    field('tmdbRating', 'tmdb_rating'),
    field('posterPath', 'poster_path'),
    field('backdropPath', 'backdrop_path'),
  ]);
  writeTable(sql, data, 'sessions', [
    field('id'),
    field('userId', 'user_id'),
    field('accessHash', 'access_hash'),
    field('refreshHash', 'refresh_hash'),
    field('accessExpiresAt', 'access_expires_at'),
    field('refreshExpiresAt', 'refresh_expires_at'),
  ]);
  writeTable(sql, data, 'reviews', [
    field('id'),
    field('userId', 'user_id'),
    field('movieId', 'movie_id'),
    field('rating'),
    field('text'),
    field('containsSpoiler', 'contains_spoiler'),
    field('imageUrls', 'image_urls', true),
    field('createdAt', 'created_at'),
    field('updatedAt', 'updated_at'),
  ]);
  writeTable(sql, data, 'reviewRatings', [
    field('id'),
    field('reviewId', 'review_id'),
    field('userId', 'user_id'),
    field('rating'),
    field('createdAt', 'created_at'),
    field('updatedAt', 'updated_at'),
  ], databaseTable: 'review_ratings');
  writeTable(sql, data, 'likes', [
    field('id'),
    field('reviewId', 'review_id'),
    field('userId', 'user_id'),
    field('createdAt', 'created_at'),
  ]);
  writeTable(sql, data, 'comments', [
    field('id'),
    field('reviewId', 'review_id'),
    field('userId', 'user_id'),
    field('text'),
    field('parentCommentId', 'parent_comment_id'),
    field('createdAt', 'created_at'),
    field('updatedAt', 'updated_at'),
  ]);
  writeTable(sql, data, 'follows', [
    field('id'),
    field('followerId', 'follower_id'),
    field('followingId', 'following_id'),
    field('createdAt', 'created_at'),
  ]);
  writeTable(sql, data, 'watchlist', [
    field('id'),
    field('userId', 'user_id'),
    field('movieId', 'movie_id'),
    field('createdAt', 'created_at'),
  ]);
  writeTable(sql, data, 'messages', [
    field('id'),
    field('userId', 'user_id'),
    field('text'),
    field('createdAt', 'created_at'),
  ]);

  sql.writeln('commit;');
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(sql.toString());
}

({String jsonKey, String column, bool json}) field(
  String jsonKey, [
  String? column,
  bool json = false,
]) => (jsonKey: jsonKey, column: column ?? jsonKey, json: json);

void writeTable(
  StringBuffer sql,
  Map<String, dynamic> data,
  String table,
  List<({String jsonKey, String column, bool json})> fields, {
  String? databaseTable,
}) {
  final rows = (data[table] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();
  if (rows.isEmpty) return;
  final columns = fields.map((item) => item.column).join(', ');
  sql.writeln(
    'insert into scenora.${databaseTable ?? table} ($columns) values',
  );
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final values = fields
        .map((item) {
          final value = row[item.jsonKey];
          return item.json
              ? '${quote(jsonEncode(value ?? const []))}::jsonb'
              : quote(value);
        })
        .join(', ');
    sql.write('  ($values)');
    sql.writeln(index == rows.length - 1 ? '' : ',');
  }
  final updates = fields
      .where((item) => item.column != 'id')
      .map((item) => '${item.column} = excluded.${item.column}')
      .join(', ');
  sql.writeln('on conflict (id) do update set $updates;');
}

String quote(Object? value) {
  if (value == null) return 'null';
  if (value is num) return value.toString();
  if (value is bool) return value ? 'true' : 'false';
  return "'${value.toString().replaceAll("'", "''")}'";
}
