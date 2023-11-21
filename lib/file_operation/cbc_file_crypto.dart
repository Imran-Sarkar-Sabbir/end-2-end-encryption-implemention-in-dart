import 'dart:io';
import 'dart:typed_data';
import 'package:end2end/file_operation/read_file.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

class CBCFileCrypto {
  static const blockSize = 16;
  static const numberOfBlocksInAChunk = 65536;
  static const chunkSize =
      blockSize * numberOfBlocksInAChunk * 3; // 3mb chunk su

  const CBCFileCrypto();

  final iv = "aaaaaaaaaaaaaaaa";
  encrypt({
    required File targetFile,
    required File destinationFile,
    required String key,
  }) async {
    RandomAccessFile rawFile = targetFile.openSync();
    RandomAccessFile distRawFile =
        destinationFile.openSync(mode: FileMode.write);

    final encryptor = CBCBlockCipher(AESEngine());
    encryptor.init(
      true,
      ParametersWithIV(
        KeyParameter(Uint8List.fromList(key.codeUnits)),
        Uint8List.fromList(iv.codeUnits),
      ),
    );

    final totalBytes = targetFile.lengthSync();
    final blockableBytesCount = totalBytes ~/ blockSize;
    final blockableBytes = blockableBytesCount * blockSize;
    final totalChunkCount = blockableBytes ~/ chunkSize;

    int position = 0;
    final cypherChunk = Uint8List(chunkSize);
    for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
      rawFile.setPositionSync(position);
      position += chunkSize;
      List<int> bytes = await rawFile.read(position);
      final chunk = Uint8List.fromList(bytes);
      for (int blockIdx = 0; blockIdx < numberOfBlocksInAChunk; blockIdx++) {
        final offset = blockIdx * blockSize;
        encryptor.processBlock(chunk, offset, cypherChunk, offset);
      }
      distRawFile.writeFromSync(cypherChunk);
    }

    if (position < blockableBytes) {
      rawFile.setPositionSync(position);
      position = blockableBytes;
      List<int> bytes = await rawFile.read(position);
      final blocks = Uint8List.fromList(bytes);
      final cypherBlocks = Uint8List(blocks.length);
      final totalBlocks = blocks.length ~/ blockSize;
      for (int blockIdx = 0; blockIdx < totalBlocks; blockIdx++) {
        final blockOffSet = blockIdx * blockSize;
        encryptor.processBlock(blocks, blockOffSet, cypherBlocks, blockOffSet);
      }
      printHex(blocks);
      printHex(cypherBlocks);
      distRawFile.writeFromSync(cypherBlocks);
    }

    int paddingSize = 0;
    if (position < totalBytes) {
      rawFile.setPositionSync(position);
      position = totalBytes;
      List<int> bytes = await rawFile.read(position);
      List<int> finalBytes = [];
      finalBytes.addAll(bytes);
      paddingSize = (blockSize - finalBytes.length);
      final endPosition = position + paddingSize;
      while (++position <= endPosition) {
        finalBytes.add(0);
      }
      final rowData = Uint8List.fromList(finalBytes);
      final cypherData = encryptor.process(rowData);
      distRawFile.writeFromSync(cypherData);
    }

    distRawFile.writeFromSync([paddingSize]);
    await rawFile.close();
    await distRawFile.close();
    return true;
  }

  decrypt({
    required File targetFile,
    required File destinationFile,
    required String key,
  }) async {
    RandomAccessFile rawFile = targetFile.openSync();
    RandomAccessFile distRawFile =
        destinationFile.openSync(mode: FileMode.write);

    final decryptor = CBCBlockCipher(AESEngine());
    decryptor.init(
      false,
      ParametersWithIV(
        KeyParameter(Uint8List.fromList(key.codeUnits)),
        Uint8List.fromList(iv.codeUnits),
      ),
    );

    int totalBytes = targetFile.lengthSync();
    rawFile.setPositionSync(totalBytes - 1);

    final [paddingSize] = await rawFile.read(totalBytes);
    totalBytes--;

    final blockableBytesCount = (totalBytes ~/ blockSize) - 1;
    final blockableBytes = blockableBytesCount * blockSize;
    final totalChunkCount = blockableBytes ~/ chunkSize;

    int position = 0;

    final decypherChunk = Uint8List(chunkSize);
    for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
      rawFile.setPositionSync(position);
      position += chunkSize;
      List<int> bytes = await rawFile.read(position);
      final chunk = Uint8List.fromList(bytes);
      for (int blockIdx = 0; blockIdx < numberOfBlocksInAChunk; blockIdx++) {
        final offset = blockIdx * blockSize;
        decryptor.processBlock(chunk, offset, decypherChunk, offset);
      }
      distRawFile.writeFromSync(decypherChunk);
    }

    if (position < blockableBytes) {
      rawFile.setPositionSync(position);
      position = blockableBytes;
      List<int> bytes = await rawFile.read(position);
      final blocks = Uint8List.fromList(bytes);
      final cypherBlocks = Uint8List(blocks.length);
      final totalBlocks = blocks.length ~/ blockSize;
      for (int blockIdx = 0; blockIdx < totalBlocks; blockIdx++) {
        final blockOffSet = blockIdx * blockSize;
        decryptor.processBlock(blocks, blockOffSet, cypherBlocks, blockOffSet);
      }
      distRawFile.writeFromSync(cypherBlocks);
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

    await rawFile.close();
    await distRawFile.close();
    return true;
  }
}
