import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/router/app_routes.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/group_repository.dart';
import 'package:social_app/views/groups/member_picker_screen.dart';

const _brandColor = Color(0xFF0793F1);

/// Name, photo, public/private and initial members for a new group. Pops
/// with the created [ConversationModel] so the Groups tab can open it.
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _repo = GroupRepository();
  ConversationVisibility _visibility = ConversationVisibility.private;
  List<UserModel> _members = [];
  Uint8List? _imageBytes;
  bool _submitting = false;

  bool get _canSubmit => _nameController.text.trim().isNotEmpty && !_submitting;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _imageBytes = bytes);
  }

  Future<void> _pickMembers() async {
    final picked = await context.push<List<UserModel>>(
      AppRoutes.groupAddMembers,
      extra: MemberPickerArgs(initiallySelected: _members),
    );
    if (picked != null && mounted) setState(() => _members = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final created = await _repo.createGroup(
        name: _nameController.text.trim(),
        visibility: _visibility,
        memberIds: _members.map((m) => m.id).toList(),
        imageBytes: _imageBytes,
      );
      if (!mounted) return;
      context.pop(created);
    } on AppException catch (e) {
      AppToast.error(e.message);
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New group',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _submitting ? null : _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                      child: _imageBytes == null
                          ? Icon(Icons.groups_rounded, size: 48, color: colorScheme.onPrimaryContainer)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: _brandColor,
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Who can join', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _VisibilityOption(
              selected: _visibility == ConversationVisibility.private,
              icon: Icons.lock_outline_rounded,
              title: 'Private',
              subtitle: 'People can request to join; an admin must approve them.',
              onTap: _submitting ? null : () => setState(() => _visibility = ConversationVisibility.private),
            ),
            const SizedBox(height: 8),
            _VisibilityOption(
              selected: _visibility == ConversationVisibility.public,
              icon: Icons.public_rounded,
              title: 'Public',
              subtitle: 'Anyone who finds the group can join straight away.',
              onTap: _submitting ? null : () => setState(() => _visibility = ConversationVisibility.public),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _members.isEmpty ? 'Members' : 'Members (${_members.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _submitting ? null : _pickMembers,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(_members.isEmpty ? 'Add' : 'Edit'),
                ),
              ],
            ),
            if (_members.isEmpty)
              Text(
                "Optional — you can add people later. You'll be the group's owner.",
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _members)
                    InputChip(
                      avatar: UserAvatar(
                        source: m.image.trim().isNotEmpty
                            ? m.image
                            : (m.name.isNotEmpty ? m.name[0].toUpperCase() : '?'),
                        radius: 12,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        textColor: colorScheme.onSurface,
                      ),
                      label: Text(m.name),
                      onDeleted: _submitting
                          ? null
                          : () => setState(() => _members = _members.where((x) => x.id != m.id).toList()),
                    ),
                ],
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: _brandColor,
                minimumSize: const Size.fromHeight(50),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Create group', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _brandColor : colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _brandColor : colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? _brandColor : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
