// tool/encrypt_json.dart
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  ///********** */
  final plainFile = File('.github/workflows/lst_rdo.json');
  print('>>> Reading file | lst_rdo.json | : ${plainFile.absolute.path}');
  print('>>> File exists  | lst_rdo.json | : ${plainFile.existsSync()}');
  print('>>> File length  | lst_rdo.json | : ${plainFile.lengthSync()}');
  if (!plainFile.existsSync()) {
    print('❌ lst_rdo.json introuvable');
    return;
  }

  ///********* */

  final plain = File('.github/workflows/lst_rdo.json').readAsBytesSync();
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

  /*  ===  INFOS lst_rdo.aes  ===  */
  final aesLen = out.lengthSync();
  final digest = sha256.convert(out.readAsBytesSync());
  print('>>> AES file length |lst_rdo.aes| : $aesLen');
  print('>>> AES SHA-256     |lst_rdo.aes| : $digest');
  print('>>> IV (hex)        |lst_rdo.aes| : ${iv.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

  print('✅ chiffré : ${out.path}');
}