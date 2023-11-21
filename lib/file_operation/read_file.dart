import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/export.dart';

Future<void> readfile() async {
  // const fileName = "jukto.jpg";
  // const fileName = "my_file.txt";
  const fileName = "video.mp4";
  final myFile = File("./lib/file_operation/$fileName");
  final encryptedFile = File("./lib/file_operation/encryption/$fileName.ase")
    ..createSync(recursive: true);

  final decryptedFile = File("./lib/file_operation/decryption/$fileName")
    ..createSync(recursive: true);
  getFileDetails(myFile);
  await encrypt(myFile, encryptedFile);
  await decrypted(encryptedFile, decryptedFile);
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

const key = "encryption k for file encryption";

encrypt(File file, File encryptionFile) async {
  RandomAccessFile rawFile = file.openSync();
  RandomAccessFile distRawFile = encryptionFile.openSync(mode: FileMode.write);

  const blockSize = 16;
  final encryptor = BlockCipher('AES')
    ..init(
        true,
        KeyParameter(
          Uint8List.fromList(key.codeUnits),
        ));

  final decryptor = BlockCipher('AES')
    ..init(
        false,
        KeyParameter(
          Uint8List.fromList(key.codeUnits),
        ));

  final totalBytes = file.lengthSync();
  int position = 0;
  print("totalBytes $totalBytes");

  while ((position + blockSize) <= totalBytes) {
    rawFile.setPositionSync(position);
    position += blockSize;
    List<int> bytes = await rawFile.read(position);
    final rowData = Uint8List.fromList(bytes);
    final cypherData = encryptor.process(rowData);
    distRawFile.writeFromSync(cypherData);
  }

  print(" =================================================================");
  print("");
  print("");

  int paddingSize = 0;
  if (position < totalBytes) {
    rawFile.setPositionSync(position);
    position = totalBytes;
    List<int> bytes = await rawFile.read(position);
    List<int> finalBytes = [];

    print("position: $position");
    print("totalBytes: $totalBytes");
    print("bytes length : ${bytes.length}");

    finalBytes.addAll(bytes);
    paddingSize = (blockSize - finalBytes.length);
    final endPosition = position + paddingSize;
    while (++position <= endPosition) {
      finalBytes.add(0);
    }
    print("finalBytes length : ${finalBytes.length}");

    // print(String.fromCharCodes(finalBytes));
    // print(finalBytes);
    // print(finalBytes.length);

    final rowData = Uint8List.fromList(finalBytes);
    final cypherData = encryptor.process(rowData);
    distRawFile.writeFromSync(cypherData);
  }
  distRawFile.writeFromSync([paddingSize]);
  await rawFile.close();
  await distRawFile.close();
  print("position: $position && totalBytes: $totalBytes");
  print("file encrypted successfully");

  print("");
  print("");
  print(" =================================================================");
}

decrypted(File file, File decryptionFile) async {
  RandomAccessFile rawFile = file.openSync();
  RandomAccessFile distRawFile = decryptionFile.openSync(mode: FileMode.write);

  const blockSize = 16;
  final decryptor = BlockCipher('AES')
    ..init(
        false,
        KeyParameter(
          Uint8List.fromList(key.codeUnits),
        ));

  int totalBytes = file.lengthSync();
  rawFile.setPositionSync(totalBytes - 1);

  final [paddingSize] = await rawFile.read(totalBytes);
  totalBytes--;

  print("totalBytes $totalBytes");
  int position = 0;
  final endPosition = totalBytes - blockSize;
  while ((position + blockSize) <= endPosition) {
    rawFile.setPositionSync(position);
    position += blockSize;
    List<int> bytes = await rawFile.read(position);
    final cypherData = Uint8List.fromList(bytes);
    final rowData = decryptor.process(cypherData);
    distRawFile.writeFromSync(rowData);
  }
  rawFile.setPositionSync(position);
  position += blockSize;
  List<int> bytes = await rawFile.read(position);
  final cypherData = Uint8List.fromList(bytes);
  final rowData = decryptor.process(cypherData);

  final lastBlock = <int>[];
  lastBlock.addAll(rowData);
  for (var i = 0; i < paddingSize; i++) {
    lastBlock.removeLast();
  }
  distRawFile.writeFromSync(lastBlock);

  print(lastBlock);
  await rawFile.close();
  await distRawFile.close();
}

printHex(Uint8List data) {
  print("================================");
  print("data length : ${data.length}");
  print(toHex(data));
}

toHex(Uint8List data) {
  return data.map((e) => e.toRadixString(16)).join();
}
