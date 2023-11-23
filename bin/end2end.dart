import 'dart:convert';
import 'dart:typed_data';
import 'package:end2end/end2end.dart';
import 'package:end2end/file_operation/read_file.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> main(List<String> arguments) async {
  // readfile();
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
}

install() async {
  final identityKeyPair = generateIdentityKeyPair();
  final registrationId = generateRegistrationId(false);
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

String toString(codedString) {
  return String.fromCharCodes(codedString);
}

printString(Uint8List codedString) {
  print(toString(codedString));
}

createSession(
  String userId,
  InMemorySessionStore sessionStore,
  InMemoryPreKeyStore preKeyStore,
  InMemorySignedPreKeyStore signedPreKeyStore,
  InMemoryIdentityKeyStore identityStore,
) async {
  final bobAddress = SignalProtocolAddress(userId, 0);

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
    0,
    remotePreKeys[0].id,
    remotePreKeys[0].getKeyPair().publicKey,
    remoteSignedPreKey.id,
    remoteSignedPreKey.getKeyPair().publicKey,
    remoteSignedPreKey.signature,
    remoteIdentityKeyPair.getPublicKey(),
  );

  // showSessions(sessionStore);
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

  const aliceAddress = SignalProtocolAddress('alice', 0);

  for (final p in remotePreKeys) {
    await signalProtocolStore.storePreKey(p.id, p);
  }

  await signalProtocolStore.storeSignedPreKey(
    remoteSignedPreKey.id,
    remoteSignedPreKey,
  );

  final remoteSessionBuilder = SessionBuilder(
    signalProtocolStore,
    signalProtocolStore,
    signalProtocolStore,
    signalProtocolStore,
    bobAddress,
  );

  final signedPreKey = await signedPreKeyStore.loadSignedPreKey(
    signedPreKeyStore.store.keys.first,
  );

  final remoteRetrievedPreKey = PreKeyBundle(
    await identityStore.getLocalRegistrationId(),
    0,
    0,
    PreKeyRecord.fromBuffer(preKeyStore.store[0]!).getKeyPair().publicKey,
    signedPreKey.id,
    signedPreKey.getKeyPair().publicKey,
    signedPreKey.signature,
    identityStore.identityKeyPair.getPublicKey(),
  );

  await remoteSessionBuilder.processPreKeyBundle(remoteRetrievedPreKey);

  final remoteSessionCipher = SessionCipher(
    signalProtocolStore,
    signalProtocolStore,
    signalProtocolStore,
    signalProtocolStore,
    aliceAddress,
  );
  for (var i = 0; i < 5; i++) {
    // showSessions(sessionStore);

    print(i);

    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode('Hello $userId')),
    );
    final ciphertext2 = await remoteSessionCipher.encrypt(
      Uint8List.fromList(utf8.encode('Hello form remote')),
    );

    if (ciphertext.getType() == CiphertextMessage.prekeyType) {
      final serialized = ciphertext.serialize();

      final msg = PreKeySignalMessage(serialized);

      final plaintext = await remoteSessionCipher.decrypt(
        msg,
      );

      final plaintext2 = await sessionCipher.decrypt(
        ciphertext2 as PreKeySignalMessage,
      );
      print("Decrypted text : $i");
      print(utf8.decode(plaintext));
      print(utf8.decode(plaintext2));
    }
  }

  print("keys");
  print(map.keys.length);
}

showIdentity(InMemoryIdentityKeyStore identityStore) async {
  final idKey = await identityStore.getIdentityKeyPair();
  final trastedKey = identityStore.trustedKeys;

  printString(idKey.serialize());
  for (final key in trastedKey.keys) {
    print("$key -> ${toString(trastedKey[key]?.serialize())}");
  }
  print("****************************************************************");
}

final map = {};
showSessions(InMemorySessionStore sessionStore) {
  for (final sessionKey in sessionStore.sessions.keys) {
    print("$sessionKey -> ${toString(sessionStore.sessions[sessionKey])}");
    map[toString(sessionStore.sessions[sessionKey])] = true;
  }
  print("****************************************************************");
}
