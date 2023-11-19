import 'dart:convert';
import 'dart:typed_data';
import 'package:end2end/end2end.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> main(List<String> arguments) async {
  installE2EE();
  return;

  final [
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  ] = await install();

  createSession(
    "bob",
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  );
  return;
  createSession(
    "don",
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  );
  createSession(
    "mafia",
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  );
  await createSession(
    "putin",
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  );
  createSession(
    "putin",
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  );
}

createSession(
  String userId,
  sessionStore,
  preKeyStore,
  signedPreKeyStore,
  identityStore,
) async {
  final bobAddress = SignalProtocolAddress(userId, 1);

  final sessionBuilder = SessionBuilder(
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
    bobAddress,
  );

  final remoteRegId = generateRegistrationId(false);
  final remoteIdentityKeyPair = generateIdentityKeyPair();
  final remotePreKeys = generatePreKeys(0, 110);
  final remoteSignedPreKey = generateSignedPreKey(remoteIdentityKeyPair, 0);

  final retrievedPreKey = PreKeyBundle(
    remoteRegId,
    1,
    remotePreKeys[2].id,
    remotePreKeys[2].getKeyPair().publicKey,
    remoteSignedPreKey.id,
    remoteSignedPreKey.getKeyPair().publicKey,
    remoteSignedPreKey.signature,
    remoteIdentityKeyPair.getPublicKey(),
  );

  await sessionBuilder.processPreKeyBundle(retrievedPreKey);

  final sessionCipher = SessionCipher(
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
    bobAddress,
  );

  final signalProtocolStore = InMemorySignalProtocolStore(
    remoteIdentityKeyPair,
    311,
  );
  const aliceAddress = SignalProtocolAddress('alice', 2);

  final remoteSessionCipher = SessionCipher.fromStore(
    signalProtocolStore,
    aliceAddress,
  );

  for (final p in remotePreKeys) {
    await signalProtocolStore.storePreKey(p.id, p);
  }

  await signalProtocolStore.storeSignedPreKey(
    remoteSignedPreKey.id,
    remoteSignedPreKey,
  );
  for (var i = 0; i < 200; i++) {
    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode('Hello $userId')),
    );

    if (ciphertext.getType() == CiphertextMessage.prekeyType) {
      final plaintext = await remoteSessionCipher.decrypt(
        ciphertext as PreKeySignalMessage,
      );
      print("Decrypted text : $i");
      print(utf8.decode(plaintext));
    }
  }
}

install() async {
  final identityKeyPair = generateIdentityKeyPair();
  final registrationId = generateRegistrationId(false);

  // final publicKey = identityKeyPair.getPublicKey().publicKey.serialize();
  // final privateKey = identityKeyPair.getPrivateKey().serialize();

  // printString(publicKey);
  // printString(privateKey);
  // printString(identityKeyPair.serialize());

  // print("registration id $registrationId");

  final preKeys = generatePreKeys(0, 110);
  final signedPreKey = generateSignedPreKey(identityKeyPair, 0);

  final sessionStore = InMemorySessionStore();
  final preKeyStore = InMemoryPreKeyStore();
  final signedPreKeyStore = InMemorySignedPreKeyStore();
  final identityStore = InMemoryIdentityKeyStore(
    identityKeyPair,
    registrationId,
  );

  for (final p in preKeys) {
    await preKeyStore.storePreKey(p.id, p);
  }
  await signedPreKeyStore.storeSignedPreKey(signedPreKey.id, signedPreKey);
  return [
    sessionStore,
    preKeyStore,
    signedPreKeyStore,
    identityStore,
  ];
}

printString(Uint8List codedString) {
  print(String.fromCharCodes(codedString));
}
