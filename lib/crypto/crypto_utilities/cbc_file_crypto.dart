import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

class CBCFileCrypto {
  static const blockSize = 16;
  static const chunkSizeInMegabytes = 3;
  static const numberOfBlocksInAChunk = 65536 * chunkSizeInMegabytes;
  static const chunkSize = blockSize * numberOfBlocksInAChunk; // 3mb chunk size
  static const paddingChar = 65;

  const CBCFileCrypto();

  Uint8List _readFile({
    required RandomAccessFile file,
    required int start,
    required int end,
  }) {
    file.setPositionSync(start);
    return file.readSync(end - start);
  }

  Uint8List _readChunk(RandomAccessFile file, int position) {
    return _readFile(
      file: file,
      start: position,
      end: position + chunkSize,
    );
  }

  encrypt({
    required File source,
    required File dest,
    required Uint8List key,
    required Uint8List iv,
  }) async {
    final encryptor = CBCBlockCipher(AESEngine());
    encryptor.init(
      true,
      ParametersWithIV(
        KeyParameter(key),
        iv,
      ),
    );
    final sorceFile = source.openSync();
    final totalBytes = sorceFile.lengthSync();
    final blockableBytesCount = totalBytes ~/ blockSize;
    final blockableBytes = blockableBytesCount * blockSize;
    final totalChunkCount = blockableBytes ~/ chunkSize;
    final destFile = dest.openSync(mode: FileMode.write);

    int position = 0;
    if (totalChunkCount > 0) {
      final cypherChunk = Uint8List(chunkSize);
      for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
        final chunk = _readChunk(sorceFile, position);
        position += chunkSize;
        int offset = 0;

        for (int blockIdx = 0; blockIdx < numberOfBlocksInAChunk; blockIdx++) {
          offset += encryptor.processBlock(chunk, offset, cypherChunk, offset);
        }
        destFile.writeFromSync(cypherChunk);
      }
    }

    if (position < blockableBytes) {
      List<int> bytes = _readFile(
        file: sorceFile,
        start: position,
        end: blockableBytes,
      );
      position = blockableBytes;
      final blocks = Uint8List.fromList(bytes);
      final cypherBlocks = Uint8List(blocks.length);
      final totalBlocks = blocks.length ~/ blockSize;
      int offset = 0;
      for (int blockIdx = 0; blockIdx < totalBlocks; blockIdx++) {
        offset += encryptor.processBlock(blocks, offset, cypherBlocks, offset);
      }
      destFile.writeFromSync(cypherBlocks);
    }
    int paddingSize = 0;
    if (position < totalBytes) {
      List<int> bytes = _readFile(
        file: sorceFile,
        start: position,
        end: totalBytes,
      );
      position = totalBytes;
      List<int> finalBytes = [];
      finalBytes.addAll(bytes);
      paddingSize = (blockSize - finalBytes.length);
      final endPosition = position + paddingSize;
      while (++position <= endPosition) {
        finalBytes.add(paddingChar);
      }
      final rowData = Uint8List.fromList(finalBytes);
      final cypherData = encryptor.process(rowData);
      destFile.writeFromSync(cypherData);
    }

    destFile.writeFromSync([paddingSize]);
    destFile.closeSync();
    sorceFile.closeSync();
    return true;
  }

  decrypt({
    required File source,
    required File dest,
    required Uint8List key,
    required Uint8List iv,
  }) async {
    final decryptor = CBCBlockCipher(AESEngine());
    decryptor.init(
      false,
      ParametersWithIV(
        KeyParameter(key),
        iv,
      ),
    );

    final sourceFile = source.openSync();
    int totalBytes = sourceFile.lengthSync();
    // last block contains the padding information
    final [paddingSize] = _readFile(
      file: sourceFile,
      start: totalBytes - 1,
      end: totalBytes,
    );
    totalBytes--;

    final blockableBytesCount = (totalBytes ~/ blockSize);
    final blockableBytes = blockableBytesCount * blockSize;
    assert(blockableBytes == totalBytes);
    int totalChunkCount = blockableBytes ~/ chunkSize;
    final totalChunkBytes = totalChunkCount * chunkSize;
    final lastBlockInLastChunk = totalChunkBytes == blockableBytes;
    if (lastBlockInLastChunk) {
      totalChunkCount--;
    }

    // clear the file
    final destFile = dest.openSync(mode: FileMode.write);
    int position = 0;

    if (totalChunkCount > 0) {
      final decypherChunk = Uint8List(chunkSize);
      for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
        final chunk = _readChunk(sourceFile, position);
        position += chunkSize;
        int offset = 0;
        for (int blockIdx = 0; blockIdx < numberOfBlocksInAChunk; blockIdx++) {
          offset += decryptor.processBlock(
            chunk,
            offset,
            decypherChunk,
            offset,
          );
        }
        destFile.writeFromSync(decypherChunk);
      }
    }

    final cypherBlocks = _readFile(
      file: sourceFile,
      start: position,
      end: blockableBytes,
    );
    position = blockableBytes;
    final decypherBlock = Uint8List(cypherBlocks.length);
    final numberOfBlocks = (cypherBlocks.length ~/ blockSize);
    int offset = 0;
    for (int blockIdx = 0; blockIdx < numberOfBlocks; blockIdx++) {
      offset += decryptor.processBlock(
        cypherBlocks,
        offset,
        decypherBlock,
        offset,
      );
    }

    destFile.writeFromSync(
      decypherBlock.sublist(0, decypherBlock.length - paddingSize),
    );

    destFile.closeSync();
    sourceFile.closeSync();
    return true;
  }
}
