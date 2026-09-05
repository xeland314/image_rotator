import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/history_entry.dart';

class HistoryService {
  static const String boxName = 'rotador_history';
  static const int maxEntries = 100;
  static const _uuid = Uuid();

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
    }
  }

  static bool get isReady => Hive.isBoxOpen(boxName);

  static Box<String> get _box => Hive.box<String>(boxName);

  static Future<String> save(HistoryEntry entry) async {
    final id = entry.id.isEmpty ? _uuid.v4() : entry.id;
    final createdAt = entry.createdAt == 0 ? DateTime.now().millisecondsSinceEpoch : entry.createdAt;
    final toSave = HistoryEntry(
      id: id,
      createdAt: createdAt,
      name: entry.name,
      imageOriginal: entry.imageOriginal,
      imageResult: entry.imageResult,
      operations: entry.operations,
      totalAngle: entry.totalAngle,
      normalizedAngle: entry.normalizedAngle,
      formula: entry.formula,
      showTrace: entry.showTrace,
      includeDirect: entry.includeDirect,
    );
    await _box.put(id, jsonEncode(toSave.toJson()));
    // prune oldest
    final all = await getAll();
    if (all.length > maxEntries) {
      final sorted = [...all]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final toDelete = sorted.take(all.length - maxEntries);
      for (final e in toDelete) {
        await _box.delete(e.id);
      }
    }
    return id;
  }

  static Future<List<HistoryEntry>> getAll() async {
    if (!Hive.isBoxOpen(boxName)) return [];
    final values = _box.values;
    final list = values.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return HistoryEntry.fromJson(map);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> delete(String id) async => _box.delete(id);

  static Future<void> clear() async => _box.clear();

  static Future<HistoryEntry?> getById(String id) async {
    final s = _box.get(id);
    if (s == null) return null;
    return HistoryEntry.fromJson(jsonDecode(s));
  }
}
