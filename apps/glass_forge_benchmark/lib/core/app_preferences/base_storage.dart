import 'package:glass_forge_benchmark/utils/helpers/logger_helper.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

abstract class BaseStorage {
  late Box<dynamic> _box;

  Future<void> init(String boxName) async {
    try {
      _box = await Hive.openBox(boxName);
    } catch (e, s) {
      AppLogger.error('Hive box "$boxName" open failed; recreating', e, s);
      await Hive.deleteBoxFromDisk(boxName);
      _box = await Hive.openBox(boxName);
    }
  }

  Future<void> remove(String key) => _box.delete(key);

  Future<void> removeAll() => _box.clear();

  T? retrieve<T>(String key) => _box.get(key) as T?;

  Future<void> store<T>(String key, T value) => _box.put(key, value);

  bool hasData(String key) => _box.containsKey(key);

  List<dynamic> getAllKeys() => _box.keys.toList();
}
