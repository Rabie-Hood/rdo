import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  final plain = File('lst_rdo.json').readAsBytesSync();
  // clé 32 bytes – stockée nulle part dans le repo
  final key = Key.fromUtf8('MyVeryLong32BytesSecretKey123456'); // 32 car
  final iv  = IV.fromSecureRandom(12);                           // GCM 96 bits
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));

  final encrypted = encrypter.encryptBytes(plain, iv: iv);
  final out = File('assets/lst_rdo.aes');
  out.createSync(recursive: true);
  out.writeAsBytesSync([
    ...iv.bytes,          // 12 premiers octets
    ...encrypted.bytes,   // le reste
  ]);
  print('✅ chiffré : ${out.path}');
}