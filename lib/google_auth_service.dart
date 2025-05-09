import 'dart:async';
import 'package:echonotes/speech_to_text.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/docs/v1.dart' as docs;

import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

//  Constants & Configuration
const _scopes = [
  'email',
  'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/documents',
  'https://www.googleapis.com/auth/drive.file',
];

final _secureStorage = const FlutterSecureStorage();

// State Notifier (Riverpod)
class GoogleAuthNotifier extends StateNotifier<GoogleAuthState> {
  final GoogleSignIn _googleSignIn;

  GoogleAuthNotifier()
    : _googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? dotenv.env['GOOGLE_CLIENT_ID'] : null,
        scopes: _scopes,
        serverClientId: !kIsWeb ? dotenv.env['GOOGLE_SERVER_CLIENT_ID'] : null,
      ),
      super(GoogleAuthInitial()) {
    // Attempt silent sign-in when the notifier is created
    silentSignIn();
  }

  Future<void> signIn() async {
    try {
      state = const GoogleAuthLoading();

      final account = await _googleSignIn.signIn();

      if (account == null) {
        state = const GoogleAuthError('Sign-in cancelled');
        return;
      }

      debugPrint('Sign-in successful with account: ${account.email}');

      final authClient = await _getValidAuthClient(account);
      if (authClient == null) {
        state = const GoogleAuthError('Failed to get valid credentials');
        return;
      }

      await _persistToken(authClient.credentials.accessToken.data);
      state = GoogleAuthAuthenticated(account, authClient);
    } catch (e, s) {
      // More detailed error logging
      debugPrint('SignIn error type: ${e.runtimeType}');
      debugPrint('SignIn error message: $e');
      debugPrint('Stack trace: $s');

      // Handle specific error types
      if (e.toString().contains('10:')) {
        state = const GoogleAuthError(
          'Authentication configuration error. Please check your Google Cloud Console setup.',
        );
      } else {
        state = GoogleAuthError(e.toString());
      }
    }
  }

  Future<void> signOut() async {
    try {
      state = const GoogleAuthLoading();
      await _googleSignIn.disconnect();
      await _secureStorage.delete(key: 'oauth_token');
      state = const GoogleAuthInitial();
    } catch (e, s) {
      debugPrint('SignOut error: $e\n$s');
      state = const GoogleAuthError('Sign out failed');
    }
  }

  Future<auth.AuthClient?> _getValidAuthClient(
    GoogleSignInAccount account,
  ) async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        return null;
      }

      if (!await _validateToken(client)) {
        try {
          await _googleSignIn.signInSilently(suppressErrors: false);
          final refreshedClient = await _googleSignIn.authenticatedClient();
          if (refreshedClient != null &&
              await _validateToken(refreshedClient)) {
            return refreshedClient;
          }
        } catch (e) {
          debugPrint('Token refresh error: $e');
        }
        return null;
      }

      return client;
    } catch (e) {
      debugPrint('AuthClient error: $e');
      return null;
    }
  }

  Future<bool> _validateToken(auth.AuthClient client) async {
    final expiry = client.credentials.accessToken.expiry;
    return expiry.isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  Future<void> _persistToken(String token) async {
    await _secureStorage.write(key: 'oauth_token', value: token);
  }

  Future<void> silentSignIn() async {
    try {
      state = const GoogleAuthLoading();
      final storedToken = await _secureStorage.read(key: 'oauth_token');
      if (storedToken == null) {
        final account = await _googleSignIn.signInSilently();
        if (account == null) {
          state = const GoogleAuthInitial();
          return;
        }

        final authClient = await _getValidAuthClient(account);
        if (authClient != null) {
          state = GoogleAuthAuthenticated(account, authClient);
        } else {
          state = const GoogleAuthInitial();
        }
      } else {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          final authClient = await _getValidAuthClient(account);
          if (authClient != null) {
            state = GoogleAuthAuthenticated(account, authClient);
            return;
          }
        }
        await _secureStorage.delete(key: 'oauth_token');
        state = const GoogleAuthInitial();
      }
    } catch (e) {
      debugPrint('SilentSignIn error: $e');
      state = const GoogleAuthInitial();
    }
  }
}

//  State Definitions
sealed class GoogleAuthState {
  const GoogleAuthState();
}

class GoogleAuthInitial extends GoogleAuthState {
  const GoogleAuthInitial();
}

class GoogleAuthLoading extends GoogleAuthState {
  const GoogleAuthLoading();
}

class GoogleAuthAuthenticated extends GoogleAuthState {
  final GoogleSignInAccount user;
  final auth.AuthClient client;

  const GoogleAuthAuthenticated(this.user, this.client);
}

class GoogleAuthError extends GoogleAuthState {
  final String message;
  const GoogleAuthError(this.message);
}

//  Provider Setup
final googleAuthProvider =
    StateNotifierProvider<GoogleAuthNotifier, GoogleAuthState>((ref) {
      return GoogleAuthNotifier();
    });

//  Google Docs Service
class GoogleDocsService {
  static docs.DocsApi? _cachedDocsApi;

  Future<docs.DocsApi> getDocsApi(auth.AuthClient client) async {
    return _cachedDocsApi ??= docs.DocsApi(client);
  }

  Future<String?> createDocument(auth.AuthClient client, String title) async {
    try {
      final docsApi = await getDocsApi(client);
      final document = docs.Document()..title = title;
      final createdDoc = await docsApi.documents.create(document);
      return createdDoc.documentId;
    } catch (e, s) {
      debugPrint('CreateDoc error: $e\n$s');
      return null;
    }
  }

  Future<docs.Document?> getDocument(
    auth.AuthClient client,
    String documentId,
  ) async {
    try {
      final docsApi = await getDocsApi(client);
      return await docsApi.documents.get(documentId);
    } catch (e, s) {
      debugPrint('GetDoc error: $e\n$s');
      return null;
    }
  }

  void clearCache() {
    _cachedDocsApi = null;
  }
}

//  AuthGate for Navigation
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(googleAuthProvider);

    ref.listen<GoogleAuthState>(googleAuthProvider, (prev, next) {
      if (next is GoogleAuthAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SendMessage()),
            (route) => false,
          );
        });
      }
    });

    return switch (authState) {
      GoogleAuthInitial() => const Scaffold(
        body: Center(child: Text('Not signed in')),
      ),
      GoogleAuthLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      GoogleAuthAuthenticated() => const Scaffold(
        body: Center(child: Text('Redirecting...')),
      ),
      GoogleAuthError(:final message) => Scaffold(
        body: Center(child: Text('Error: $message')),
      ),
    };
  }
}
