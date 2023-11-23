import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:end2end/crypto/stores/InDeviceIdentityKeyStore.dart';
import 'package:end2end/crypto/stores/InDevicePreKeyStore.dart';
import 'package:end2end/crypto/stores/InDeviceSessionStore.dart';
import 'package:end2end/crypto/stores/InDeviceSignedPreKeyStore.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

typedef KeySender = Future<bool> Function(Map<String, dynamic>);

class KeyManager {
  final keyStorage = KeyStorage();
  InDeviceIdentityKeyStore? identityStore;
  InDeviceSignedPreKeyStore? signedPreKeyStore;
  InDevicePreKeyStore? preKeyStore;
  InDeviceSessionStore? sessionStore;

  final KeySender identityKeySender;
  final KeySender signedPreKeySender;
  final KeySender preKeySender;

  KeyManager({
    required this.identityKeySender,
    required this.signedPreKeySender,
    required this.preKeySender,
  });

  Future<void> init() async {
    await keyStorage.init();
  }

  Future<void> install() async {
    identityStore = await InDeviceIdentityKeyStore.retrive(keyStorage);
    if (identityStore == null) {
      if (!await generateIdentityKeyStore()) {
        throw Exception("Error saving identity key");
      }
    }

    signedPreKeyStore = await InDeviceSignedPreKeyStore.retrive(keyStorage);
    if (signedPreKeyStore == null) {
      if (!await genSignedPreKeyStore()) {
        throw Exception("Error saving signed pre key");
      }
    }

    preKeyStore = await InDevicePreKeyStore.retrive(keyStorage);
    if (preKeyStore == null) {
      if (!await genPreKeyStore()) {
        throw Exception("Error saving pre key");
      }
    }

    if (await preKeyStore!.shouldGenPreKey()) {
      await genPreKeys();
    }

    sessionStore = await InDeviceSessionStore.retrive(keyStorage);
  }

  Future<bool> generateIdentityKeyStore() async {
    try {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);
      final hasSaved = await identityKeySender({
        "registrationId": registrationId,
        "identityPublic": identityKeyPair.getPublicKey().serialize(),
      });
      if (hasSaved) {
        identityStore = InDeviceIdentityKeyStore(
          identityKeyPair,
          registrationId,
          keyStorage,
        );
        await identityStore!.save();
      }
      return hasSaved;
    } catch (e) {
      print("error generating identity key");
      print(e);
      return false;
    }
  }

  Future<bool> genSignedPreKeyStore() async {
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
        signedPreKeyStore = InDeviceSignedPreKeyStore(keyStorage);
        await signedPreKeyStore!.storeSignedPreKey(
          signedPreKey.id,
          signedPreKey,
        );
      }
      return hasSend;
    } catch (e) {
      print("error on sending signed pre key");
      print(e);
      return false;
    }
  }

  Future<bool> genPreKeyStore() async {
    try {
      preKeyStore = InDevicePreKeyStore(keyStorage);

      if (await preKeyStore!.shouldGenPreKey()) {
        return genPreKeys();
      } else {
        return true;
      }
    } catch (e) {
      print("error on sending pre key");
      print(e);
      return false;
    }
  }

  Future<bool> genPreKeys() async {
    int preKeyIndex = await preKeyStore!.getPreKeyIndex();
    final preKeys = generatePreKeys(
      preKeyIndex,
      preKeyIndex + InDevicePreKeyStore.GEN_PRE_KEY_PER_BATCH,
    );
    final keyMap = <String, dynamic>{};
    for (final p in preKeys) {
      keyMap["${p.id}"] = p.getKeyPair().publicKey.serialize();
    }
    final hasSend = await preKeySender(keyMap);
    if (hasSend) {
      for (final p in preKeys) {
        await preKeyStore!.storePreKey(p.id, p);
      }
    }
    int lastIndex = (preKeys.last.id + 1).remainder(maxValue - 1) + 1;
    await preKeyStore?.storePreKeyIndex(lastIndex);
    return hasSend;
  }

  hasSessionWith({required SignalProtocolAddress user}) {
    return sessionStore?.containsSession(user) ?? false;
  }
}
