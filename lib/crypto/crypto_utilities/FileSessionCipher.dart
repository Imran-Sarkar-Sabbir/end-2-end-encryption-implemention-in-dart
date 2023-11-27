// ignore_for_file: file_names

import 'package:encrypt/encrypt.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class CustomSessionCipher extends SessionCipher {
  final SessionStore _sessionStore;
  final PreKeyStore _preKeyStore;
  final SignedPreKeyStore _signedPreKeyStore;
  final IdentityKeyStore _identityKeyStore;
  final SignalProtocolAddress _remoteAddress;

  CustomSessionCipher(
    this._sessionStore,
    this._preKeyStore,
    this._signedPreKeyStore,
    this._identityKeyStore,
    this._remoteAddress,
  ) : super(
          _sessionStore,
          _preKeyStore,
          _signedPreKeyStore,
          _identityKeyStore,
          _remoteAddress,
        );

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
    return {};
    // final sessionRecord = await _sessionStore.loadSession(_remoteAddress);
    // final sessionState = sessionRecord.sessionState;
    // final chainKey = sessionState.getSenderChainKey();
    // final messageKeys = chainKey.getMessageKeys();
    // final senderEphemeral = sessionState.getSenderRatchetKey();
    // final previousCounter = sessionState.previousCounter;
    // final sessionVersion = sessionState.getSessionVersion();

    // CiphertextMessage ciphertextMessage = SignalMessage(
    //     sessionVersion,
    //     messageKeys.getMacKey(),
    //     senderEphemeral,
    //     chainKey.index,
    //     previousCounter,
    //     ciphertextBody,
    //     sessionState.getLocalIdentityKey(),
    //     sessionState.getRemoteIdentityKey());
    // if (sessionState.hasUnacknowledgedPreKeyMessage()) {
    //   final items = sessionState.getUnacknowledgedPreKeyMessageItems();
    //   final localRegistrationId = sessionState.localRegistrationId;

    //   ciphertextMessage = PreKeySignalMessage.from(
    //       sessionVersion,
    //       localRegistrationId,
    //       items.getPreKeyId(),
    //       items.getSignedPreKeyId(),
    //       items.getBaseKey(),
    //       sessionState.getLocalIdentityKey(),
    //       ciphertextMessage as SignalMessage);
    // }

    // final nextChainKey = chainKey.getNextChainKey();
    // sessionState.setSenderChainKey(nextChainKey);

    // if (!await _identityKeyStore.isTrustedIdentity(_remoteAddress,
    //     sessionState.getRemoteIdentityKey(), Direction.sending)) {
    //   throw UntrustedIdentityException(
    //       _remoteAddress.getName(), sessionState.getRemoteIdentityKey());
    // }

    // await _identityKeyStore.saveIdentity(
    //     _remoteAddress, sessionState.getRemoteIdentityKey());
    // await _sessionStore.storeSession(_remoteAddress, sessionRecord);
    // return ciphertextMessage;
  }
}
