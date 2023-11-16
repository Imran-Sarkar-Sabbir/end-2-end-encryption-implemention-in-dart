import 'package:end2end/storage/key_storage_adapter.dart';
import 'package:hive/hive.dart';

class HiveAdapter implements KeyStorageAdapter {
  @override
  Future<void> init() async {
    Hive.init("hive_storage");
  }

  @override
  Future<dynamic> retrive({required String key, String? partition}) async {
    final box = await Hive.openBox(partition ?? key);
    return box.get(key);
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
}
