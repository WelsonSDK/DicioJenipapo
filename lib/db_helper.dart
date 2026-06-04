import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dicionario.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Dicionario (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            portugues TEXT,
            traducao TEXT
          )
        ''');
      },
    );

    return _db!;
  }

  static Future<List<Map<String, dynamic>>> buscarPalavras(String texto) async {
    final db = await getDatabase();
    return await db.query(
      'Dicionario',
      where: 'portugues LIKE ?',
      whereArgs: ['%$texto%'],
      limit: 200,
    );
  }

  static Future<List<Map<String, dynamic>>> buscarPorLetra(String letra) async {
    final db = await getDatabase();
    return await db.query(
      'Dicionario',
      where: 'portugues LIKE ?',
      whereArgs: ['$letra%'],
    );
  }

  static Future<void> inserirPalavra(String portugues, String traducao) async {
    final db = await getDatabase();
    await db.insert(
      'Dicionario',
      {'portugues': portugues, 'traducao': traducao},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}