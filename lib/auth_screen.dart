import 'package:echonotes/google_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(googleAuthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Google Auth')),
      body: Center(
        child: switch (authState) {
          GoogleAuthInitial() => _buildSignInButton(ref),
          GoogleAuthLoading() => const CircularProgressIndicator(),
          GoogleAuthAuthenticated(:final user) => _buildUserProfile(user, ref),
          GoogleAuthError(:final message) => _buildErrorUI(message, ref),
        },
      ),
    );
  }

  Widget _buildSignInButton(WidgetRef ref) {
    return FilledButton(
      onPressed: () => ref.read(googleAuthProvider.notifier).signIn(),
      child: const Text('Sign In with Google'),
    );
  }

  Widget _buildUserProfile(GoogleSignInAccount user, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          radius: 40,
        ),
        const SizedBox(height: 16),
        Text(user.displayName ?? 'No name'),
        Text(user.email),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => ref.read(googleAuthProvider.notifier).signOut(),
          child: const Text('Sign Out'),
        ),
      ],
    );
  }

  Widget _buildErrorUI(String message, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => ref.read(googleAuthProvider.notifier).signIn(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
