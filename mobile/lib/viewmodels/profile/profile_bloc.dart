import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/post_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/user_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileInitialState()) {
    on<ProfileLoadRequested>(_onLoadRequested, transformer: droppable());
    // concurrent(), not droppable(): the 4 tabs must be able to load in
    // parallel — a global droppable() here would drop the Reels tab's
    // first fetch while the Posts tab's is still in flight.
    on<ProfileTabRequested>(_onTabRequested, transformer: concurrent());
    on<ProfileTabMoreRequested>(_onTabMoreRequested, transformer: concurrent());
    on<ProfileFollowToggled>(_onFollowToggled, transformer: droppable());
  }

  final UserRepository _userRepo = UserRepository();
  final UserCache _userCache = getIt<UserCache>();

  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoadingState());
    try {
      final result = await _userRepo.getUserProfile(event.userId);
      emit(
        ProfileLoadedState(
          user: result.user.copyWith(newIsFollowedByMe: result.isFollowedByMe),
          isBlockedByMe: result.isBlockedByMe,
          isOwnProfile: _userCache.current?.id == event.userId,
          tabs: {for (final tab in ProfileMediaType.values) tab: const ProfileTabInitial()},
        ),
      );
    } catch (e) {
      final message = e is AppException ? e.message : 'Failed to load profile';
      emit(ProfileErrorState(message: message));
    }
  }

  Future<void> _onTabRequested(
    ProfileTabRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoadedState) return;
    if (current.tabs[event.tab] is! ProfileTabInitial) return;

    emit(current.copyWithTab(event.tab, const ProfileTabLoading()));
    try {
      final result = await _fetchTab(event.tab, current.user.id);
      final latest = state;
      if (latest is! ProfileLoadedState) return;
      emit(
        latest.copyWithTab(
          event.tab,
          ProfileTabLoaded(
            items: result.items,
            hasMorePage: result.hasMorePage,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } on AppException catch (e) {
      final latest = state;
      if (latest is! ProfileLoadedState) return;
      emit(
        latest.copyWithTab(
          event.tab,
          e.statusCode == 403
              ? const ProfileTabBlocked()
              : ProfileTabError(message: e.message),
        ),
      );
    }
  }

  Future<void> _onTabMoreRequested(
    ProfileTabMoreRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoadedState) return;
    final tabState = current.tabs[event.tab];
    if (tabState is! ProfileTabLoaded || !tabState.hasMorePage) return;

    try {
      final result = await _fetchTab(event.tab, current.user.id, cursor: event.cursor);
      final latest = state;
      if (latest is! ProfileLoadedState) return;
      final latestTabState = latest.tabs[event.tab];
      final previousItems = latestTabState is ProfileTabLoaded ? latestTabState.items : <PostModel>[];
      emit(
        latest.copyWithTab(
          event.tab,
          ProfileTabLoaded(
            items: [...previousItems, ...result.items],
            hasMorePage: result.hasMorePage,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } on AppException {
      // A failed "load more" leaves the tab's already-loaded items in
      // place — no error state, the user can just retry by scrolling.
    }
  }

  Future<({List<PostModel> items, bool hasMorePage, String? nextCursor})> _fetchTab(
    ProfileMediaType tab,
    String userId, {
    String? cursor,
  }) async {
    final page = switch (tab) {
      ProfileMediaType.post => await _userRepo.fetchUserPosts(userId, cursor: cursor),
      ProfileMediaType.reel => await _userRepo.fetchUserReels(userId, cursor: cursor),
      ProfileMediaType.repost => await _userRepo.fetchUserReposts(userId, cursor: cursor),
      ProfileMediaType.mention => await _userRepo.fetchUserTagged(userId, cursor: cursor),
    };
    return (items: page.items, hasMorePage: page.hasMorePage, nextCursor: page.nextCursor);
  }

  Future<void> _onFollowToggled(
    ProfileFollowToggled event,
    Emitter<ProfileState> emit,
  ) async {
    final current = state;
    if (current is! ProfileLoadedState) return;

    final original = current.user;
    final optimisticUser = original.copyWith(
      newIsFollowedByMe: !original.isFollowedByMe,
      newFollowersCount: original.isFollowedByMe
          ? original.followersCount - 1
          : original.followersCount + 1,
    );
    // Optimistic: flip the button immediately, reconcile the count with
    // the server response below, and roll back only if the request fails.
    emit(current.copyWith(user: optimisticUser));

    try {
      final result = await _userRepo.toggleFollow(original);
      final latest = state;
      if (latest is! ProfileLoadedState) return;
      emit(latest.copyWith(user: latest.user.copyWith(newFollowersCount: result.followersCount)));
    } on AppException {
      final latest = state;
      if (latest is! ProfileLoadedState) return;
      emit(
        latest.copyWith(
          user: latest.user.copyWith(
            newIsFollowedByMe: original.isFollowedByMe,
            newFollowersCount: original.followersCount,
          ),
        ),
      );
    }
  }
}
