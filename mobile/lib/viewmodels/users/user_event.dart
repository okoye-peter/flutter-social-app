part of 'user_bloc.dart';


sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object> get props => [];
}

final class UpdateUserEvent extends UserEvent {
  const UpdateUserEvent({
    required this.user,
    this.imageBytes,
    this.imageFileName,
  });

  final UserModel user;
  final Uint8List? imageBytes;
  final String? imageFileName;

  @override
  List<Object> get props => [user, imageBytes ?? '', imageFileName ?? ''];
}
