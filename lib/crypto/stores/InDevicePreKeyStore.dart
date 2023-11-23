import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class InDevicePreKeyStore extends PreKeyStore {
  static InDevicePreKeyStore? _instance;
  static const int MIN_PRE_KEY_COUNT = 50;
  static const int GEN_PRE_KEY_PER_BATCH = 110;

  static const _preKeyPortion = "pre_key";
  static const _preKeyInfo = "key_info";
  static const _preKeyIndex = "key_index";
  static const _preKeyCount = "key_count";

  final KeyStorage store;

  InDevicePreKeyStore(this.store) {
    if (_instance != null) {
      throw Exception("InDevicePreKeyStore already initialized");
    }
    _instance = this;
  }

  static Future<InDevicePreKeyStore?> retrive(KeyStorage store) async {
    if (_instance != null) return _instance;
    final hasPreKey = await store.hasData(key: _preKeyPortion);
    if (hasPreKey) {
      return InDevicePreKeyStore(store);
    }
    return null;
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    final prekeyData = await store.retrieve(
      key: preKeyId.toString(),
      partition: _preKeyPortion,
    );
    return prekeyData != null;
  }

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final prekeyData = await store.retrieve(
      key: preKeyId.toString(),
      partition: _preKeyPortion,
    );

    if (prekeyData == null) {
      throw InvalidKeyIdException('No such prekeyrecord! - $preKeyId');
    }
    return PreKeyRecord.fromBuffer(prekeyData!);
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    await store.remove(key: preKeyId.toString(), partition: _preKeyPortion);
    int preKeyCount = await getPrekeyCount();
    await savePrekeyCount(preKeyCount - 1);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    await store.store(
      key: preKeyId.toString(),
      value: record.serialize(),
      partition: _preKeyPortion,
    );
    int preKeyCount = await getPrekeyCount();
    await savePrekeyCount(preKeyCount + 1);
  }

  Future<void> savePrekeyCount(int count) async {
    await store.store(
      key: _preKeyCount,
      value: count,
      partition: _preKeyInfo,
    );
  }

  Future<int> getPrekeyCount() async {
    int? count = await store.retrieve(
      key: _preKeyCount,
      partition: _preKeyInfo,
    );
    return count ?? 0;
  }

  Future<void> storePreKeyIndex(int preKey) async {
    await store.store(
      key: _preKeyIndex,
      value: preKey,
      partition: _preKeyInfo,
    );
  }

  Future<int> getPreKeyIndex() async {
    int? preKeyIndex = await store.retrieve(
      key: _preKeyIndex,
      partition: _preKeyInfo,
    );
    return preKeyIndex ?? 0;
  }

  Future<bool> shouldGenPreKey() async {
    int count = await getPrekeyCount();
    return count < MIN_PRE_KEY_COUNT;
  }
}
