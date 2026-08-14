import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/login_model.dart';
import 'package:social_app/models/registration_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/auth_repository.dart';

part 'auth_state.dart';
part 'auth_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<RegisterEvent>(_processRegistration, transformer: droppable());
    on<LoginEvent>(_processLogin, transformer: droppable());
    on<FetchAuthenticatedUserEvent>(_processGetAuthUser, transformer: droppable());
    on<LogoutEvent>(_processLogout, transformer: droppable());
  }

  final AuthRepository _repo = getIt<AuthRepository>();

  Future<void> _processRegistration(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final result = await _repo.register(event.data);
      emit(AuthLoadedState(result.user));
    } catch (e) {
      final message = e is AppException ? e.message : 'Registration Failed';
      emit(AuthErrorState(message));
    }
  }

  Future<void> _processLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoadingState());
    try {
      final result = await _repo.login(event.data);
      emit(AuthLoadedState(result.user));
    } catch (e) {
      final message = e is AppException ? e.message : 'Authentication Failed';
      emit(AuthErrorState(message));
    }
  }

  Future<void> _processLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      await _repo.logout();
    } catch (_) {
      // AuthRepository.logout() clears local tokens/cache in its `finally`
      // regardless of outcome, so the session is gone locally either way —
      // a failed server-side revoke shouldn't block the state transition.
    }
    emit(const AuthUnauthenticatedState());
  }

  Future<void> _processGetAuthUser(
    FetchAuthenticatedUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    final cachedUser = _repo.cachedUser;
    if (cachedUser != null) {
      emit(AuthLoadedState(cachedUser));
    } else {
      emit(AuthLoadingState());
    }

    try {
      final freshUser = await _repo.getAuthUser();
      emit(AuthLoadedState(freshUser));
    } catch (e) {
      if (e is AppException && e.isUnauthorized) {
        // Refresh token expired/revoked server-side — the cached user is no
        // longer valid, regardless of whether we had one to show.
        await _repo.logout();
        emit(const AuthUnauthenticatedState());
        return;
      }

      // Any other failure (network blip, 5xx) — if we already showed cached
      // data, keep it rather than bouncing the user to an error screen.
      if (cachedUser == null) {
        final message = e is AppException ? e.message : 'Failed to load user';
        emit(AuthErrorState(message));
      }
    }
  }
}
