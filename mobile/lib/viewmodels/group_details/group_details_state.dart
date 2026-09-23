part of 'group_details_bloc.dart';

enum GroupDetailsStatus { loading, loaded, error }

/// Single state class (not a sealed hierarchy) because the chat and info
/// screens both keep rendering the last-loaded group while an action runs
/// or a background refetch happens.
final class GroupDetailsState extends Equatable {
  const GroupDetailsState({
    this.status = GroupDetailsStatus.loading,
    this.conversation,
    this.joinRequests = const [],
    this.isBusy = false,
    this.exited = false,
    this.errorMessage,
    this.notice,
    this.actionError,
  });

  final GroupDetailsStatus status;
  final ConversationModel? conversation;
  final List<GroupJoinRequestModel> joinRequests;
  // An admin/member action is in flight.
  final bool isBusy;
  // The caller is no longer a member (left, or was removed) — screens pop.
  final bool exited;
  // Set only in [GroupDetailsStatus.error] (the initial load failed).
  final String? errorMessage;
  // One-shot toasts, never carried over by copyWith.
  final String? notice;
  final String? actionError;

  ConversationMemberModel? get me {
    final myId = getIt<UserCache>().current?.id;
    for (final m in conversation?.members ?? const <ConversationMemberModel>[]) {
      if (m.userId == myId) return m;
    }
    return null;
  }

  /// OWNER/ADMIN — may edit the group, add/remove members, handle requests.
  bool get canManage => me?.role == MemberRole.owner || me?.role == MemberRole.admin;

  ConversationMemberModel? memberById(String? userId) {
    for (final m in conversation?.members ?? const <ConversationMemberModel>[]) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  GroupDetailsState copyWith({
    GroupDetailsStatus? status,
    ConversationModel? conversation,
    List<GroupJoinRequestModel>? joinRequests,
    bool? isBusy,
    bool? exited,
    String? errorMessage,
    String? notice,
    String? actionError,
  }) {
    return GroupDetailsState(
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      joinRequests: joinRequests ?? this.joinRequests,
      isBusy: isBusy ?? this.isBusy,
      exited: exited ?? this.exited,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    conversation,
    joinRequests,
    isBusy,
    exited,
    errorMessage,
    notice,
    actionError,
  ];
}
