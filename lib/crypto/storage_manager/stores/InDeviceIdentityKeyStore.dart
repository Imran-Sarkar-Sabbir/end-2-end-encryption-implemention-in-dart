import 'package:end2end/crypto/storage_manager/key_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:libsignal_protocol_dart/src/eq.dart';

class InDeviceIdentityKeyStore extends IdentityKeyStore {
  static InDeviceIdentityKeyStore? _instance;
  static const _identityKeyPortion = "identity_";
  static const _trustedKeyPortion = "trusted_";

  static const _keyIdentity = "identity_key";
  static const _keyRegistration = "registration_key";

  final IdentityKeyPair identityKeyPair;
  final int localRegistrationId;
  final KeyStorage store;

  InDeviceIdentityKeyStore(
    this.identityKeyPair,
    this.localRegistrationId,
    this.store,
  ) {
    if (_instance != null) {
      throw Exception("InDeviceIdentityKeyStore already initialized");
    }
    _instance = this;
  }

  static Future<InDeviceIdentityKeyStore?> retrive(KeyStorage store) async {
    if (_instance != null) return _instance;
    final identityData = await store.retrieve(
      key: _keyIdentity,
      partition: _identityKeyPortion,
    );

    final registrationId = await store.retrieve(
      key: _keyRegistration,
      partition: _identityKeyPortion,
    );

    if (identityData != null && registrationId != null) {
      return InDeviceIdentityKeyStore(
        IdentityKeyPair.fromSerialized(identityData),
        registrationId,
        store,
      );
    }
    return null;
  }

  Future save() async {
    await store.store(
      key: _keyIdentity,
      value: identityKeyPair.serialize(),
      partition: _identityKeyPortion,
    );

    await store.store(
      key: _keyRegistration,
      value: localRegistrationId,
      partition: _identityKeyPortion,
    );
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final identityData = await store.retrieve(
      key: address.toString(),
      partition: _trustedKeyPortion,
    );
    if (identityData == null) return null;
    return IdentityKey.fromBytes(identityData, 0);
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async => identityKeyPair;

  @override
  Future<int> getLocalRegistrationId() async => localRegistrationId;

  @override
  Future<bool> isTrustedIdentity(SignalProtocolAddress address,
      IdentityKey? identityKey, Direction? direction) async {
    final trusted = await getIdentity(address);
    if (identityKey == null) {
      return false;
    }
    return trusted == null || eq(trusted.serialize(), identityKey.serialize());
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    final existing = await getIdentity(address);
    if (identityKey == null) {
      return false;
    }
    if (identityKey != existing) {
      await store.store(
        key: address.toString(),
        value: identityKey.serialize(),
        partition: _trustedKeyPortion,
      );
      return true;
    } else {
      return false;
    }
  }
}
