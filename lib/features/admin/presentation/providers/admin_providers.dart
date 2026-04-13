import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../core/models/user_model.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AdminRepository(supabase);
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getAllUsers();
});
