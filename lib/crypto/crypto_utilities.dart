import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

String getAddressName(String address) {
  final temp = address.split(":");
  return temp[0];
}

SignalProtocolAddress getAddress(String address) {
  final temp = address.split(":");
  return SignalProtocolAddress(temp[0], int.parse(temp[1]));
}
