part of 'profile_bloc.dart';

sealed class ProfileEvent extends Equatable {
  const ProfileEvent();
  @override
  List<Object?> get props => [];
}

final class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested({required this.userId, this.initialUser});
  final String userId;
  final UserModel? initialUser;
  @override
  List<Object?> get props => [userId, initialUser];
}

final class ProfileTabRequested extends ProfileEvent {
  const ProfileTabRequested({required this.tab});
  final ProfileMediaType tab;
  @override
  List<Object?> get props => [tab];
}

final class ProfileTabMoreRequested extends ProfileEvent {
  const ProfileTabMoreRequested({required this.tab, required this.cursor});
  final ProfileMediaType tab;
  final String cursor;
  @override
  List<Object?> get props => [tab, cursor];
}

final class ProfileFollowToggled extends ProfileEvent {
  const ProfileFollowToggled();
}
