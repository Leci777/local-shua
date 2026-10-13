import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/download_task.dart';

/// 本地 SQLite：下载索引 + 本地进度镜像两张表（架构 §3.4）。
/// 播放历史/收藏/进度服务端是唯一事实源；本地镜像只服务「已下载视频的离线播放」。
class DownloadDb {
  DownloadDb._();

  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'pcvideo_local.db'),
      version: 1,
      onConfigure: (db) async {
        // 外键默认不开，这里显式打开（删视频记录时级联删本地进度）
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            video_id INTEGER PRIMARY KEY,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            total_bytes INTEGER NOT NULL DEFAULT 0,
            received_bytes INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            error_text TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE local_progress (
            video_id INTEGER PRIMARY KEY,
            position_sec REAL NOT NULL DEFAULT 0,
            duration_sec REAL NOT NULL DEFAULT 0,
            completed INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ===== downloads =====

  static Future<List<DownloadTask>> allDownloads() async {
    final db = await instance;
    final rows = await db.query('downloads', orderBy: 'rowid DESC');
    return rows.map(DownloadTask.fromRow).toList();
  }

  static Future<DownloadTask?> findDownload(int videoId) async {
    final db = await instance;
    final rows = await db.query('downloads', where: 'video_id = ?', whereArgs: [videoId]);
    return rows.isEmpty ? null : DownloadTask.fromRow(rows.first);
  }

  static Future<void> upsertDownload(DownloadTask task) async {
    final db = await instance;
    await db.insert(
      'downloads',
      task.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeDownload(int videoId) async {
    final db = await instance;
    await db.delete('downloads', where: 'video_id = ?', whereArgs: [videoId]);
  }

  /// 下载中+已完成占用的字节总和（设置页显示缓存大小）
  static Future<int> totalBytes() async {
    final db = await instance;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(received_bytes), 0) AS total FROM downloads',
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  // ===== local_progress =====

  static Future<({double positionSec, double durationSec, bool completed})?> localProgress(
      int videoId) async {
    final db = await instance;
    final rows = await db.query('local_progress', where: 'video_id = ?', whereArgs: [videoId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      positionSec: (row['position_sec'] as num).toDouble(),
      durationSec: (row['duration_sec'] as num).toDouble(),
      completed: (row['completed'] as int) == 1,
    );
  }

  static Future<void> saveLocalProgress({
    required int videoId,
    required double positionSec,
    required double durationSec,
    required bool completed,
  }) async {
    final db = await instance;
    await db.insert(
      'local_progress',
      {
        'video_id': videoId,
        'position_sec': positionSec,
        'duration_sec': durationSec,
        'completed': completed ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeLocalProgress(int videoId) async {
    final db = await instance;
    await db.delete('local_progress', where: 'video_id = ?', whereArgs: [videoId]);
  }
}
