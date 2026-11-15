import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/api_client.dart';

/// Central authentication service managing Supabase Auth lifecycle.
///
/// Features:
/// - Secure credentials extraction via compile-time environment flags (--dart-define)
/// - Graceful degradation to development mode if credentials are unconfigured
/// - Token provider integration for [ApiClient]
/// - Password-based login, registration, and logout
class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  bool _initialized = false;
  bool get isConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  bool get isInitialized => _initialized;

  /// Initialize Supabase Flutter SDK if credentials are provided.
  Future<void> initialize() async {
    ApiClient.defaultAuthTokenProvider = tokenProvider;

    if (!isConfigured) {
      _initialized = true;
      return;
    }
    if (!_initialized) {
      try {
        await Supabase.initialize(
          url: _supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: _supabaseAnonKey,
        );
      } catch (e) {
        // Trapping duplicate initialization or platform channel errors
      }
      _initialized = true;
    }
  }

  SupabaseClient? get _client {
    if (isConfigured && _initialized) {
      try {
        return Supabase.instance.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Session? get currentSession => _client?.auth.currentSession;
  User? get currentUser => _client?.auth.currentUser;
  bool get isAuthenticated => currentSession != null;

  String? get currentAccessToken => currentSession?.accessToken;

  /// Dynamic token provider callback suitable for passing to [ApiClient].
  AuthTokenProvider get tokenProvider => () async => currentAccessToken;

  Stream<AuthState> get onAuthStateChange =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInAnonymously() async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    return await client.auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}
