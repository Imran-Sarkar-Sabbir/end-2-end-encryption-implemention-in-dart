import 'package:end2end/crypto/crypto_utilities.dart';
import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class InDeviceSessionStore extends SessionStore {
  static InDeviceSessionStore? _instance;

  static const _sessionPortion = "sessions";

  final KeyStorage store;
  InDeviceSessionStore(this.store) {
    if (_instance != null) {
      throw Exception("InDeviceSessionStore already initialized");
    }
    _instance = this;
  }

  static Future<InDeviceSessionStore?> retrive(KeyStorage store) async {
    if (_instance != null) return _instance;
    return InDeviceSessionStore(store);
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final sessionData = await store.retrieve(
      key: address.toString(),
      partition: _sessionPortion,
    );
    return sessionData != null;
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    final sessions = await store.retriveAll(key: _sessionPortion);
    for (final k in sessions.keys.toList()) {
      if (getAddressName(k) == name) {
        await store.remove(key: k, partition: _sessionPortion);
      }
    }
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    await store.remove(key: address.toString(), partition: _sessionPortion);
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final deviceIds = <int>[];
    final sessions = await store.retriveAll(key: _sessionPortion);
    for (final key in sessions.keys) {
      final session = getAddress(key);
      if (session.getName() == name && session.getDeviceId() != 1) {
        deviceIds.add(key.getDeviceId());
      }
    }

    return deviceIds;
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    try {
      final sessionData = await store.retrieve(
        key: address.toString(),
        partition: _sessionPortion,
      );
      if (sessionData != null) {
        return SessionRecord.fromSerialized(sessionData!);
      } else {
        return SessionRecord();
      }
    } on Exception catch (e) {
      throw AssertionError(e);
    }
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) async {
    await store.store(
      key: address.toString(),
      value: record.serialize(),
      partition: _sessionPortion,
    );
  }
}
