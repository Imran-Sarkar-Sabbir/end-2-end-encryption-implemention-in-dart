import 'dart:convert';
import 'dart:typed_data';

import 'package:end2end/my_key_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> installE2EE() async {
  await myKeyManager.init();
  await myKeyManager.install();

  await fetchMessages();
  await sendMessages();
}

fetchMessages() async {
  final response = await apiGet("/messages/$myId");
  final data = jsonDecode(response);
  for (final userId in data.keys) {
    final sessionCipher = await getSessionCipher(userId);
    if (sessionCipher == null) continue;
    final messages = data[userId];
    for (String msg in messages) {
      final cipherMsg = Uint8List.fromList(msg.codeUnits);
      final ciphertext = SignalMessage.fromSerialized(cipherMsg);
      if (ciphertext.getType() == CiphertextMessage.prekeyType) {
        final plainText = await sessionCipher.decrypt(
          ciphertext as PreKeySignalMessage,
        );
        print(plainText);
      }
    }
    await myKeyManager.saveSession();
  }
}

Future<SessionCipher?> getSessionCipher(String userId) async {
  final address = SignalProtocolAddress(userId, 0);
  bool hasSession = await myKeyManager.hasSessionWith(user: address);

  if (!hasSession) {
    try {
      final remoteUserKeys = await apiGet('/key/$otherId');
      print("remoteUserKeys");
      print(remoteUserKeys);
      final data = jsonDecode(remoteUserKeys);

      print(data["registrationId"]);
      print(data["registrationId"].runtimeType);
      final retrievedPreKey = PreKeyBundle(
        data["registrationId"],
        0,
        int.parse(data["preKeyId"]),
        Curve.decodePoint(
          parse(data["preKey"]),
          0,
        ),
        data["signedPreKeyId"],
        Curve.decodePoint(
          parse(data["signedPreKeyPublic"]),
          0,
        ),
        parse(data["signedPreKeySignature"]),
        IdentityKey.fromBytes(parse(data["identityPublic"]), 0),
      );

      print("retrievedPreKey");
      print(retrievedPreKey);

      final sessionBuilder = SessionBuilder(
        myKeyManager.sessionStore!,
        myKeyManager.preKeyStore!,
        myKeyManager.signedPreKeyStore!,
        myKeyManager.identityStore!,
        address,
      );
      await sessionBuilder.processPreKeyBundle(retrievedPreKey);
      await myKeyManager.saveSession();
      await myKeyManager.storeIdentity();
    } on Error catch (e) {
      print(e);
      print(e.stackTrace);
      print("error getring usres key");
      return null;
    }
  }

  return SessionCipher(
    myKeyManager.sessionStore!,
    myKeyManager.preKeyStore!,
    myKeyManager.signedPreKeyStore!,
    myKeyManager.identityStore!,
    address,
  );
}

Uint8List parse(List<dynamic> ll) {
  Uint8List l = Uint8List(ll.length);
  for (var i = 0; i < ll.length; i++) {
    l[i] = ll[i];
  }
  return l;
}

sendMessages() async {
  final sessionCipher = await getSessionCipher(otherId);

  print("sessionCipher");
  print(sessionCipher);
  if (sessionCipher == null) {
    return;
  }

  final cipherMsg = await sessionCipher.encrypt(
    Uint8List.fromList(utf8.encode("this is my encrypted message")),
  );

  await myKeyManager.saveSession();
  final response = await apiPost("/messages/$otherId", {
    "msg": String.fromCharCodes(cipherMsg.serialize()),
    "from": myId,
  });
  print(response);
}

// void sendKeysToRemote() {
//   final preKeyId = 0;
//   final preKey = PreKeyRecord.fromBuffer(
//     myKeyManager.preKeyStore!.store[preKeyId]!,
//   );

//   final signPreKeyId = myKeyManager.signedPreKeyStore!.store.keys.first;
//   final signPreKey = SignedPreKeyRecord.fromSerialized(
//     myKeyManager.signedPreKeyStore!.store[signPreKeyId]!,
//   );

//   final myGeneratedKey = {
//     "remoteRegId": myKeyManager.identityStore!.localRegistrationId,
//     "deviceId": 1,
//     "preKeyId": preKeyId,
//     "preKeyPublic": preKey.getKeyPair().publicKey.serialize(),
//     "signedPreKeyId": signPreKeyId,
//     "signedPreKeyPublic": signPreKey.getKeyPair().publicKey.serialize(),
//     "signPreSignature": signPreKey.signature,
//     "identityPublic":
//         myKeyManager.identityStore!.identityKeyPair.getPublicKey().serialize(),
//   };

//   print(myGeneratedKey);
// }
