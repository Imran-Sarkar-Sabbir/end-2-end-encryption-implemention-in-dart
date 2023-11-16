import 'package:end2end/storage/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class KeyStorageManager {
  final keyStorage = KeyStorage();
  static const String _identityPartition = "identityPartition";
  static const String _signedPreKeyPartition = "signedPreKeyPartition";
  static const String _preKeyPartition = "preKeyPartition";
  static const String _sessionPartition = "sessionPartition";

  initStorage() async {
    await keyStorage.init();
  }

  Future<void> storeIdentityKey(InMemoryIdentityKeyStore identityStore) async {
    final identityKeyPair = identityStore.identityKeyPair.serialize();
    final registrationId = identityStore.localRegistrationId;

    await keyStorage.store(
      partition: _identityPartition,
      key: "identityKeyPair",
      value: identityKeyPair,
    );

    await keyStorage.store(
      partition: _identityPartition,
      key: "registrationId",
      value: registrationId,
    );
  }

  Future<InMemoryIdentityKeyStore?> retriveIdentityKey() async {
    final identityKeyPairData = await keyStorage.retrive(
      partition: _identityPartition,
      key: "identityKeyPair",
    );

    final registrationID = await keyStorage.retrive(
      partition: _identityPartition,
      key: "registrationId",
    );

    if (identityKeyPairData != null && registrationID != null) {
      final identityKeyPair = IdentityKeyPair.fromSerialized(
        identityKeyPairData,
      );
      return InMemoryIdentityKeyStore(identityKeyPair, registrationID);
    }
    return null;
  }

  Future<void> storeSignedPreKey(
    InMemorySignedPreKeyStore signedPreKeyStore,
  ) async {
    final keyMap = {};
    for (final key in signedPreKeyStore.store.keys) {
      keyMap[key] = signedPreKeyStore.store[key];
    }
    await keyStorage.store(
      partition: _signedPreKeyPartition,
      key: _signedPreKeyPartition,
      value: keyMap,
    );
  }

  Future<InMemorySignedPreKeyStore?> retriveSignedPreKey() async {
    final keyMap = await keyStorage.retrive(
      partition: _signedPreKeyPartition,
      key: _signedPreKeyPartition,
    );

    if (keyMap != null) {
      final signedPreKeyStore = InMemorySignedPreKeyStore();
      for (final key in keyMap.keys) {
        signedPreKeyStore.store[key] = keyMap[key];
      }
      return signedPreKeyStore;
    }
    return null;
  }

  Future<void> storePreKeys(
    InMemoryPreKeyStore preKeyStore,
  ) async {
    final keyMap = {};
    for (final key in preKeyStore.store.keys) {
      keyMap[key] = preKeyStore.store[key];
    }
    await keyStorage.store(
      partition: _preKeyPartition,
      key: _preKeyPartition,
      value: keyMap,
    );
  }

  Future<InMemoryPreKeyStore?> retrivePreKey() async {
    final keyMap = await keyStorage.retrive(
      partition: _preKeyPartition,
      key: _preKeyPartition,
    );

    if (keyMap != null) {
      final preKeyStore = InMemoryPreKeyStore();
      for (final key in keyMap.keys) {
        preKeyStore.store[key] = keyMap[key];
      }
      return preKeyStore;
    }
    return null;
  }

  Future<void> storeSessions(InMemorySessionStore sessionStore) async {
    final sessions = {};
    for (final session in sessionStore.sessions.keys) {
      sessions[session.getName()] = {
        "deviceId": session.getDeviceId(),
        "key": sessionStore.sessions[session],
      };
    }
    await keyStorage.store(
      key: _sessionPartition,
      value: sessions,
      partition: _sessionPartition,
    );
  }

  Future<InMemorySessionStore> retriveSessions() async {
    final sessionStore = InMemorySessionStore();

    final sessions = await keyStorage.retrive(
      key: _sessionPartition,
      partition: _sessionPartition,
    );

    if (sessions != null) {
      for (final sessionId in sessions.keys) {
        final userSession = SignalProtocolAddress(
          sessionId,
          sessions[sessionId]["deviceId"],
        );
        sessionStore.sessions[userSession] = sessions[sessionId]['key'];
      }
    }

    return sessionStore;
  }
}
