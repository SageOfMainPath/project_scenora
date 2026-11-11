import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

bool get isGoogleAuthConfigured =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

Future<void> initializeGoogleAuth() async {
  if (!isGoogleAuthConfigured) return;
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
}

Future<String> signInWithGoogle() async {
  if (!isGoogleAuthConfigured) {
    throw const GoogleAuthException(
      'Google Sign-In needs the Supabase URL and publishable key.',
    );
  }
  final auth = Supabase.instance.client.auth;
  final existing = auth.currentSession;
  if (existing != null && !existing.isExpired) return existing.accessToken;

  final sessionFuture = auth.onAuthStateChange
      .firstWhere((state) => state.session != null)
      .then((state) => state.session!)
      .timeout(const Duration(minutes: 2));
  final launched = await auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'scenora://login-callback/',
  );
  if (!launched) {
    throw const GoogleAuthException('Could not open Google Sign-In.');
  }
  try {
    return (await sessionFuture).accessToken;
  } on TimeoutException {
    throw const GoogleAuthException('Google Sign-In timed out. Try again.');
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
