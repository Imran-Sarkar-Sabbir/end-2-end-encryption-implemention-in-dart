import 'package:end2end/managers/key_storage_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class KeyManager {
  static const _preKeysCount = 110;
  final keyStorageManager = KeyStorageManager();
  InMemorySignedPreKeyStore? signedPreKeyStore;
  InMemoryIdentityKeyStore? identityStore;
  InMemoryPreKeyStore? preKeyStore;
  InMemorySessionStore? sessionStore;

  Future<void> init() async {
    keyStorageManager.initStorage();
  }

  Future<void> install() async {
    identityStore = await keyStorageManager.retriveIdentityKey();
    if (identityStore == null) {
      await generateIdentityKey();
    }
    signedPreKeyStore = await keyStorageManager.retriveSignedPreKey();
    if (signedPreKeyStore == null) {
      await genSignedPreKey();
    }
    await managePreKey();
    sessionStore = await keyStorageManager.retriveSessions();
  }

  Future<void> generateIdentityKey() async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    identityStore = InMemoryIdentityKeyStore(identityKeyPair, registrationId);
    await keyStorageManager.storeIdentityKey(identityStore!);
  }

  Future<void> genSignedPreKey() async {
    final signedPreKey = generateSignedPreKey(
      identityStore!.identityKeyPair,
      0,
    );
    signedPreKeyStore = InMemorySignedPreKeyStore();
    await signedPreKeyStore!.storeSignedPreKey(signedPreKey.id, signedPreKey);
    await keyStorageManager.storeSignedPreKey(signedPreKeyStore!);
  }

  Future<void> managePreKey() async {
    preKeyStore = await keyStorageManager.retrivePreKey();
    if (preKeyStore == null) {
      await genPreKeys(0);
    }
  }

  Future<void> genPreKeys(int start) async {
    preKeyStore = InMemoryPreKeyStore();
    final preKeys = generatePreKeys(start, _preKeysCount);
    for (final p in preKeys) {
      await preKeyStore!.storePreKey(p.id, p);
    }
    await keyStorageManager.storePreKeys(preKeyStore!);
  }
}

final myKeyManager = KeyManager();
