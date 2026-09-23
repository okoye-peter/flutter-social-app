import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/conversation_member_model.dart';
import 'package:social_app/models/group_join_request_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/group_details/group_details_bloc.dart';
import 'package:social_app/views/groups/member_picker_screen.dart';
import 'package:social_app/views/groups/widgets/group_avatar.dart';

const _brandColor = Color(0xFF0793F1);

/// A group's details: photo, name, visibility, members with their roles,
/// and — for OWNER/ADMIN — editing, adding/removing members and handling
/// join requests. Uses the chat screen's own [GroupDetailsBloc] (passed as
/// the route `extra`), so changes here are reflected there immediately.
/// Leaving is handled by the chat screen's listener, which navigates back
/// to the Groups tab (closing this screen too).
class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.bloc});

  final GroupDetailsBloc bloc;

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;
    bloc.add(GroupDetailsUpdateEvent(imageBytes: await picked.readAsBytes()));
  }

  Future<void> _edit(BuildContext context, GroupDetailsState state) async {
    final group = state.conversation;
    if (group == null) return;
    final result = await showModalBottomSheet<({String name, ConversationVisibility visibility})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditGroupSheet(
        name: group.name ?? '',
        visibility: group.visibility ?? ConversationVisibility.private,
      ),
    );
    if (result == null) return;
    final name = result.name != group.name ? result.name : null;
    final visibility = result.visibility != group.visibility ? result.visibility : null;
    if (name == null && visibility == null) return;
    bloc.add(GroupDetailsUpdateEvent(name: name, visibility: visibility));
  }

  Future<void> _addMembers(BuildContext context, GroupDetailsState state) async {
    final picked = await context.push<List<UserModel>>(
      AppRoutes.groupAddMembers,
      extra: MemberPickerArgs(
        excludeIds: {for (final m in state.conversation?.members ?? const []) m.userId},
      ),
    );
    if (picked == null || picked.isEmpty) return;
    bloc.add(GroupDetailsAddMembersEvent(picked.map((u) => u.id).toList()));
  }

  Future<void> _removeMember(BuildContext context, ConversationMemberModel member) async {
    final confirmed = await _confirm(
      context,
      title: 'Remove ${member.user.name}?',
      body: 'They will no longer see new messages in this group.',
      action: 'Remove',
    );
    if (confirmed) bloc.add(GroupDetailsRemoveMemberEvent(member.userId));
  }

  Future<void> _leave(BuildContext context, GroupDetailsState state) async {
    final isOwner = state.me?.role == MemberRole.owner;
    final confirmed = await _confirm(
      context,
      title: 'Leave this group?',
      body: isOwner
          ? 'You are the owner. Ownership will pass to the longest-serving admin (or member).'
          : "You won't get new messages unless someone adds you back.",
      action: 'Leave',
    );
    if (confirmed) bloc.add(const GroupDetailsLeaveEvent());
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocConsumer<GroupDetailsBloc, GroupDetailsState>(
      bloc: bloc,
      // An exit (left/removed) is toasted by the chat screen, which also
      // navigates away — don't double up here.
      listenWhen: (_, current) => !current.exited && (current.notice != null || current.actionError != null),
      listener: (_, state) {
        if (state.actionError != null) AppToast.error(state.actionError!);
        if (state.notice != null) AppToast.success(state.notice!);
      },
      builder: (context, state) {
        final group = state.conversation;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Group info', style: TextStyle(fontWeight: FontWeight.w700)),
            actions: [
              if (state.canManage)
                IconButton(
                  tooltip: 'Edit group',
                  onPressed: state.isBusy ? null : () => _edit(context, state),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
            bottom: state.isBusy
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: group == null
              ? (state.status == GroupDetailsStatus.error
                    ? Center(child: Text(state.errorMessage ?? 'Failed to load group'))
                    : const Center(child: CircularProgressIndicator()))
              : RefreshIndicator(
                  onRefresh: () async => bloc.add(const GroupDetailsLoadEvent()),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: state.canManage && !state.isBusy ? _changePhoto : null,
                          child: Stack(
                            children: [
                              GroupAvatar(image: group.image, radius: 52),
                              if (state.canManage)
                                const Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _brandColor,
                                    child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          group.name ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            group.visibility == ConversationVisibility.public
                                ? Icons.public_rounded
                                : Icons.lock_outline_rounded,
                            size: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.visibility == ConversationVisibility.public ? 'Public' : 'Private'} group'
                            ' · ${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (state.canManage && state.joinRequests.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SectionHeader('Join requests (${state.joinRequests.length})'),
                        for (final request in state.joinRequests)
                          _JoinRequestTile(
                            request: request,
                            enabled: !state.isBusy,
                            onRespond: (accept) => bloc.add(
                              GroupDetailsRespondJoinRequestEvent(requestId: request.id, accept: accept),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      _SectionHeader('Members (${group.members.length})'),
                      if (state.canManage)
                        ListTile(
                          enabled: !state.isBusy,
                          onTap: () => _addMembers(context, state),
                          leading: const CircleAvatar(
                            radius: 22,
                            backgroundColor: _brandColor,
                            child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                          ),
                          title: const Text('Add members', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      for (final member in _sorted(group.members))
                        _MemberTile(
                          member: member,
                          isMe: member.userId == state.me?.userId,
                          // Admins can't remove the owner; nobody removes
                          // themselves here (that's "Leave group").
                          onRemove: state.canManage &&
                                  !state.isBusy &&
                                  member.userId != state.me?.userId &&
                                  member.role != MemberRole.owner
                              ? () => _removeMember(context, member)
                              : null,
                        ),
                      const SizedBox(height: 16),
                      ListTile(
                        enabled: !state.isBusy,
                        onTap: () => _leave(context, state),
                        leading: Icon(Icons.logout_rounded, color: colorScheme.error),
                        title: Text(
                          'Leave group',
                          style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  /// Owner first, then admins, then everyone else — alphabetical within each.
  static List<ConversationMemberModel> _sorted(List<ConversationMemberModel> members) {
    int rank(MemberRole r) => switch (r) {
      MemberRole.owner => 0,
      MemberRole.admin => 1,
      MemberRole.member => 2,
    };
    return [...members]..sort((a, b) {
      final byRole = rank(a.role).compareTo(rank(b.role));
      return byRole != 0 ? byRole : a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

Widget _avatarFor(BuildContext context, UserModel user) {
  final colorScheme = Theme.of(context).colorScheme;
  return UserAvatar(
    source: user.image.trim().isNotEmpty
        ? user.image
        : (user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
    radius: 22,
    backgroundColor: colorScheme.surfaceContainerHighest,
    textColor: colorScheme.onSurface,
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isMe, required this.onRemove});

  final ConversationMemberModel member;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = switch (member.role) {
      MemberRole.owner => 'Owner',
      MemberRole.admin => 'Admin',
      MemberRole.member => null,
    };
    return ListTile(
      leading: _avatarFor(context, member.user),
      title: Text(isMe ? '${member.user.name} (You)' : member.user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '@${member.user.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (roleLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brandColor),
              ),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from group',
              onPressed: onRemove,
              icon: Icon(Icons.person_remove_outlined, color: colorScheme.error),
            ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({required this.request, required this.enabled, required this.onRespond});

  final GroupJoinRequestModel request;
  final bool enabled;
  final ValueChanged<bool> onRespond;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _avatarFor(context, request.user),
      title: Text(request.user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '@${request.user.username}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reject',
            onPressed: enabled ? () => onRespond(false) : null,
            icon: Icon(Icons.close_rounded, color: colorScheme.error),
          ),
          IconButton(
            tooltip: 'Accept',
            onPressed: enabled ? () => onRespond(true) : null,
            icon: const Icon(Icons.check_rounded, color: Colors.green),
          ),
        ],
      ),
    );
  }
}

class _EditGroupSheet extends StatefulWidget {
  const _EditGroupSheet({required this.name, required this.visibility});

  final String name;
  final ConversationVisibility visibility;

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  late final _nameController = TextEditingController(text: widget.name);
  late ConversationVisibility _visibility = widget.visibility;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 4),
          SegmentedButton<ConversationVisibility>(
            segments: const [
              ButtonSegment(
                value: ConversationVisibility.private,
                icon: Icon(Icons.lock_outline_rounded),
                label: Text('Private'),
              ),
              ButtonSegment(
                value: ConversationVisibility.public,
                icon: Icon(Icons.public_rounded),
                label: Text('Public'),
              ),
            ],
            selected: {_visibility},
            onSelectionChanged: (s) => setState(() => _visibility = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: name.isEmpty
                ? null
                : () => Navigator.pop(context, (name: name, visibility: _visibility)),
            style: FilledButton.styleFrom(
              backgroundColor: _brandColor,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
