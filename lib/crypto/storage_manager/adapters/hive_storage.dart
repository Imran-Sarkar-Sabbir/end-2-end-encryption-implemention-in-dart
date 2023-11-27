import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:hive/hive.dart';

class HiveKeyStore implements KeyStorage {
  final String path;
  HiveKeyStore({required this.path});

  @override
  Future<void> init() async {
    Hive.init("hive_storage");
  }

  @override
  Future retrieve({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    final data = box.get(key);
    return data;
  }

  @override
  Future<Map> retriveAll({
    required String key,
    String? partition,
  }) async {
    final box = await Hive.openBox(partition ?? key);
    final r = Map.fromIterables(box.keys, box.values);
    return r;
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
    box.delete(key);
  }

  @override
  Future<bool> hasData({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    final r = box.isNotEmpty;
    return r;
  }
}
