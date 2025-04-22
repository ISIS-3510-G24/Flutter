import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
    final email = await _secureStorage.read(key: 'biometric_email');
    final password = await _secureStorage.read(key: 'biometric_password');
    return email != null && password != null;
  }

  static Future<Map<String, String?>> getSavedCredentials() async {
    return {
      'email': await _secureStorage.read(key: 'biometric_email'),
      'password': await _secureStorage.read(key: 'biometric_password'),
    };
  }

  static Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'biometric_email', value: email);
    await _secureStorage.write(key: 'biometric_password', value: password);
  }

  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'biometric_email');
    await _secureStorage.delete(key: 'biometric_password');
  }
}