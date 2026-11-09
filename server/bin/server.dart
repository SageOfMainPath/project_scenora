import 'dart:io';

import 'package:scenora_backend/api.dart';
import 'package:scenora_backend/postgres_store.dart';
import 'package:scenora_backend/security.dart';
import 'package:scenora_backend/store.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final fileEnvironment = _loadEnvironmentFile('.env');
  String? setting(String name) {
    final processValue = Platform.environment[name]?.trim();
    if (processValue != null && processValue.isNotEmpty) return processValue;
    final fileValue = fileEnvironment[name]?.trim();
    return fileValue == null || fileValue.isEmpty ? null : fileValue;
  }

  final port = int.tryParse(setting('PORT') ?? '') ?? 8080;
  final databaseUrl = setting('SUPABASE_DATABASE_URL');
  final ScenoraStore store = databaseUrl == null
      ? JsonStore('data/db.json')
      : await PostgresStore.open(databaseUrl);
  final api = ScenoraApi(
    store: store,
    security: SecurityService(pepper: setting('SCENORA_TOKEN_PEPPER')),
    tmdbApiKey: setting('TMDB_API_KEY'),
    tmdbReadAccessToken: setting('TMDB_READ_ACCESS_TOKEN'),
  );
  final server = await shelf_io.serve(
    api.handler,
    InternetAddress.anyIPv4,
    port,
  );
  server.autoCompress = true;
  stdout.writeln(
    'SCENORA API running on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('Health check: http://localhost:$port/health');
  stdout.writeln(
    setting('TMDB_API_KEY') != null || setting('TMDB_READ_ACCESS_TOKEN') != null
        ? 'TMDB integration: enabled'
        : 'TMDB integration: demo mode (.env key not found)',
  );
  stdout.writeln(
    databaseUrl == null
        ? 'Database: local JSON (SUPABASE_DATABASE_URL is not set)'
        : 'Database: Supabase PostgreSQL',
  );
}

Map<String, String> _loadEnvironmentFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};

  final values = <String, String>{};
  for (var line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trim();
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final name = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[name] = value;
  }
  return values;
}
