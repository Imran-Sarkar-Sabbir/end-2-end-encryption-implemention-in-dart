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

  Future<Uint8List> _readFile({
    required File file,
    required int start,
    required int end,
  }) async {
    final fileStream = file.openRead(start, end);
    final listOfBytes = (await fileStream.toList()).expand(
      (element) => element,
    );
    return Uint8List.fromList(listOfBytes.toList());
  }

  Future<Uint8List> _readChunk(File file, int position) async {
    return _readFile(file: file, start: position, end: position + chunkSize);
  }

  encrypt({
    required File targetFile,
    required File destinationFile,
    required String key,
    required String iv,
  }) async {
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
    destinationFile.writeAsBytesSync([], flush: true, mode: FileMode.write);

    int position = 0;
    if (totalChunkCount > 0) {
      final cypherChunk = Uint8List(chunkSize);
      for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
        final chunk = await _readChunk(targetFile, position);
        position += chunkSize;
        int offset = 0;
        for (int blockIdx = 0; blockIdx < numberOfBlocksInAChunk; blockIdx++) {
          offset += encryptor.processBlock(chunk, offset, cypherChunk, offset);
        }
        destinationFile.writeAsBytesSync(
          cypherChunk,
          mode: FileMode.append,
          flush: true,
        );
      }
    }

    if (position < blockableBytes) {
      List<int> bytes = await _readFile(
        file: targetFile,
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
      destinationFile.writeAsBytesSync(
        cypherBlocks,
        mode: FileMode.append,
        flush: true,
      );
    }
    int paddingSize = 0;
    if (position < totalBytes) {
      List<int> bytes = await _readFile(
        file: targetFile,
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
      destinationFile.writeAsBytesSync(
        cypherData,
        mode: FileMode.append,
        flush: true,
      );
    }

    destinationFile.writeAsBytesSync(
      [paddingSize],
      mode: FileMode.append,
      flush: true,
    );
    return true;
  }

  decrypt({
    required File targetFile,
    required File destinationFile,
    required String key,
    required String iv,
  }) async {
    final decryptor = CBCBlockCipher(AESEngine());
    decryptor.init(
      false,
      ParametersWithIV(
        KeyParameter(Uint8List.fromList(key.codeUnits)),
        Uint8List.fromList(iv.codeUnits),
      ),
    );

    int totalBytes = targetFile.lengthSync();
    final [paddingSize] = await _readFile(
      file: targetFile,
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
    destinationFile.writeAsBytesSync([], mode: FileMode.write, flush: true);
    int position = 0;

    if (totalChunkCount > 0) {
      final decypherChunk = Uint8List(chunkSize);
      for (int chunkIdx = 0; chunkIdx < totalChunkCount; chunkIdx++) {
        final chunk = await _readChunk(targetFile, position);
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
        destinationFile.writeAsBytesSync(
          decypherChunk,
          mode: FileMode.append,
          flush: true,
        );
      }
    }

    final cypherBlocks = await _readFile(
      file: targetFile,
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
    destinationFile.writeAsBytesSync(
      decypherBlock.sublist(0, decypherBlock.length - paddingSize),
      mode: FileMode.append,
      flush: true,
    );
    return true;
  }
}
