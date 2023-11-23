abstract class KeyStorageInterface {
  Future<void> init();

  Future<void> store({
    required String key,
    required dynamic value,
    String? partition,
  });

  Future retrieve({required String key, String? partition});

  Future<Map> retriveAll({
    required String key,
    String? partition,
  });

  Future<void> remove({required String key, String? partition});

  Future<bool> hasData({required String key, String? partition});
}
