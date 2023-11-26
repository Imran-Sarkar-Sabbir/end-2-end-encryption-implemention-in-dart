import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:end2end/crypto/crypto_utilities/cbc_file_crypto.dart';

const cypher_key = "encryption k for file encryption";
final iv = "aaaaaaaaaaaaaaaa";

Future<void> readfile() async {
  final enctyptor = CBCFileCrypto();

  // const fileName = "jukto.jpg";
  // const fileName = "my_file.txt";
  const fileName = "video.mp4";
  // const fileName = "Docker Desktop Installer.exe";
  // const fileName = "VSCodeUserSetup-x64-1.54.1.exe";
  // const fileName ="Extraction.2.2023.1080p.NF.WEB-DL.DDP5.1.Atmos.H.264-XEBEC.mkv";
  final myFile = File("./lib/file_operation/$fileName");
  final encryptedFile = File("./lib/file_operation/encryption/$fileName.ase")
    ..createSync(recursive: true);

  final decryptedFile = File("./lib/file_operation/decryption/$fileName")
    ..createSync(recursive: true);

  try {
    DateTime startTime = DateTime.now();
    await enctyptor.encrypt(
      source: myFile,
      dest: encryptedFile,
      key: Uint8List.fromList(cypher_key.codeUnits),
      iv: Uint8List.fromList(iv.codeUnits),
    );
    DateTime endTime = DateTime.now();
    print("Encryption need : ${endTime.difference(startTime)}");
  } on Error catch (e) {
    print("Error encrypting");
    print(e);
    print(e.stackTrace);
  }
  DateTime startTime = DateTime.now();
  await enctyptor.decrypt(
    source: encryptedFile,
    dest: decryptedFile,
    key: Uint8List.fromList(cypher_key.codeUnits),
    iv: Uint8List.fromList(iv.codeUnits),
  );
  DateTime endTime = DateTime.now();
  print("Decryption need : ${endTime.difference(startTime)}");
}
