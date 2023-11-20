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
    for (final msg in messages) {
      try {
        print("msg");
        print(msg);
        final ciphertext = SignalMessage.fromSerialized(parseBytes(msg));
        final plainText = await sessionCipher.decryptFromSignal(
          ciphertext,
        );
        print(utf8.decode(plainText));
      } on Error catch (e) {
        print(e);
        print(e.stackTrace);
        print("error decrypting message");
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

      final data = jsonDecode(remoteUserKeys);
      final retrievedPreKey = PreKeyBundle(
        data["registrationId"],
        0,
        int.parse(data["preKeyId"]),
        Curve.decodePoint(
          parseBytes(data["preKey"]),
          0,
        ),
        data["signedPreKeyId"],
        Curve.decodePoint(
          parseBytes(data["signedPreKeyPublic"]),
          0,
        ),
        parseBytes(data["signedPreKeySignature"]),
        IdentityKey.fromBytes(parseBytes(data["identityPublic"]), 0),
      );

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

Uint8List parseBytes(List<dynamic> ll) {
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
  await apiPost("/messages/$otherId", {
    "msg": cipherMsg.serialize(),
    "from": myId,
  });
}
