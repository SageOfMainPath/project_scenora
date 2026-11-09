import 'dart:convert';
import 'dart:io';
import 'dart:math';

abstract class ScenoraStore {
  Map<String, dynamic> get data;

  List<Map<String, dynamic>> table(String name);

  String id(String prefix);

  Future<void> save();
}

class JsonStore implements ScenoraStore {
  JsonStore(this.path) {
    _file = File(path);
    _file.parent.createSync(recursive: true);
    if (_file.existsSync()) {
      data = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      _migrate();
    } else {
      data = _initialData();
      _saveSync();
    }
  }

  final String path;
  late final File _file;
  @override
  late Map<String, dynamic> data;
  final Random _random = Random.secure();

  void _migrate() {
    for (final name in [
      'users',
      'sessions',
      'reviews',
      'reviewRatings',
      'likes',
      'comments',
      'follows',
      'movies',
      'watchlist',
      'messages',
    ]) {
      data.putIfAbsent(name, () => <Map<String, dynamic>>[]);
    }
    _saveSync();
  }

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
  Future<void> save() async => _saveSync();

  void _saveSync() {
    final temporary = File('$path.tmp');
    temporary.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    if (_file.existsSync()) _file.deleteSync();
    temporary.renameSync(path);
  }

  Map<String, dynamic> _initialData() => {
    'users': <Map<String, dynamic>>[],
    'sessions': <Map<String, dynamic>>[],
    'reviews': <Map<String, dynamic>>[],
    'reviewRatings': <Map<String, dynamic>>[],
    'likes': <Map<String, dynamic>>[],
    'comments': <Map<String, dynamic>>[],
    'follows': <Map<String, dynamic>>[],
    'watchlist': <Map<String, dynamic>>[],
    'messages': <Map<String, dynamic>>[],
    'movies': <Map<String, dynamic>>[
      {
        'id': '693134',
        'title': 'Dune: Part Two',
        'year': 2024,
        'genre': 'Sci-Fi, Adventure',
        'overview':
            'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.',
        'tmdbRating': 8.5,
        'posterPath': null,
      },
      {
        'id': '872585',
        'title': 'Oppenheimer',
        'year': 2023,
        'genre': 'Biography, Drama',
        'overview':
            'The story of J. Robert Oppenheimer and his role in the development of the atomic bomb.',
        'tmdbRating': 8.6,
        'posterPath': null,
      },
      {
        'id': '666277',
        'title': 'Past Lives',
        'year': 2023,
        'genre': 'Drama, Romance',
        'overview':
            'Two childhood friends reunite in New York and confront destiny, love, and the choices that shape a life.',
        'tmdbRating': 7.8,
        'posterPath': null,
      },
      {
        'id': '414906',
        'title': 'The Batman',
        'year': 2022,
        'genre': 'Crime, Mystery',
        'overview':
            'Batman ventures into Gotham City’s underworld as a killer leaves behind a trail of cryptic clues.',
        'tmdbRating': 7.8,
        'posterPath': null,
      },
      {
        'id': '569094',
        'title': 'Spider-Verse',
        'year': 2023,
        'genre': 'Animation, Action',
        'overview':
            'Miles Morales catapults across the Multiverse and meets a team of Spider-People.',
        'tmdbRating': 8.6,
        'posterPath': null,
      },
      {
        'id': '136315',
        'title': 'The Bear',
        'year': 2024,
        'genre': 'Drama, Comedy',
        'overview':
            'A young chef returns home to Chicago to run his family sandwich shop.',
        'tmdbRating': 8.6,
        'posterPath': null,
      },
    ],
  };
}
