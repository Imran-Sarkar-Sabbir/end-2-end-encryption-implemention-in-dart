import 'package:end2end/my_key_manager.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

Future<void> installE2EE() async {
  await myKeyManager.init();
  await myKeyManager.install();

  await fetchMessages();
  await sendMessages();
}

fetchMessages() async {
  final response = await apiGet("/messages/$myId");
  print(response);
}

sendMessages() async {
  final response = await apiPost(
    "/messages/$otherId",
    "this is my message",
  );
  print(response);
}

// void sendKeysToRemote() {
//   final preKeyId = 0;
//   final preKey = PreKeyRecord.fromBuffer(
//     myKeyManager.preKeyStore!.store[preKeyId]!,
//   );

//   final signPreKeyId = myKeyManager.signedPreKeyStore!.store.keys.first;
//   final signPreKey = SignedPreKeyRecord.fromSerialized(
//     myKeyManager.signedPreKeyStore!.store[signPreKeyId]!,
//   );

//   final myGeneratedKey = {
//     "remoteRegId": myKeyManager.identityStore!.localRegistrationId,
//     "deviceId": 1,
//     "preKeyId": preKeyId,
//     "preKeyPublic": preKey.getKeyPair().publicKey.serialize(),
//     "signedPreKeyId": signPreKeyId,
//     "signedPreKeyPublic": signPreKey.getKeyPair().publicKey.serialize(),
//     "signPreSignature": signPreKey.signature,
//     "identityPublic":
//         myKeyManager.identityStore!.identityKeyPair.getPublicKey().serialize(),
//   };

//   print(myGeneratedKey);
// }
