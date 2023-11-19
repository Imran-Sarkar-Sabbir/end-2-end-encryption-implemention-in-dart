import 'dart:convert';
import 'dart:typed_data';
import 'package:end2end/end2end.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import "package:libsignal_protocol_dart/src/ecc/curve.dart";

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
  preKeyStore,
  signedPreKeyStore,
  InMemoryIdentityKeyStore identityStore,
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

  final preKey = remotePreKeys[0].getKeyPair();

  print("===============================");
  printString(preKey.publicKey.serialize());
  printString(
      Curve.decodePoint(Uint8List.fromList(preKey.publicKey.serialize()), 0)
          .serialize());
  print("===============================");
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

  showSessions(sessionStore);
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

  for (var i = 0; i < 5; i++) {
    // showSessions(sessionStore);
    final ciphertext = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode('Hello $userId')),
    );

    if (ciphertext.getType() == CiphertextMessage.prekeyType) {
      final serialized = ciphertext.serialize();

      final msg = PreKeySignalMessage(serialized);

      final plaintext = await remoteSessionCipher.decrypt(
        msg,
      );
      print("Decrypted text : $i");
      print(utf8.decode(plaintext));
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
