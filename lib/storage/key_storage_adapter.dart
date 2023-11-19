abstract class KeyStorageAdapter {
  Future<void> init();

  Future<void> store({
    required String key,
    required dynamic value,
    String? partition,
  });

  Future<dynamic> retrive({required String key, String? partition});

  Future<Map> retriveAll({
    required String key,
    String? partition,
  });
}
