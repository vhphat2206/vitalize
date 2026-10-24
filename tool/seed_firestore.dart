// Puts the exercise catalog from assets/data (exercises, muscles, equipment, routines, moves) into
// Cloud Firestore, where the app reads it (lib/data/catalog.dart):
//
//   firebase login                       once, as an owner of the Firebase project
//   dart run tool/seed_firestore.dart    again whenever the JSON changes
//
// Firestore ends up matching the JSON: every item is written whole, items no longer in the JSON
// are deleted. It writes through the Firestore REST API with the Firebase CLI's sign-in, which
// firestore.rules do not apply to; the app itself can only read the catalog.
import 'dart:convert';
import 'dart:io';

const _data = 'assets/data';

Future<void> main(List<String> args) async {
  final project = args.isNotEmpty ? args.first : _defaultProject();
  final db = _Firestore(project, await _accessToken());

  dynamic read(String name) => jsonDecode(File('$_data/$name.json').readAsStringSync());
  final docs = <String, Map<String, dynamic>>{};
  for (final name in ['exercises', 'routines', 'moves']) {
    for (final (i, item) in (read(name) as List).indexed) {
      docs['$name/${item['id']}'] = {...item as Map<String, dynamic>, 'order': i};
    }
  }
  final muscles = read('muscles') as Map<String, dynamic>;
  for (final (i, m) in (muscles['muscles'] as List).indexed) {
    docs['muscles/${m['id']}'] = {...m as Map<String, dynamic>, 'order': i};
  }
  docs['meta/muscleOrder'] = muscles['order'] as Map<String, dynamic>;
  docs['meta/equipment'] = read('equipment') as Map<String, dynamic>;

  final stale = [
    for (final collection in ['exercises', 'muscles', 'routines', 'moves', 'meta'])
      for (final path in await db.list(collection))
        if (!docs.containsKey(path)) path,
  ];
  await db.commit([
    for (final MapEntry(key: path, value: fields) in docs.entries)
      {
        'update': {'name': db.name(path), 'fields': _fields(fields)},
      },
    for (final path in stale) {'delete': db.name(path)},
  ]);
  stdout.writeln(
    'Firestore project $project: wrote ${docs.length} documents'
    '${stale.isEmpty ? '' : ', deleted ${stale.length} (${stale.join(', ')})'}.',
  );
  db.close();
}

String _defaultProject() {
  final rc = File('.firebaserc');
  if (!rc.existsSync()) _fail('No .firebaserc here: run from the project root, or pass the id.');
  return (jsonDecode(rc.readAsStringSync())['projects'] as Map)['default'] as String;
}

/// The Firebase CLI's access token. Running a CLI command first makes it refresh the token
/// (it lasts an hour) and save it where the CLI keeps its sign-in.
Future<String> _accessToken() async {
  final cli = await Process.run('firebase', ['projects:list', '--json'], runInShell: true);
  if (cli.exitCode != 0) _fail('Firebase CLI not signed in: run `firebase login` first.');
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final store = File('$home/.config/configstore/firebase-tools.json');
  final tokens = (jsonDecode(store.readAsStringSync()) as Map)['tokens'] as Map?;
  final expires = tokens?['expires_at'] as int? ?? 0;
  if (tokens == null || expires < DateTime.now().millisecondsSinceEpoch + 60000) {
    _fail('No fresh Firebase CLI token in ${store.path}: run `firebase login --reauth`.');
  }
  return tokens['access_token'] as String;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

/// Firestore's typed values, from JSON.
Map<String, Object?> _fields(Map<String, dynamic> map) => {
  for (final MapEntry(:key, :value) in map.entries) key: _value(value),
};

Map<String, Object?> _value(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  List<dynamic> l => {
    'arrayValue': {'values': l.map(_value).toList()},
  },
  Map<String, dynamic> m => {
    'mapValue': {'fields': _fields(m)},
  },
  _ => throw ArgumentError('No Firestore value for $v'),
};

class _Firestore {
  _Firestore(this.project, this.token);

  final String project;
  final String token;
  final _http = HttpClient();

  String get _root => 'projects/$project/databases/(default)/documents';

  String name(String path) => '$_root/$path';

  /// The paths of the documents in [collection].
  Future<List<String>> list(String collection) async {
    final paths = <String>[];
    String? page;
    do {
      final j = await _call(
        'GET',
        '$_root/$collection',
        query: {'pageSize': '300', 'mask.fieldPaths': 'order', 'pageToken': ?page},
      );
      for (final d in j['documents'] as List? ?? const []) {
        paths.add(((d as Map)['name'] as String).substring(_root.length + 1));
      }
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return paths;
  }

  void close() => _http.close();

  /// Applies [writes] atomically, 500 at a time (Firestore's limit per commit).
  Future<void> commit(List<Map<String, Object?>> writes) async {
    for (var i = 0; i < writes.length; i += 500) {
      await _call('POST', '$_root:commit', body: {'writes': writes.skip(i).take(500).toList()});
    }
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.https('firestore.googleapis.com', '/v1/$path', query);
    final request = await _http.openUrl(method, uri)
      ..headers.set('authorization', 'Bearer $token')
      // Bill the project being written to, not the CLI's own sign-in client.
      ..headers.set('x-goog-user-project', project)
      ..headers.contentType = ContentType.json;
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) _fail('Firestore said ${response.statusCode}: $text');
    return text.isEmpty ? const {} : jsonDecode(text) as Map<String, dynamic>;
  }
}
