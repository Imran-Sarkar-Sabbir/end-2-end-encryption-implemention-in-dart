import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:end2end/file_operation/cbc_file_crypto.dart';

const cypher_key = "encryption k for file encryption";
final iv = "aaaaaaaaaaaaaaaa";

Future<void> readfile() async {
  final enctyptor = CBCFileCrypto();

  // const fileName = "jukto.jpg";
  // const fileName = "my_file.txt";
  // const fileName = "video.mp4";
  const fileName = "Docker Desktop Installer.exe";
  // const fileName = "VSCodeUserSetup-x64-1.54.1.exe";
  final myFile = File("./lib/file_operation/$fileName");
  final encryptedFile = File("./lib/file_operation/encryption/a$fileName.ase")
    ..createSync(recursive: true);

  final decryptedFile = File("./lib/file_operation/decryption/a$fileName")
    ..createSync(recursive: true);

  // testCBC();
  // return;

  try {
    DateTime startTime = DateTime.now();
    await enctyptor.encrypt(
      source: myFile,
      dest: encryptedFile,
      key: cypher_key,
      iv: iv,
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
    key: cypher_key,
    iv: iv,
  );
  DateTime endTime = DateTime.now();
  print("Decryption need : ${endTime.difference(startTime)}");
}

void testCBC() {
  final plainText = [
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1
  ];
  final messageAuthenticationCode = 'flutter is awesome';

  final key = Key(Uint8List.fromList(cypher_key.codeUnits));
  final iv = IV(Uint8List.fromList("iiiiiiiiiiiiiiii".codeUnits));
  final macValue = Uint8List.fromList(utf8.encode(messageAuthenticationCode));

  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: ""));

  final encrypted = encrypter.encryptBytes(
    plainText,
    iv: iv,
    // associatedData: macValue,
  );
  final decrypted = encrypter.decrypt(
    encrypted,
    iv: iv,
    // associatedData: macValue,
  );

  print(plainText.length);
  print(decrypted);
  print(encrypted.bytes);
  print(encrypted.bytes.length);
  print(encrypted.base16);
  print(encrypted.base64);
}

void getFileDetails(File file) {
  print('File exists: ${file.path}');
  print('File length: ${file.lengthSync()} bytes');
  print('Last modified: ${file.lastModifiedSync()}');
  print(
    'Is a directory: ${file.statSync().type == FileSystemEntityType.directory}',
  );
  print('Is a file: ${file.statSync().type == FileSystemEntityType.file}');
}

// const cypher_key = "0123456789ABCDEF";

printHex(Uint8List data) {
  print("================================");
  print("data length : ${data.length}");
  print(toHex(data));
}

toHex(Uint8List data) {
  return data.map((e) => e.toRadixString(16)).join();
}
