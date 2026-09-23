import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/models/group_model.dart';
import 'package:social_app/repositories/group_repository.dart';

part 'group_search_event.dart';
part 'group_search_state.dart';

/// Group discovery: groups matching a name that the caller is NOT in yet,
/// plus joining them — PUBLIC groups join immediately, PRIVATE ones create
/// a join request (which can be cancelled while still pending).
class GroupSearchBloc extends Bloc<GroupSearchEvent, GroupSearchState> {
  GroupSearchBloc() : super(const GroupSearchInitialState()) {
    on<GroupSearchQueryChanged>(_onQueryChanged, transformer: restartable());
    on<GroupJoinPressed>(_onJoinPressed, transformer: concurrent());
    on<GroupJoinCancelPressed>(_onCancelPressed, transformer: concurrent());
  }

  final GroupRepository _repo = GroupRepository();

  Future<void> _onQueryChanged(GroupSearchQueryChanged event, Emitter<GroupSearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const GroupSearchInitialState());
      return;
    }
    emit(const GroupSearchLoadingState());
    try {
      final result = await _repo.searchGroups(query: query);
      emit(GroupSearchLoadedState(groups: result.items));
    } catch (e) {
      final message = e is AppException ? e.message : 'Search failed';
      emit(GroupSearchErrorState(message: message));
    }
  }

  Future<void> _onJoinPressed(GroupJoinPressed event, Emitter<GroupSearchState> emit) async {
    final group = event.group;
    if (!_setBusy(emit, group.id, true)) return;
    try {
      final result = await _repo.joinGroup(group.id);
      final current = state;
      if (current is! GroupSearchLoadedState) return;
      if (result == GroupJoinResult.joined) {
        // Now a member — it belongs in "my groups", not in discovery.
        emit(current.copyWith(
          groups: current.groups.where((g) => g.id != group.id).toList(),
          busyIds: {...current.busyIds}..remove(group.id),
          joined: group,
        ));
      } else {
        emit(current.copyWith(
          groups: _withStatus(current.groups, group.id, GroupJoinStatus.pending),
          busyIds: {...current.busyIds}..remove(group.id),
          notice: 'Request sent to the group admins',
        ));
      }
    } on AppException catch (e) {
      _failAction(emit, group.id, e.message);
    }
  }

  Future<void> _onCancelPressed(GroupJoinCancelPressed event, Emitter<GroupSearchState> emit) async {
    final id = event.group.id;
    if (!_setBusy(emit, id, true)) return;
    try {
      await _repo.cancelJoinRequest(id);
      final current = state;
      if (current is! GroupSearchLoadedState) return;
      emit(current.copyWith(
        groups: _withStatus(current.groups, id, GroupJoinStatus.none),
        busyIds: {...current.busyIds}..remove(id),
      ));
    } on AppException catch (e) {
      _failAction(emit, id, e.message);
    }
  }

  /// Marks [id] as having a request in flight. Returns false (and does
  /// nothing) if results aren't loaded or it's already busy.
  bool _setBusy(Emitter<GroupSearchState> emit, String id, bool busy) {
    final current = state;
    if (current is! GroupSearchLoadedState) return false;
    if (busy && current.busyIds.contains(id)) return false;
    emit(current.copyWith(
      busyIds: busy ? {...current.busyIds, id} : ({...current.busyIds}..remove(id)),
    ));
    return true;
  }

  void _failAction(Emitter<GroupSearchState> emit, String id, String message) {
    final current = state;
    if (current is! GroupSearchLoadedState) return;
    emit(current.copyWith(busyIds: {...current.busyIds}..remove(id), actionError: message));
  }

  List<GroupModel> _withStatus(List<GroupModel> groups, String id, GroupJoinStatus status) => [
    for (final g in groups)
      g.id == id
          ? GroupModel(
              id: g.id,
              name: g.name,
              image: g.image,
              visibility: g.visibility,
              memberCount: g.memberCount,
              createdAt: g.createdAt,
              joinStatus: status,
            )
          : g,
  ];
}
