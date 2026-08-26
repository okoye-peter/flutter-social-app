import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/user_repository.dart';

part 'user_state.dart';
part 'user_event.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitialState()) {
    on<UpdateUserEvent>(_processUserUpdate, transformer: droppable());
  }

  final UserRepository _repo = UserRepository();

  Future<void> _processUserUpdate(
    UpdateUserEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoadingState());
    try {
      final user = await _repo.updateUser(
        event.user,
        imageBytes: event.imageBytes,
        imageFileName: event.imageFileName,
      );
      emit(UserUpdatedState(user: user));
    } catch (e) {
      final message = e is AppException ? e.message : 'User profile update failed';
      emit(UserErrorState(message: message));
    }
  }
}
