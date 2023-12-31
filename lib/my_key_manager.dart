import 'dart:convert';

import 'package:end2end/crypto/managers/key_manager.dart';
import 'package:http/http.dart' as http;

const bool isMyUser = false;

const myId = isMyUser ? "userA" : "userB";
const otherId = !isMyUser ? "userA" : "userB";

final myKeyManager = KeyManager(
  identityKeySender: identityKeySender,
  signedPreKeySender: signedPreKeySender,
  preKeySender: preKeySender,
);

Future<bool> identityKeySender(Map<String, dynamic> key) async {
  try {
    await apiPost("/identityKey/$myId", key);
    return true;
  } catch (e) {
    print(e);
    return false;
  }
}

Future<bool> signedPreKeySender(Map<String, dynamic> key) async {
  try {
    await apiPost("/signedPreKey/$myId", key);
    return true;
  } catch (e) {
    print(e);
    return false;
  }
}

Future<bool> preKeySender(Map<String, dynamic> key) async {
  try {
    await apiPost("/preKey/$myId", key);
    return true;
  } catch (e) {
    print(e);
    return false;
  }
}

const basePath = "localhost:12345";

apiPost(String apiEndPoint, dynamic body) async {
  print("post: $basePath$apiEndPoint");
  await http.post(
    Uri.http(basePath, apiEndPoint),
    body: jsonEncode(body),
    headers: {"content-type": "application/json"},
  );
}

apiGet(
  String apiEndPoint,
) async {
  print("get: $basePath$apiEndPoint");
  final response = await http.get(
    Uri.http(basePath, apiEndPoint),
  );
  if (response.statusCode >= 400) throw Exception("API error: ");
  return response.body;
}
