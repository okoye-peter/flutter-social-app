part of 'user_bloc.dart';


sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object> get props => [];
}

final class UpdateUserEvent extends UserEvent {
  const UpdateUserEvent({required this.user});

  final UserModel user;

  @override
  List<Object> get props => [user];
}
