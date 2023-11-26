import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class InDeviceSenderKeyStore extends SenderKeyStore {
  static InDeviceSenderKeyStore? _instance;

  static const _senderKeyPortion = "sender_key_";

  final KeyStorage _store;
  InDeviceSenderKeyStore(this._store) {
    // if (_instance != null) {
    //   throw Exception("InDeviceSenderKeyStore already initialized");
    // }
    _instance = this;
  }

  static Future<InDeviceSenderKeyStore> retrive(KeyStorage store) async {
    if (_instance != null) return _instance!;
    return InDeviceSenderKeyStore(store);
  }

  @override
  Future<SenderKeyRecord> loadSenderKey(SenderKeyName senderKeyName) async {
    try {
      final record = await _store.retrieve(
        key: senderKeyName.serialize(),
        partition: _senderKeyPortion,
      );
      if (record == null) {
        return SenderKeyRecord();
      } else {
        return SenderKeyRecord.fromSerialized(record);
      }
    } on Exception catch (e) {
      throw AssertionError(e);
    }
  }

  @override
  Future<void> storeSenderKey(
    SenderKeyName senderKeyName,
    SenderKeyRecord record,
  ) async {
    await _store.store(
      key: senderKeyName.serialize(),
      value: record.serialize(),
      partition: _senderKeyPortion,
    );
  }
}
