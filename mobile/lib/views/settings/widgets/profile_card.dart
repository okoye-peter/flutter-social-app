import 'package:flutter/material.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';
import 'package:social_app/models/user_model.dart';

const _brandColor = Color(0xFF0793F1);

/// Avatar, name/about form, and edit/save controls shown at the top of the
/// settings screen.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.colorScheme,
    required this.avatarImage,
    required this.isUploadingAvatar,
    required this.onAvatarTap,
    required this.isEditing,
    required this.isSaving,
    required this.formKey,
    required this.nameController,
    required this.aboutController,
    required this.user,
    required this.onEditProfile,
    required this.onCancelEdit,
    required this.onSaveProfile,
  });

  final ColorScheme colorScheme;
  final ImageProvider? avatarImage;
  final bool isUploadingAvatar;
  final VoidCallback onAvatarTap;
  final bool isEditing;
  final bool isSaving;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController aboutController;
  final UserModel user;
  final VoidCallback onEditProfile;
  final VoidCallback onCancelEdit;
  final VoidCallback onSaveProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _brandColor.withValues(alpha: 0.10),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_brandColor, _brandColor.withValues(alpha: 0.4)],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: colorScheme.surface,
                    child: CircleAvatar(
                      radius: 51,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (isUploadingAvatar)
                  Positioned.fill(
                    child: CircleAvatar(
                      radius: 57,
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _brandColor,
                        border: Border.all(color: colorScheme.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _brandColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: formKey,
            child: Column(
              children: [
                if (isEditing) ...[
                  AuthTextField(
                    controller: nameController,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: aboutController,
                    label: 'About me',
                    icon: Icons.info_outline_rounded,
                    textInputAction: TextInputAction.done,
                  ),
                ] else ...[
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.phoneNumber,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: Colors.green.shade600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.aboutMe.isNotEmpty
                        ? user.aboutMe
                        : 'No bio added yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: isSaving ? null : onCancelEdit,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AuthSubmitButton(
                          label: 'Save',
                          isLoading: isSaving,
                          onPressed: onSaveProfile,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: onEditProfile,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Edit profile',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
