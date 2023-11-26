import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:end2end/crypto/crypto_utilities/cbc_file_crypto.dart';
import 'package:end2end/crypto/crypto_utilities/custom_group_cipher.dart';
import 'package:end2end/crypto/storage_manager/adapters/hive_storage.dart';
import 'package:end2end/crypto/storage_manager/stores/InDeviceSenderKeyStore.dart';
import 'package:end2end/my_key_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> installE2EE() async {
  await groupTest();
  return;
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

  final aliceS = HiveKeyStore(path: 'alice');
  final bobS = HiveKeyStore(path: 'bob');
  final tomS = HiveKeyStore(path: 'tom');
  final mikeS = HiveKeyStore(path: 'mike');

  final aliceStore = InDeviceSenderKeyStore(aliceS);
  final bobStore = InDeviceSenderKeyStore(bobS);
  final tomStore = InDeviceSenderKeyStore(tomS);
  final mikeStore = InDeviceSenderKeyStore(mikeS);

  // final aliceStore = InMemorySenderKeyStore();
  // final bobStore = InMemorySenderKeyStore();
  // final tomStore = InMemorySenderKeyStore();

  final aliceSessionBuilder = GroupSessionBuilder(aliceStore);
  final bobSessionBuilder = GroupSessionBuilder(bobStore);
  final tomSessionBuilder = GroupSessionBuilder(tomStore);
  final mikeSessionBuilder = GroupSessionBuilder(mikeStore);

  final aliceGroupCipher = CustomGroupCipher(aliceStore, groupSender);
  final bobGroupCipher = CustomGroupCipher(bobStore, groupSender);
  final tomGroupCipher = CustomGroupCipher(tomStore, groupSender);
  final mikeGroupCipher = CustomGroupCipher(mikeStore, groupSender);

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

  await mikeSessionBuilder.process(
    groupSender,
    receivedAliceDistributionMessage,
  );

  final bobMsg = await aliceGroupCipher.encrypt(Uint8List.fromList(
    utf8.encode(
      "#include <stdio.h>\nint main() {\n\tprintf(\"Hello World 😎\");\n\treturn 0;\n}",
    ),
  ));

  final cryptoInfo = await aliceGroupCipher.getFileEncryptionKeys();
  cryptoInfo["fileName"] = fileName;

  final myFile = File(fileName);
  final encryptFilePath = "./encryption/$fileName.ase";
  final encryptedFile = File(encryptFilePath)..createSync(recursive: true);

  cryptoInfo["encryptFilePath"] = encryptFilePath;
  final fileCrypto = CBCFileCrypto();
  await fileCrypto.encrypt(
    source: myFile,
    dest: encryptedFile,
    key: cryptoInfo["fileKey"],
    iv: cryptoInfo["fileIV"],
  );
  final fileMsg = await aliceGroupCipher.encryptFileInfo(cryptoInfo);

  final deMsg = await bobGroupCipher.decrypt(bobMsg);
  final tomMsg = await tomGroupCipher.decrypt(bobMsg);
  final mikeMsg = await mikeGroupCipher.decrypt(bobMsg);
  final defileMsg = await mikeGroupCipher.decrypt(fileMsg);
  print(utf8.decode(deMsg));
  print(utf8.decode(tomMsg));
  print(utf8.decode(mikeMsg));

  final fileInfo = jsonDecode(utf8.decode(defileMsg));
  print(fileInfo);

  final decryptedFile = File("./decryption/${fileInfo["fileName"]}")
    ..createSync(recursive: true);
  await fileCrypto.decrypt(
    source: File(fileInfo["encryptFilePath"]),
    dest: decryptedFile,
    key: parseBytes(fileInfo["fileKey"]),
    iv: parseBytes(fileInfo["fileIV"]),
  );
}

// const fileName = "jukto.jpg";
// const fileName = "my_file.txt";
const fileName = "WhatsApp Security Paper Analysis - Mit.pdf";

  // const fileName = "Docker Desktop Installer.exe";
  // const fileName = "VSCodeUserSetup-x64-1.54.1.exe";
  // const fileName ="Extraction.2.2023.1080p.NF.WEB-DL.DDP5.1.Atmos.H.264-XEBEC.mkv";