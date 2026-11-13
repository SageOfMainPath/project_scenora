import 'dart:io';

import 'package:postgres/postgres.dart';

const _tables = [
  'users',
  'sessions',
  'movies',
  'reviews',
  'review_ratings',
  'likes',
  'comments',
  'follows',
  'watchlist',
  'messages',
];

Future<void> main(List<String> arguments) async {
  final environment = _loadEnvironment('.env');
  final databaseUrl =
      Platform.environment['SUPABASE_DATABASE_URL']?.trim() ??
      environment['SUPABASE_DATABASE_URL']?.trim();
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('SUPABASE_DATABASE_URL is not configured.');
    exitCode = 2;
    return;
  }
  final connection = await Connection.openFromUrl(databaseUrl);
  try {
    if (arguments.contains('--status')) {
      await _printCounts(connection);
      return;
    }
    if (!arguments.contains('--reset') ||
        !arguments.contains('--confirm=RESET_SCENORA')) {
      stdout.writeln(
        'Use --status, or --reset --confirm=RESET_SCENORA to erase accounts and community data.',
      );
      return;
    }
    stdout.writeln('Before reset:');
    await _printCounts(connection);
    await connection.runTx((tx) async {
      await tx.execute('''
        truncate table
          scenora.comments,
          scenora.review_ratings,
          scenora.likes,
          scenora.sessions,
          scenora.messages,
          scenora.watchlist,
          scenora.follows,
          scenora.reviews,
          scenora.users
        restart identity cascade
      ''');
      // Supabase Auth users are separate from SCENORA's custom user table.
      // Clear them as part of an explicitly confirmed full demo reset.
      await tx.execute('delete from auth.users');
    });
    stdout.writeln('After reset:');
    await _printCounts(connection);
  } finally {
    await connection.close();
  }
}

Future<void> _printCounts(Connection connection) async {
  for (final table in _tables) {
    final result = await connection.execute(
      'select count(*) from scenora.$table',
    );
    stdout.writeln('$table: ${result.first.first}');
  }
  final authUsers = await connection.execute('select count(*) from auth.users');
  stdout.writeln('auth.users: ${authUsers.first.first}');
}

Map<String, String> _loadEnvironment(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final result = <String, String>{};
  for (var line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}
