import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../models/tracking_model.dart';

class TrackingDatabaseService {
  static final TrackingDatabaseService _instance = TrackingDatabaseService._internal();
  factory TrackingDatabaseService() => _instance;
  TrackingDatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on the web');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kwandwe_tracking.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks(
        id TEXT PRIMARY KEY,
        name TEXT,
        activity_type TEXT,
        start_time INTEGER,
        end_time INTEGER,
        distance_meters REAL,
        duration_seconds INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE track_points(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_id TEXT,
        latitude REAL,
        longitude REAL,
        altitude REAL,
        speed REAL,
        timestamp INTEGER,
        FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
      )
    ''');
    
    // Index to speed up querying points for a specific track
    await db.execute('CREATE INDEX idx_track_points_track_id ON track_points (track_id)');
  }

  // --- Session Methods ---

  Future<void> insertTrackSession(TrackSession session) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'tracks',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTrackSession(TrackSession session) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      'tracks',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> deleteTrackSession(String id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TrackSession>> getAllTrackSessions() async {
    if (kIsWeb) return [];
    final db = await database;
    final maps = await db.query('tracks', orderBy: 'start_time DESC');
    return List.generate(maps.length, (i) => TrackSession.fromMap(maps[i]));
  }

  Future<TrackSession?> getTrackSession(String id) async {
    if (kIsWeb) return null;
    final db = await database;
    final maps = await db.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TrackSession.fromMap(maps.first);
    }
    return null;
  }

  // --- Point Methods ---

  Future<void> insertTrackPoint(TrackPoint point) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'track_points',
      point.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TrackPoint>> getPointsForTrack(String trackId) async {
    if (kIsWeb) return [];
    final db = await database;
    final maps = await db.query(
      'track_points',
      where: 'track_id = ?',
      whereArgs: [trackId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => TrackPoint.fromMap(maps[i]));
  }
}
