import 'package:bah_francais/core/database/app_database.dart';
import 'package:bah_francais/features/drills/data/drill_tables.drift.dart';
import 'package:bah_francais/features/drills/domain/drill_type.dart';
import 'package:drift/drift.dart';

/// The sessions. A session row is written with its first answer, so a
/// session with none leaves no row; `CardsDao` keeps the counts and end up
/// to date with each answer.
class SessionsDao {
  SessionsDao(this._db);

  final AppDatabase _db;

  /// Starts a session of [drill] (null for a mixed session) at [at], and
  /// returns its id.
  Future<int> start({required DrillType? drill, required DateTime at}) => _db
      .into(_db.sessions)
      .insert(
        SessionsCompanion.insert(drillType: drill, startTime: at, endTime: at),
      );

  Future<SessionRow?> session(int id) => (_db.select(
    _db.sessions,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Past sessions, newest first.
  Stream<List<SessionRow>> watchSessions() =>
      (_db.select(_db.sessions)..orderBy([
            (s) => OrderingTerm.desc(s.startTime),
            (s) => OrderingTerm.desc(s.id),
          ]))
          .watch();
}
