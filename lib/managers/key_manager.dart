import 'package:end2end/managers/key_storage_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

typedef KeySender = Future<bool> Function(Map<String, dynamic>);

class KeyManager {
  static const _preKeysCount = 110;
  final keyStorageManager = KeyStorageManager();
  InMemorySignedPreKeyStore? signedPreKeyStore;
  InMemoryIdentityKeyStore? identityStore;
  InMemoryPreKeyStore? preKeyStore;
  InMemorySessionStore? sessionStore;

  final KeySender identityKeySender;
  final KeySender signedPreKeySender;
  final KeySender preKeySender;

  KeyManager({
    required this.identityKeySender,
    required this.signedPreKeySender,
    required this.preKeySender,
  });

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
    try {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final hasSaved = await identityKeySender({
        "registrationId": registrationId,
        "identityPublic": identityKeyPair.getPublicKey().serialize(),
      });
      if (hasSaved) {
        identityStore = InMemoryIdentityKeyStore(
          identityKeyPair,
          registrationId,
        );
        await keyStorageManager.storeIdentityKey(identityStore!);
      }
    } catch (e) {
      print("error generating identity key");
      print(e);
    }
  }

  Future<void> genSignedPreKey() async {
    try {
      final signedPreKey = generateSignedPreKey(
        identityStore!.identityKeyPair,
        0,
      );
      final hasSend = await signedPreKeySender({
        "signedPreKeyId": signedPreKey.id,
        "signedPreKeySignature": signedPreKey.signature,
        "signedPreKeyPublic": signedPreKey.getKeyPair().publicKey.serialize(),
      });
      if (hasSend) {
        signedPreKeyStore = InMemorySignedPreKeyStore();
        await signedPreKeyStore!.storeSignedPreKey(
          signedPreKey.id,
          signedPreKey,
        );
        await keyStorageManager.storeSignedPreKey(signedPreKeyStore!);
      }
    } catch (e) {
      print("error on sending signed pre key");
      print(e);
    }
  }

  Future<void> managePreKey() async {
    preKeyStore = await keyStorageManager.retrivePreKey();
    if (preKeyStore == null) {
      await genPreKeys(0);
    }
  }

  Future<void> genPreKeys(int start) async {
    try {
      preKeyStore = InMemoryPreKeyStore();
      final preKeys = generatePreKeys(start, _preKeysCount);
      final keyMap = <String, dynamic>{};
      for (final p in preKeys) {
        keyMap["${p.id}"] = p.serialize();
      }
      final hasSend = await preKeySender(keyMap);
      if (hasSend) {
        for (final p in preKeys) {
          await preKeyStore!.storePreKey(p.id, p);
        }
        await keyStorageManager.storePreKeys(preKeyStore!);
      }
    } catch (e) {
      print("error on sending pre key");
      print(e);
    }
  }
}