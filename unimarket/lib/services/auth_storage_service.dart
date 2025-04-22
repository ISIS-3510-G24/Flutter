import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorageService {
  static const _secureStorage = FlutterSecureStorage();
  static const _authBoxName = 'authBox';
  static const _emailKey = 'email';
  static const _passwordKey = 'password';

  static Future<void> saveCredentials(String email, String password) async {
    final authBox = await Hive.openBox(_authBoxName);
    await authBox.put(_emailKey, email);
    await _secureStorage.write(key: _passwordKey, value: password);
  }

  static Future<Map<String, String?>> getCredentials() async {
    final authBox = await Hive.openBox(_authBoxName);
    final email = authBox.get(_emailKey) as String?;
    final password = await _secureStorage.read(key: _passwordKey);
    return {'email': email, 'password': password};
  }

  static Future<void> clearCredentials() async {
    final authBox = await Hive.openBox(_authBoxName);
    await authBox.delete(_emailKey);
    await _secureStorage.delete(key: _passwordKey);
  }
}