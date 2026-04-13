import 'package:campus_baloncesto_app/core/models/user_model.dart';
import 'package:campus_baloncesto_app/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider for Supabase Client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthRepository(supabase);
});

// Stream Provider for Auth State changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

// Future Provider to fetch the current user's profile
final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  // Watch auth state to react to login/logout
  final authStateAsync = ref.watch(authStateProvider);
  final user = authStateAsync.value?.session?.user ?? Supabase.instance.client.auth.currentUser;
  
  if (user == null) return null;
  
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getUserProfile(user.id);
});
