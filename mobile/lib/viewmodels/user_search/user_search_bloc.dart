import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/search_repository.dart';
import 'package:social_app/repositories/user_repository.dart';

part 'user_search_event.dart';
part 'user_search_state.dart';

class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  UserSearchBloc() : super(UserSearchInitialState()) {
    on<UserSearchQueryChanged>(_onQueryChanged, transformer: restartable());
    on<UserSearchFollowToggled>(_onFollowToggled);
  }

  final SearchRepository _repo = SearchRepository();
  final UserRepository _userRepo = UserRepository();

  // Guards against a double-tap firing two overlapping requests for the
  // same user while the first is still in flight.
  final Set<String> _pendingFollowUserIds = {};

  Future<void> _onQueryChanged(UserSearchQueryChanged event, Emitter<UserSearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(UserSearchInitialState());
      return;
    }
    emit(UserSearchLoadingState());
    try {
      final users = await _repo.searchUsers(query);
      emit(UserSearchLoadedState(users: users));
    } catch (e) {
      final message = e is AppException ? e.message : 'Search failed';
      emit(UserSearchErrorState(message: message));
    }
  }

  Future<void> _onFollowToggled(UserSearchFollowToggled event, Emitter<UserSearchState> emit) async {
    final original = event.user;
    if (_pendingFollowUserIds.contains(original.id)) return;
    _pendingFollowUserIds.add(original.id);

    final optimistic = original.copyWith(
      newIsFollowedByMe: !original.isFollowedByMe,
      newFollowersCount: original.isFollowedByMe
          ? original.followersCount - 1
          : original.followersCount + 1,
    );
    // Optimistic: flip the button immediately, reconcile the count with the
    // server response below, and roll back only if the request fails.
    emit(_applyUser(state, optimistic));

    try {
      final result = await _userRepo.toggleFollow(original);
      final current = _findUser(state, original.id) ?? optimistic;
      emit(_applyUser(state, current.copyWith(newFollowersCount: result.followersCount)));
    } on AppException {
      // Revert only the fields this toggle owns, applied on top of
      // whatever the user looks like *now* rather than a wholesale replace
      // with the stale `original` snapshot.
      final current = _findUser(state, original.id) ?? original;
      emit(
        _applyUser(
          state,
          current.copyWith(
            newIsFollowedByMe: original.isFollowedByMe,
            newFollowersCount: original.followersCount,
          ),
        ),
      );
    } finally {
      _pendingFollowUserIds.remove(original.id);
    }
  }

  /// Replaces [updated] into the loaded results list by id; any other
  /// state (loading, error, a since-changed search) is returned unchanged.
  UserSearchState _applyUser(UserSearchState current, UserModel updated) {
    if (current is! UserSearchLoadedState) return current;
    return UserSearchLoadedState(
      users: [
        for (final user in current.users)
          if (user.id == updated.id) updated else user,
      ],
    );
  }

  UserModel? _findUser(UserSearchState current, String id) {
    if (current is! UserSearchLoadedState) return null;
    for (final user in current.users) {
      if (user.id == id) return user;
    }
    return null;
  }
}
