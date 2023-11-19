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

    final trastedKey = {};
    for (final key in identityStore.trustedKeys.keys) {
      trastedKey[key.toString()] = identityStore.trustedKeys[key]?.serialize();
    }

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

    await keyStorage.store(
      partition: _identityPartition,
      key: "trastedKey",
      value: trastedKey,
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

    if (identityKeyPairData == null || registrationID == null) {
      return null;
    }

    final identityKeyPair = IdentityKeyPair.fromSerialized(
      identityKeyPairData,
    );

    final identityStore = InMemoryIdentityKeyStore(
      identityKeyPair,
      registrationID,
    );

    final trastedKey = await keyStorage.retrive(
      partition: _identityPartition,
      key: "trastedKey",
    );

    if (trastedKey != null) {
      for (final key in trastedKey.keys) {
        final temp = key.split(":");
        final address = SignalProtocolAddress(temp[0], int.parse(temp[1]));
        identityStore.trustedKeys[address] = IdentityKey.fromBytes(
          trastedKey[key],
          0,
        );
      }
    }

    return identityStore;
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
      await keyStorage.store(
        key: session.toString(),
        value: sessions,
        partition: _sessionPartition,
      );
    }
  }

  Future<InMemorySessionStore> retriveSessions() async {
    final sessionStore = InMemorySessionStore();

    final sessions = await keyStorage.retriveAll(
      key: _sessionPartition,
      partition: _sessionPartition,
    );

    if (sessions.isNotEmpty) {
      for (final sessionId in sessions.keys) {
        final temp = sessionId.split(":");
        final address = SignalProtocolAddress(temp[0], int.parse(temp[1]));
        sessionStore.sessions[address] = sessions[sessionId];
      }
    }

    return sessionStore;
  }
}
