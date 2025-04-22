import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const _emailKey = 'biometric_email';
  static const _passwordKey = 'biometric_password';

  static Future<bool> get hasBiometrics async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your account',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasSavedCredentials() async {
    final creds = await getSavedCredentials();
    return creds['email'] != null && creds['password'] != null;
  }


  static Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      return {'email': email, 'password': password};
    } catch (e) {
      print('Error reading credentials: $e');
      return {'email': null, 'password': null};
    }
  }

  static Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      print('Credentials saved successfully');
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'biometric_email');
    await _secureStorage.delete(key: 'biometric_password');
  }
}