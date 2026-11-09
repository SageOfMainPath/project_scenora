import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHash {
  const PasswordHash({required this.salt, required this.hash});

  final String salt;
  final String hash;
}

class SecurityService {
  SecurityService({String? pepper})
    : _pepper =
          pepper ??
          const String.fromEnvironment(
            'SCENORA_TOKEN_PEPPER',
            defaultValue: 'scenora-local-development-pepper',
          );

  final Random _random = Random.secure();
  final String _pepper;

  PasswordHash hashPassword(String password, {String? salt}) {
    final saltValue = salt ?? randomToken(16);
    final hmac = Hmac(sha256, utf8.encode(password));
    final saltBytes = utf8.encode(saltValue);
    var block = hmac.convert([...saltBytes, 0, 0, 0, 1]).bytes;
    final derived = List<int>.from(block);
    for (var i = 1; i < 30000; i++) {
      block = hmac.convert(block).bytes;
      for (var byte = 0; byte < derived.length; byte++) {
        derived[byte] ^= block[byte];
      }
    }
    return PasswordHash(
      salt: saltValue,
      hash: base64UrlEncode(derived).replaceAll('=', ''),
    );
  }

  bool verifyPassword(String password, String salt, String expectedHash) {
    final actual = hashPassword(password, salt: salt).hash;
    if (actual.length != expectedHash.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return difference == 0;
  }

  String randomToken([int bytes = 32]) {
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String tokenHash(String token) =>
      sha256.convert(utf8.encode('$token:$_pepper')).toString();
}
