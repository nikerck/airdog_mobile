import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_service.dart';

class WishRepository {
  WishRepository(this._db, {this.sync});

  final AppDatabase _db;
  final SyncService? sync;

  bool get online => sync != null;

  Stream<List<Wish>> watch({String spaceId = Spaces.shared}) {
    final query = _db.select(_db.wishes)
      ..where((t) => t.spaceId.equals(spaceId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    return query.watch();
  }

  Stream<List<WishSaving>> watchSavings() {
    final query = _db.select(_db.wishSavings)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.savedAt, mode: OrderingMode.desc)]);
    return query.watch();
  }

  Future<void> add({
    required String title,
    required int price,
    int priority = 1,
    String link = '',
    String note = '',
    String spaceId = Spaces.shared,
  }) async {
    if (sync != null) {
      await sync!.createWish(
        title: title,
        price: price,
        priority: priority,
        link: link,
        note: note,
        spaceId: spaceId,
      );
      return;
    }
    final now = DateTime.now();
    await _db.into(_db.wishes).insert(
          WishesCompanion.insert(
            id: 'wish_${now.microsecondsSinceEpoch}',
            spaceId: spaceId,
            title: title,
            price: Value(price),
            priority: Value(priority),
            link: Value(link),
            note: Value(note),
            createdBy: Value(Members.me),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> update(
    Wish wish, {
    required String title,
    required int price,
    required int priority,
    String link = '',
    String note = '',
  }) async {
    if (sync != null) {
      await sync!.updateWish(wish,
          title: title, price: price, priority: priority, link: link, note: note);
      return;
    }
    await (_db.update(_db.wishes)..where((t) => t.id.equals(wish.id))).write(
      WishesCompanion(
        title: Value(title),
        price: Value(price),
        priority: Value(priority),
        link: Value(link),
        note: Value(note),
        updatedAt: Value(DateTime.now()),
        rev: Value(wish.rev + 1),
      ),
    );
  }

  Future<void> remove(Wish wish) async {
    if (sync != null) {
      await sync!.deleteWish(wish);
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.wishes)..where((t) => t.id.equals(wish.id))).write(
      WishesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(wish.rev + 1),
      ),
    );
  }

  Future<void> addSaving(
    Wish wish, {
    required int amount,
    String memberId = Members.me,
  }) async {
    if (sync != null) {
      await sync!.addSaving(wish, amount: amount, memberId: memberId);
      return;
    }
    final now = DateTime.now();
    await _db.into(_db.wishSavings).insert(
          WishSavingsCompanion.insert(
            id: 'save_${now.microsecondsSinceEpoch}',
            wishId: wish.id,
            memberId: memberId,
            amount: amount,
            savedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> removeSaving(Wish wish, WishSaving saving) async {
    if (sync != null) {
      await sync!.deleteSaving(wish, saving);
      return;
    }
    final now = DateTime.now();
    await (_db.update(_db.wishSavings)..where((t) => t.id.equals(saving.id))).write(
      WishSavingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        rev: Value(saving.rev + 1),
      ),
    );
  }
}
