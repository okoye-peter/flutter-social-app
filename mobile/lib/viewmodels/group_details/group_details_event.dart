part of 'group_details_bloc.dart';

sealed class GroupDetailsEvent extends Equatable {
  const GroupDetailsEvent();

  @override
  List<Object?> get props => [];
}

final class GroupDetailsLoadEvent extends GroupDetailsEvent {
  const GroupDetailsLoadEvent();
}

/// A `conversation:member-added` / `-removed` socket event for this group.
final class GroupDetailsMembershipChangedEvent extends GroupDetailsEvent {
  const GroupDetailsMembershipChangedEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [name, data];
}

/// OWNER/ADMIN only. Null fields are left unchanged.
final class GroupDetailsUpdateEvent extends GroupDetailsEvent {
  const GroupDetailsUpdateEvent({this.name, this.visibility, this.imageBytes});

  final String? name;
  final ConversationVisibility? visibility;
  final Uint8List? imageBytes;

  @override
  List<Object?> get props => [name, visibility, imageBytes];
}

/// OWNER/ADMIN only.
final class GroupDetailsAddMembersEvent extends GroupDetailsEvent {
  const GroupDetailsAddMembersEvent(this.userIds);

  final List<String> userIds;

  @override
  List<Object?> get props => [userIds];
}

/// OWNER/ADMIN only.
final class GroupDetailsRemoveMemberEvent extends GroupDetailsEvent {
  const GroupDetailsRemoveMemberEvent(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

final class GroupDetailsLeaveEvent extends GroupDetailsEvent {
  const GroupDetailsLeaveEvent();
}

/// OWNER/ADMIN only — accept or reject a PRIVATE group's join request.
final class GroupDetailsRespondJoinRequestEvent extends GroupDetailsEvent {
  const GroupDetailsRespondJoinRequestEvent({required this.requestId, required this.accept});

  final String requestId;
  final bool accept;

  @override
  List<Object?> get props => [requestId, accept];
}
