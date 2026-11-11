import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

bool get isGoogleAuthConfigured =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

bool _isGoogleAuthReady = false;
Object? _googleAuthInitializationError;
Future<void>? _initialization;
bool _nativeHandlerInstalled = false;
final _authUris = StreamController<Uri>.broadcast();
const _authChannel = MethodChannel('com.scenora.scenora/auth');

class _SecurePkceStorage extends GotrueAsyncStorage {
  const _SecurePkceStorage();

  static const _storage = FlutterSecureStorage();

  String _key(String key) => 'scenora_supabase_pkce_$key';

  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: _key(key));

  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: _key(key));

  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: _key(key), value: value);
}

class _SecureSessionStorage extends LocalStorage {
  const _SecureSessionStorage();

  static const _storage = FlutterSecureStorage();
  static const _key = 'scenora_supabase_auth_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<bool> hasAccessToken() async =>
      (await _storage.read(key: _key))?.isNotEmpty == true;

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

Future<void> initializeGoogleAuth() async {
  if (!isGoogleAuthConfigured || _isGoogleAuthReady) return;
  final pending = _initialization;
  if (pending != null) return pending;
  final operation = _initializeGoogleAuth();
  _initialization = operation;
  try {
    await operation;
  } finally {
    if (identical(_initialization, operation)) _initialization = null;
  }
}

Future<void> _initializeGoogleAuth() async {
  try {
    await _installNativeAuthHandler();
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        detectSessionInUri: false,
        pkceAsyncStorage: _SecurePkceStorage(),
        localStorage: _SecureSessionStorage(),
      ),
    );
    _isGoogleAuthReady = true;
    _googleAuthInitializationError = null;
  } on Object catch (error) {
    _isGoogleAuthReady = false;
    _googleAuthInitializationError = error;
  }
}

Future<void> _installNativeAuthHandler() async {
  if (_nativeHandlerInstalled) return;
  _nativeHandlerInstalled = true;
  _authChannel.setMethodCallHandler((call) async {
    if (call.method == 'onAuthUri' && call.arguments is String) {
      final uri = Uri.tryParse(call.arguments as String);
      if (uri != null) _authUris.add(uri);
    }
  });
  try {
    final value = await _authChannel.invokeMethod<String>('getInitialAuthUri');
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri != null) _authUris.add(uri);
  } on MissingPluginException {
    // Google OAuth is Android-only in this build.
  } on PlatformException {
    // The button press can still retry after the app finishes starting.
  }
}

Future<String> signInWithGoogle() async {
  if (!isGoogleAuthConfigured) {
    throw const GoogleAuthException(
      'Google Sign-In needs the Supabase URL and publishable key.',
    );
  }
  await initializeGoogleAuth();
  if (!_isGoogleAuthReady) {
    final detail = _googleAuthInitializationError == null
        ? ''
        : ': ${_googleAuthInitializationError.toString()}';
    throw GoogleAuthException('Google Sign-In could not initialize$detail');
  }

  final auth = Supabase.instance.client.auth;
  final existing = auth.currentSession;
  if (existing != null && !existing.isExpired) return existing.accessToken;

  final callbackFuture = _authUris.stream.first.timeout(
    const Duration(minutes: 2),
  );
  final launched = await auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'scenora://login-callback/',
  );
  if (!launched) {
    throw const GoogleAuthException('Could not open Google Sign-In.');
  }
  try {
    final callback = await callbackFuture;
    final response = await auth.getSessionFromUrl(callback);
    return response.session.accessToken;
  } on TimeoutException {
    throw const GoogleAuthException('Google Sign-In timed out. Try again.');
  } on AuthException catch (error) {
    throw GoogleAuthException(error.message);
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
