import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 펌프 이력 로그 데이터 모델
class PumpLogModel {
  final int? id;
  final int month;
  final int day;
  final double baseTotal;
  final double eatTotal;
  final double morningTotal;
  final double afternoonTotal;
  final double eveningTotal;
  final double appendTotal;
  final String createdAt;

  PumpLogModel({
    this.id,
    required this.month,
    required this.day,
    required this.baseTotal,
    required this.eatTotal,
    required this.morningTotal,
    required this.afternoonTotal,
    required this.eveningTotal,
    required this.appendTotal,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'day': day,
      'base_total': baseTotal,
      'eat_total': eatTotal,
      'morning_total': morningTotal,
      'afternoon_total': afternoonTotal,
      'evening_total': eveningTotal,
      'append_total': appendTotal,
      'created_at': createdAt,
    };
  }

  factory PumpLogModel.fromMap(Map<String, dynamic> map) {
    return PumpLogModel(
      id: map['id'] as int?,
      month: map['month'] as int,
      day: map['day'] as int,
      baseTotal: map['base_total'] as double,
      eatTotal: map['eat_total'] as double,
      morningTotal: map['morning_total'] as double,
      afternoonTotal: map['afternoon_total'] as double,
      eveningTotal: map['evening_total'] as double,
      appendTotal: map['append_total'] as double,
      createdAt: map['created_at'] as String,
    );
  }
}

/// 데이터베이스 접근을 추상화한 인터페이스 (단위 테스트 지원 및 SQLite 연동)
abstract class PumpDatabase {
  Future<void> init();
  Future<void> insertLog(PumpLogModel log);
  Future<void> insertLogsBulk(List<PumpLogModel> logs);
  Future<List<PumpLogModel>> getAllLogs();
  Future<void> clearLogs();
  Future<void> keepOnlyLast180Days();
}

/// 실제 기기 구동용 SQLite DB 구현체
class SqflitePumpDatabase implements PumpDatabase {
  Database? _db;

  @override
  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'healus_pump.db');

    _db = await openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pump_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month INTEGER,
            day INTEGER,
            base_total REAL,
            eat_total REAL,
            morning_total REAL,
            afternoon_total REAL,
            evening_total REAL,
            append_total REAL,
            created_at TEXT,
            UNIQUE(month, day) ON CONFLICT REPLACE
          )
        ''');
      },
    );
  }

  @override
  Future<void> insertLog(PumpLogModel log) async {
    final db = _db;
    if (db == null) throw StateError("데이터베이스가 초기화되지 않았습니다.");
    await db.insert(
      'pump_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> insertLogsBulk(List<PumpLogModel> logs) async {
    final db = _db;
    if (db == null) throw StateError("데이터베이스가 초기화되지 않았습니다.");
    
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final log in logs) {
        batch.insert('pump_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<PumpLogModel>> getAllLogs() async {
    final db = _db;
    if (db == null) throw StateError("데이터베이스가 초기화되지 않았습니다.");
    
    final List<Map<String, dynamic>> maps = await db.query('pump_logs', orderBy: 'id DESC');
    return maps.map((m) => PumpLogModel.fromMap(m)).toList();
  }

  @override
  Future<void> clearLogs() async {
    final db = _db;
    if (db == null) throw StateError("데이터베이스가 초기화되지 않았습니다.");
    await db.delete('pump_logs');
  }

  @override
  Future<void> keepOnlyLast180Days() async {
    final db = _db;
    if (db == null) throw StateError("데이터베이스가 초기화되지 않았습니다.");
    await db.execute('''
      DELETE FROM pump_logs 
      WHERE id NOT IN (
        SELECT id FROM pump_logs 
        WHERE (month * 100 + day) IN (
          SELECT (month * 100 + day) as date_val 
          FROM pump_logs 
          GROUP BY date_val 
          ORDER BY date_val DESC 
          LIMIT 180
        )
      )
    ''');
  }
}
