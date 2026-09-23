part of 'profile_bloc.dart';

sealed class ProfileTabState extends Equatable {
  const ProfileTabState();
  @override
  List<Object?> get props => [];
}

final class ProfileTabInitial extends ProfileTabState {
  const ProfileTabInitial();
}

final class ProfileTabLoading extends ProfileTabState {
  const ProfileTabLoading();
}

final class ProfileTabLoaded extends ProfileTabState {
  const ProfileTabLoaded({
    required this.items,
    required this.hasMorePage,
    required this.nextCursor,
  });
  final List<PostModel> items;
  final bool hasMorePage;
  final String? nextCursor;
  @override
  List<Object?> get props => [items, hasMorePage, nextCursor];
}

// The tab's own fetch came back 403 — the viewer and this profile's owner
// have blocked each other in whichever direction `isBlockedByMe` (checked
// up front on the profile itself) doesn't already cover.
final class ProfileTabBlocked extends ProfileTabState {
  const ProfileTabBlocked();
}

final class ProfileTabError extends ProfileTabState {
  const ProfileTabError({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

final class ProfileInitialState extends ProfileState {
  const ProfileInitialState();
}

final class ProfileLoadingState extends ProfileState {
  const ProfileLoadingState();
}

final class ProfileErrorState extends ProfileState {
  const ProfileErrorState({required this.message});
  final String message;
  @override
  List<Object?> get props => [message];
}

final class ProfileLoadedState extends ProfileState {
  const ProfileLoadedState({
    required this.user,
    required this.isBlockedByMe,
    required this.isOwnProfile,
    required this.tabs,
  });

  // `user.isFollowedByMe` is the single source of truth for follow state
  // (folded in from the profile endpoint's separate top-level field when
  // this state is first built) — deliberately not duplicated as its own
  // field here, so there's only one place that can go stale.
  final UserModel user;
  final bool isBlockedByMe;
  final bool isOwnProfile;
  final Map<ProfileMediaType, ProfileTabState> tabs;

  ProfileLoadedState copyWith({UserModel? user, bool? isBlockedByMe}) {
    return ProfileLoadedState(
      user: user ?? this.user,
      isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
      isOwnProfile: isOwnProfile,
      tabs: tabs,
    );
  }

  ProfileLoadedState copyWithTab(ProfileMediaType tab, ProfileTabState newTabState) {
    return ProfileLoadedState(
      user: user,
      isBlockedByMe: isBlockedByMe,
      isOwnProfile: isOwnProfile,
      tabs: {...tabs, tab: newTabState},
    );
  }

  @override
  List<Object?> get props => [user, isBlockedByMe, isOwnProfile, tabs];
}
