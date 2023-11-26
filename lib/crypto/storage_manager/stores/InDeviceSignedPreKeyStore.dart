import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class InDeviceSignedPreKeyStore extends SignedPreKeyStore {
  static InDeviceSignedPreKeyStore? _instance;
  static const _signedPreKeyPortion = "signed_pre_portion";

  final KeyStorage store;
  InDeviceSignedPreKeyStore(this.store) {
    if (_instance != null) {
      throw Exception("InDeviceSignedPreKeyStore already initialized");
    }
    _instance = this;
  }

  static Future<InDeviceSignedPreKeyStore?> retrive(KeyStorage store) async {
    if (_instance != null) return _instance;
    final hasSignedPreKey = await store.hasData(key: _signedPreKeyPortion);
    if (hasSignedPreKey) {
      return InDeviceSignedPreKeyStore(store);
    }
    return null;
  }

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final preKeyData = await store.retrieve(
      key: signedPreKeyId.toString(),
      partition: _signedPreKeyPortion,
    );
    if (preKeyData == null) {
      throw InvalidKeyIdException(
        'No such signedprekeyrecord! $signedPreKeyId',
      );
    }
    return SignedPreKeyRecord.fromSerialized(preKeyData);
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    Map results = await store.retriveAll(key: _signedPreKeyPortion);
    return results.values
        .map((serialized) => SignedPreKeyRecord.fromSerialized(serialized))
        .toList();
  }

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) async {
    await store.store(
      key: signedPreKeyId.toString(),
      value: record.serialize(),
      partition: _signedPreKeyPortion,
    );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    final preKeyData = await store.retrieve(
      key: signedPreKeyId.toString(),
      partition: _signedPreKeyPortion,
    );
    return preKeyData != null;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    await store.remove(
      key: signedPreKeyId.toString(),
      partition: _signedPreKeyPortion,
    );
  }
}
