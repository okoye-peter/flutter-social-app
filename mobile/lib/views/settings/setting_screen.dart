import 'dart:typed_data';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/auth/auth_bloc.dart';
import 'package:social_app/viewmodels/users/user_bloc.dart';
import 'package:social_app/views/settings/widgets/profile_card.dart';

const _brandColor = Color(0xFF0793F1);

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserBloc>(
      create: (_) => UserBloc(),
      child: const _SettingScreenBody(),
    );
  }
}

class _SettingScreenBody extends StatefulWidget {
  const _SettingScreenBody();

  @override
  State<_SettingScreenBody> createState() => _SettingScreenBodyState();
}

class _SettingScreenBodyState extends State<_SettingScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _imagePicker = ImagePicker();

  late UserModel _user;

  Uint8List? _avatarBytes;
  bool _isUploadingAvatar = false;
  bool _isEditing = false;
  bool isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    _user = getIt<UserCache>().current!;
    _nameController.text = _user.name;
    _aboutController.text = _user.aboutMe;
    getThemeMode();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void getThemeMode() async {
    final saveThemeMode = await AdaptiveTheme.getThemeMode();
    if (saveThemeMode == AdaptiveThemeMode.dark) {
      setState(() {
        isDarkTheme = true;
      });
    } else {
      setState(() {
        isDarkTheme = false;
      });
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    Navigator.of(context).pop();

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: _brandColor,
          toolbarWidgetColor: Colors.white,
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;

    setState(() {
      _avatarBytes = bytes;
      _isUploadingAvatar = true;
    });

    context.read<UserBloc>().add(
      UpdateUserEvent(
        user: _user,
        imageBytes: bytes,
        imageFileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
  }

  void _removeAvatar() {
    Navigator.of(context).pop();
    setState(() {
      _avatarBytes = null;
      _user.image = '';
    });
  }

  void _showAvatarOptions() {
    final hasPhoto = _avatarBytes != null || _user.image.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Profile photo',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: _brandColor,
                      size: 20,
                    ),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () => _pickAvatar(ImageSource.camera),
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: _brandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.photo_library_outlined,
                      color: _brandColor,
                      size: 20,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () => _pickAvatar(ImageSource.gallery),
                ),
                if (hasPhoto)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Remove photo',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    onTap: _removeAvatar,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onEditProfile() {
    setState(() => _isEditing = true);
  }

  void _onCancelEdit() {
    setState(() {
      _nameController.text = _user.name;
      _aboutController.text = _user.aboutMe;
      _isEditing = false;
    });
  }

  void _onSaveProfile() {
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) return;
    FocusScope.of(context).unfocus();

    context.read<UserBloc>().add(
      UpdateUserEvent(
        user: _user.copyWith(
          newName: _nameController.text.trim(),
          newAboutMe: _aboutController.text.trim(),
        ),
      ),
    );
  }

  void _onUserStateChanged(BuildContext context, UserState state) {
    if (state is UserErrorState) {
      setState(() {
        _isUploadingAvatar = false;
        _avatarBytes = null;
      });
      AppToast.error(state.message);
      return;
    }

    if (state is UserUpdatedState) {
      setState(() {
        _user = state.user;
        _avatarBytes = null;
        _isUploadingAvatar = false;
        _isEditing = false;
      });
      AppToast.success('User profile picture updated successfully');
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Log out?'),
          content: const Text(
            'You will need to sign in again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(LogoutEvent());
              },
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );
  }

  ImageProvider? _avatarImage() {
    if (_avatarBytes != null) return MemoryImage(_avatarBytes!);
    if (_user.image.isNotEmpty) return CachedNetworkImageProvider(_user.image);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarImage = _avatarImage();

    return BlocConsumer<UserBloc, UserState>(
      listener: _onUserStateChanged,
      builder: (context, state) {
        final isSaving = state is UserLoadingState;

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your profile and app preferences',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ProfileCard(
                colorScheme: colorScheme,
                avatarImage: avatarImage,
                isUploadingAvatar: _isUploadingAvatar,
                onAvatarTap: _showAvatarOptions,
                isEditing: _isEditing,
                isSaving: isSaving,
                formKey: _formKey,
                nameController: _nameController,
                aboutController: _aboutController,
                user: _user,
                onEditProfile: _onEditProfile,
                onCancelEdit: _onCancelEdit,
                onSaveProfile: _onSaveProfile,
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: 'Preferences'),
              const SizedBox(height: 10),
              _SettingsGroup(
                colorScheme: colorScheme,
                children: [
                  _SettingsTile(
                    colorScheme: colorScheme,
                    iconBackground: isDarkTheme
                        ? Colors.indigo.withValues(alpha: 0.16)
                        : Colors.orange.withValues(alpha: 0.16),
                    iconColor: isDarkTheme
                        ? Colors.indigo.shade300
                        : Colors.orange.shade700,
                    icon: isDarkTheme
                        ? Icons.nightlight_rounded
                        : Icons.wb_sunny_rounded,
                    title: 'Dark mode',
                    subtitle: isDarkTheme ? 'On' : 'Off',
                    trailing: Switch.adaptive(
                      value: isDarkTheme,
                      activeThumbColor: _brandColor,
                      onChanged: (bool value) {
                        setState(() {
                          isDarkTheme = value;
                        });
                        if (value) {
                          AdaptiveTheme.of(context).setDark();
                        } else {
                          AdaptiveTheme.of(context).setLight();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionLabel(label: 'Account'),
              const SizedBox(height: 10),
              _SettingsGroup(
                colorScheme: colorScheme,
                children: [
                  _SettingsTile(
                    colorScheme: colorScheme,
                    iconBackground: colorScheme.error.withValues(alpha: 0.12),
                    iconColor: colorScheme.error,
                    icon: Icons.logout_rounded,
                    title: 'Log out',
                    titleColor: colorScheme.error,
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.colorScheme, required this.children});

  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 68,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.colorScheme,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.titleColor,
    this.onTap,
  });

  final ColorScheme colorScheme;
  final Color iconBackground;
  final Color iconColor;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
