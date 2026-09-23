import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/conversation_member_model.dart';
import 'package:social_app/models/conversation_model.dart';
import 'package:social_app/models/group_join_request_model.dart';
import 'package:social_app/repositories/group_repository.dart';
import 'package:social_app/services/socket_service.dart';

part 'group_details_event.dart';
part 'group_details_state.dart';

/// One group's metadata, members and (for OWNER/ADMIN) pending join
/// requests, plus every admin/member action on it. Shared by the group's
/// chat screen (sender names, header) and its info screen, so an edit made
/// on the info screen shows up in the chat header immediately.
class GroupDetailsBloc extends Bloc<GroupDetailsEvent, GroupDetailsState> {
  GroupDetailsBloc({required this.conversationId}) : super(const GroupDetailsState()) {
    on<GroupDetailsLoadEvent>(_processLoad, transformer: restartable());
    on<GroupDetailsMembershipChangedEvent>(_processMembershipChanged, transformer: sequential());
    // Admin/member actions: one at a time, extra taps while busy dropped.
    on<GroupDetailsUpdateEvent>(_processUpdate, transformer: droppable());
    on<GroupDetailsAddMembersEvent>(_processAddMembers, transformer: droppable());
    on<GroupDetailsRemoveMemberEvent>(_processRemoveMember, transformer: droppable());
    on<GroupDetailsLeaveEvent>(_processLeave, transformer: droppable());
    on<GroupDetailsRespondJoinRequestEvent>(_processRespondJoinRequest, transformer: droppable());
    _socketSub = getIt<SocketService>().events
        .where((e) =>
            (e.name == 'conversation:member-added' || e.name == 'conversation:member-removed') &&
            e.data['conversationId'] == conversationId)
        .listen((e) => add(GroupDetailsMembershipChangedEvent(e.name, e.data)));
  }

  final String conversationId;
  final GroupRepository _repo = GroupRepository();
  late final StreamSubscription<SocketEvent> _socketSub;

  String? get _myId => getIt<UserCache>().current?.id;

  @override
  Future<void> close() async {
    await _socketSub.cancel();
    return super.close();
  }

  Future<void> _processLoad(GroupDetailsLoadEvent event, Emitter<GroupDetailsState> emit) async {
    if (state.conversation == null) emit(state.copyWith(status: GroupDetailsStatus.loading));
    try {
      final conversation = await _repo.getGroup(conversationId);
      emit(state.copyWith(status: GroupDetailsStatus.loaded, conversation: conversation));
      await _loadJoinRequests(emit);
    } on AppException catch (e) {
      // 404 = not (or no longer) a member — e.g. removed while offline.
      if (e.statusCode == 404) {
        emit(state.copyWith(exited: true, notice: 'You are no longer in this group'));
        return;
      }
      if (state.conversation != null) return; // keep what's on screen
      emit(state.copyWith(status: GroupDetailsStatus.error, errorMessage: e.message));
    }
  }

  Future<void> _loadJoinRequests(Emitter<GroupDetailsState> emit) async {
    if (!state.canManage) return;
    try {
      final requests = await _repo.fetchJoinRequests(conversationId);
      emit(state.copyWith(joinRequests: requests));
    } on AppException {
      // Non-critical — the rest of the screen still works without them.
    }
  }

  Future<void> _processMembershipChanged(
    GroupDetailsMembershipChangedEvent event,
    Emitter<GroupDetailsState> emit,
  ) async {
    if (event.name == 'conversation:member-removed' && event.data['userId'] == _myId) {
      emit(state.copyWith(exited: true, notice: 'You were removed from this group'));
      return;
    }
    add(const GroupDetailsLoadEvent());
  }

  Future<void> _processUpdate(GroupDetailsUpdateEvent event, Emitter<GroupDetailsState> emit) async {
    await _runAction(emit, () async {
      final updated = await _repo.updateGroup(
        conversationId,
        name: event.name,
        visibility: event.visibility,
        imageBytes: event.imageBytes,
      );
      emit(state.copyWith(conversation: updated, notice: 'Group updated'));
    });
  }

  Future<void> _processAddMembers(GroupDetailsAddMembersEvent event, Emitter<GroupDetailsState> emit) async {
    if (event.userIds.isEmpty) return;
    await _runAction(emit, () async {
      final updated = await _repo.addMembers(conversationId, event.userIds);
      emit(state.copyWith(conversation: updated, notice: 'Members added'));
    });
  }

  Future<void> _processRemoveMember(GroupDetailsRemoveMemberEvent event, Emitter<GroupDetailsState> emit) async {
    await _runAction(emit, () async {
      await _repo.removeMember(conversationId, event.userId);
      final conversation = state.conversation;
      if (conversation == null) return;
      emit(state.copyWith(
        conversation: _withMembers(
          conversation,
          conversation.members.where((m) => m.userId != event.userId).toList(),
        ),
        notice: 'Member removed',
      ));
    });
  }

  Future<void> _processLeave(GroupDetailsLeaveEvent event, Emitter<GroupDetailsState> emit) async {
    await _runAction(emit, () async {
      await _repo.leaveGroup(conversationId);
      emit(state.copyWith(exited: true, notice: 'You left the group'));
    });
  }

  Future<void> _processRespondJoinRequest(
    GroupDetailsRespondJoinRequestEvent event,
    Emitter<GroupDetailsState> emit,
  ) async {
    await _runAction(emit, () async {
      await _repo.respondToJoinRequest(conversationId, event.requestId, accept: event.accept);
      emit(state.copyWith(
        joinRequests: state.joinRequests.where((r) => r.id != event.requestId).toList(),
      ));
      // An accepted request adds a member — refetch for the new list.
      if (event.accept) add(const GroupDetailsLoadEvent());
    });
  }

  Future<void> _runAction(Emitter<GroupDetailsState> emit, Future<void> Function() action) async {
    emit(state.copyWith(isBusy: true));
    try {
      await action();
    } on AppException catch (e) {
      emit(state.copyWith(actionError: e.message));
    } finally {
      emit(state.copyWith(isBusy: false));
    }
  }

  ConversationModel _withMembers(ConversationModel c, List<ConversationMemberModel> members) {
    return ConversationModel(
      id: c.id,
      type: c.type,
      createdAt: c.createdAt,
      visibility: c.visibility,
      name: c.name,
      createdById: c.createdById,
      createdBy: c.createdBy,
      image: c.image,
      members: members,
    );
  }
}
