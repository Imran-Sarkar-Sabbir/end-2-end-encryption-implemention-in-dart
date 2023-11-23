import 'package:end2end/crypto/storage_manager/key_storage_interface.dart';
import 'package:hive/hive.dart';

class HiveAdapter implements KeyStorageInterface {
  @override
  Future<void> init() async {
    Hive.init("hive_storage");
  }

  @override
  Future retrieve({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    return box.get(key);
  }

  @override
  Future<Map> retriveAll({
    required String key,
    String? partition,
  }) async {
    final box = await Hive.openBox(partition ?? key);
    return Map.fromIterables(box.keys, box.values);
  }

  @override
  Future<void> store({
    required String key,
    required value,
    String? partition,
  }) async {
    final box = await Hive.openBox(partition ?? key);
    box.put(key, value);
  }

  @override
  Future<void> remove({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    return box.delete(key);
  }

  @override
  Future<bool> hasData({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    return box.isNotEmpty;
  }
}
