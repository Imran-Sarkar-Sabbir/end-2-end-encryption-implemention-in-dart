import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:end2end/my_key_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> installE2EE() async {
  // groupTest();
  // return;
  await myKeyManager.init();
  await myKeyManager.install();

  await fetchMessages();
  String? message;
  do {
    print("Write a message");
    message = stdin.readLineSync();
    if (message != null && message.isNotEmpty && message != "q") {
      if (message == "r") {
        await fetchMessages();
      } else {
        await sendMessages(message);
      }
    }
  } while (message != null && message.isNotEmpty && message != "q");
}

fetchMessages() async {
  final response = await apiGet("/messages/$myId");

  final data = jsonDecode(response);
  for (final userId in data.keys) {
    final sessionCipher = await getSessionCipher(userId);
    if (sessionCipher == null) continue;
    final messages = data[userId];
    for (String msg in messages) {
      try {
        final cypher = msg.codeUnits;
        try {
          // print("SignalMessage");
          final ciphertext = SignalMessage.fromSerialized(parseBytes(cypher));
          final plainText = await sessionCipher.decryptFromSignal(
            ciphertext,
          );
          print("message : ${utf8.decode(plainText)}");
        } catch (e) {
          // print("PreKeySignalMessage");
          final ciphertext = PreKeySignalMessage(parseBytes(cypher));
          final plainText = await sessionCipher.decrypt(
            ciphertext,
          );
          print("message : ${utf8.decode(plainText)}");
        }
      } on Error catch (e) {
        print(e);
        print(e.stackTrace);
        print("error decrypting message");
      }
    }
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

sendMessages(String message) async {
  final sessionCipher = await getSessionCipher(otherId);
  if (sessionCipher == null) {
    return;
  }

  try {
    final cipherMsg = await sessionCipher.encrypt(
      Uint8List.fromList(utf8.encode(message)),
    );

    await apiPost("/messages/$otherId", {
      "msg": String.fromCharCodes(cipherMsg.serialize()),
      "from": myId,
    });
  } catch (e) {
    print(e);
    print("error on encrypting message or sending");
  }
}

Future<void> groupTest() async {
  const alice = SignalProtocolAddress('+00000000001', 1);
  const groupSender = SenderKeyName('Private group', alice);
  final aliceStore = InMemorySenderKeyStore();
  final bobStore = InMemorySenderKeyStore();
  final tomStore = InMemorySenderKeyStore();

  final aliceSessionBuilder = GroupSessionBuilder(aliceStore);
  final bobSessionBuilder = GroupSessionBuilder(bobStore);
  final tomSessionBuilder = GroupSessionBuilder(tomStore);

  final aliceGroupCipher = GroupCipher(aliceStore, groupSender);
  final bobGroupCipher = GroupCipher(bobStore, groupSender);
  final tomGroupCipher = GroupCipher(tomStore, groupSender);

  final sentAliceDistributionMessage =
      await aliceSessionBuilder.create(groupSender);

  final receivedAliceDistributionMessage =
      SenderKeyDistributionMessageWrapper.fromSerialized(
    sentAliceDistributionMessage.serialize(),
  );

  await bobSessionBuilder.process(
    groupSender,
    receivedAliceDistributionMessage,
  );

  await tomSessionBuilder.process(
    groupSender,
    receivedAliceDistributionMessage,
  );

  final ciphertextFromAlice = await aliceGroupCipher
      .encrypt(Uint8List.fromList(utf8.encode('Hello Mixin')));
  final plaintextFromAlice = await bobGroupCipher.decrypt(ciphertextFromAlice);
  final plaintextFromAliceForTom =
      await tomGroupCipher.decrypt(ciphertextFromAlice);
  // ignore: avoid_print
  print(utf8.decode(plaintextFromAlice));
  print(utf8.decode(plaintextFromAliceForTom));
}
