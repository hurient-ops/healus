import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SyncQueueDb {
  static final SyncQueueDb _instance = SyncQueueDb._internal();
  factory SyncQueueDb() => _instance;

  Database? _db;
  final int _maxQueueSize = 50000; // 최대 5만 개의 패킷만 보관

  SyncQueueDb._internal();

  Future<void> init() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'healus_sync_queue.db');

    _db = await openDatabase(
      pathString,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE unsynced_packets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pump_id TEXT NOT NULL,
            direction TEXT NOT NULL,
            payload_hex TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS unsynced_packets');
          await db.execute('''
            CREATE TABLE unsynced_packets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pump_id TEXT NOT NULL,
              direction TEXT NOT NULL,
              payload_hex TEXT NOT NULL,
              timestamp TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  /// 새로운 패킷을 오프라인 큐에 추가
  Future<void> insertPacket(String pumpId, String direction, String payloadHex, String timestamp) async {
    final db = _db;
    if (db == null) return;

    await db.insert(
      'unsynced_packets',
      {
        'pump_id': pumpId,
        'direction': direction,
        'payload_hex': payloadHex,
        'timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 저장 후 큐 용량 초과 시 오래된 데이터 삭제 (비동기로 실행)
    _trimQueue();
  }

  /// 큐 용량이 50,000개를 넘어가면 가장 오래된 패킷(id가 작은 순)부터 삭제 (FIFO 정책)
  Future<void> _trimQueue() async {
    final db = _db;
    if (db == null) return;

    try {
      await db.execute('''
        DELETE FROM unsynced_packets 
        WHERE id NOT IN (
          SELECT id FROM unsynced_packets 
          ORDER BY id DESC 
          LIMIT $_maxQueueSize
        )
      ''');
    } catch (e) {
      print('[SyncQueueDb] Exception during queue trimming: $e');
    }
  }

  /// UNKNOWN_PID 거나 비어있는 패킷들을 실제 PID로 일괄 업데이트
  Future<void> updateUnknownPumpIds(String realPumpId) async {
    final db = _db;
    if (db == null) return;
    
    await db.update(
      'unsynced_packets',
      {'pump_id': realPumpId},
      where: 'pump_id = ? OR pump_id = ?',
      whereArgs: ['UNKNOWN_PID', ''],
    );
  }

  /// 서버로 전송할 미전송 패킷 가져오기 (가장 오래된 것부터, 최대 limit개)
  Future<List<Map<String, dynamic>>> getUnsyncedPackets({int limit = 100}) async {
    final db = _db;
    if (db == null) return [];

    return await db.query(
      'unsynced_packets',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  /// 전송이 성공적으로 완료된 패킷들을 큐에서 삭제
  Future<void> deletePackets(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = _db;
    if (db == null) return;

    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'unsynced_packets',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
