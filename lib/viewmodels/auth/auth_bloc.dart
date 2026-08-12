import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/repositories/auth_repository.dart';

part 'auth_state.dart';
part 'auth_event.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState>{
  AuthBloc() : super(AuthInitial()){
    on<RegisterEvent>(_processRegistration);
    on<LoginEvent>(_processLogin);
    on<FetchAuthenticatedUserEvent>(_processGetAuthUser);
    on<LogoutEvent>(_processLogout);
  }

  final AuthRepository _repo = getIt<AuthRepository>();

  Future<void> _processRegistration(RegisterEvent event, Emitter<AuthState> emit) async {

  }

  Future<void> _processLogin(LoginEvent event, Emitter<AuthState> emit) async {

  }

  Future<void> _processLogout(LogoutEvent event, Emitter<AuthState> emit) async {

  }

  Future<void> _processGetAuthUser(FetchAuthenticatedUserEvent event, Emitter<AuthState> emit) async {

  }
}
