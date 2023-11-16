import 'package:end2end/managers/key_manager.dart';
import 'package:end2end/storage/key_storage.dart';
import 'package:hive/hive.dart';

Future<void> installE2EE() async {
  await myKeyManager.init();
  await myKeyManager.install();

  // final box = await Hive.openBox('testBox');

  // print(box.get("hello"));
}
