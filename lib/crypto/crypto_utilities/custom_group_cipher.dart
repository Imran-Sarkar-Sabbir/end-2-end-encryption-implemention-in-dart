import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
// ignore: implementation_imports
import 'package:libsignal_protocol_dart/src/cbc.dart';

class CustomGroupCipher extends GroupCipher {
  final SenderKeyStore _senderKeyStore;
  final SenderKeyName _senderKeyId;

  final String Function(File file)? blobUploader;
  CustomGroupCipher(
    this._senderKeyStore,
    this._senderKeyId, {
    this.blobUploader,
  }) : super(_senderKeyStore, _senderKeyId);

  Future<Map> getFileEncryptionKeys({int fileCount = 1}) async {
    assert(fileCount > 0, "fileCount should be greater than 0");
    final encryptionKeyInfo = await _extractFileEncryptionKey();
    encryptionKeyInfo["files"] = [];
    for (int i = 0; i < fileCount; i++) {
      final fileKey = <String, dynamic>{
        "key": SecureRandom(32).bytes,
        "iv": SecureRandom(16).bytes,
      };
      encryptionKeyInfo["files"].add(fileKey);
    }
    return encryptionKeyInfo;
  }

  Future<Map> _extractFileEncryptionKey() async {
    try {
      final record = await _senderKeyStore.loadSenderKey(_senderKeyId);
      final senderKeyState = record.getSenderKeyState();
      final senderKey = senderKeyState.senderChainKey.senderMessageKey;

      Map result = {
        "messageKey": senderKey.cipherKey,
        "messageIV": senderKey.iv,
        "keyId": senderKeyState.keyId,
        "iteration": senderKey.iteration,
        "signPrivate": senderKeyState.signingKeyPrivate.serialize(),
      };

      final nextSenderChainKey = senderKeyState.senderChainKey.next;
      await _senderKeyStore.storeSenderKey(_senderKeyId, record);
      senderKeyState.senderChainKey = nextSenderChainKey;
      return result;
    } on InvalidKeyIdException catch (e) {
      throw NoSessionException(e.detailMessage);
    }
  }

  encryptFileInfo(Map keys) async {
    try {
      final messageKey = keys["messageKey"];
      final messageIV = keys["messageIV"];
      keys.remove("messageKey");
      keys.remove("messageIV");
      final msg = jsonEncode(keys).codeUnits;
      final ciphertext = aesCbcEncrypt(
        messageKey,
        messageIV,
        Uint8List.fromList(msg),
      );
      final senderKeyMessage = SenderKeyMessage(
        keys["keyId"],
        keys["iteration"],
        ciphertext,
        Curve.decodePrivatePoint((keys["signPrivate"])),
      );
      return senderKeyMessage.serialize();
    } on InvalidKeyIdException catch (e) {
      throw NoSessionException(e.detailMessage);
    }
  }
}
