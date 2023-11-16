import 'package:end2end/managers/key_storage_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class KeyManager {
  final keyStorageManager = KeyStorageManager();
  InMemoryIdentityKeyStore? identityStore;

  // InMemoryIdentityKeyStore(identityKeyPair, registrationId);

  KeyManager() {
    keyStorageManager.initStorage();
  }

  Future<void> init() async {
    identityStore = await keyStorageManager.retriveIdentityKey();
    if (identityStore == null) {
      await generateIdentityKey();
    }
    print(identityStore);
  }

  Future<void> generateIdentityKey() async {
    final identityKeyPair = generateIdentityKeyPair();
    final registrationId = generateRegistrationId(false);
    identityStore = InMemoryIdentityKeyStore(identityKeyPair, registrationId);
    await keyStorageManager.storeIdentityKey(identityStore!);
  }
}

final myKeyManager = KeyManager();
