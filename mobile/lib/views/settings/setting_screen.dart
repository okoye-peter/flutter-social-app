import 'dart:typed_data';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/core/utils/validators.dart';
import 'package:social_app/core/widgets/auth_submit_button.dart';
import 'package:social_app/core/widgets/auth_text_field.dart';
import 'package:social_app/models/user_model.dart';

const _brandColor = Color(0xFF0793F1);

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _imagePicker = ImagePicker();

  final _user = UserModel(
    id: '1',
    name: 'Alex Morgan',
    phoneNumber: '+2348012345678',
    image: '',
    email: '',
    fcmToken: '',
    aboutMe: 'Living my best life.',
    lastSeen: '',
    createdAt: '',
    isOnline: true,
    friendsIds: const [],
    friendRequestsIds: const [],
    sentFriendRequestsIds: const [],
  );

  Uint8List? _avatarBytes;
  bool _isUploadingAvatar = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool isDarkTheme = false;

  @override
  void initState() {
    super.initState();
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

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: _brandColor,
          toolbarWidgetColor: Colors.white,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop photo', cropStyle: CropStyle.circle),
      ],
    );
    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;

    setState(() => _isUploadingAvatar = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _avatarBytes = bytes;
      _isUploadingAvatar = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => _pickAvatar(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => _pickAvatar(ImageSource.gallery),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: _removeAvatar,
                ),
              const SizedBox(height: 8),
            ],
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

  Future<void> _onSaveProfile() async {
    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _user.name = _nameController.text.trim();
      _user.aboutMe = _aboutController.text.trim();
      _isSaving = false;
      _isEditing = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
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

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Settings',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
                          _user.name.isNotEmpty
                              ? _user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                if (_isUploadingAvatar)
                  Positioned.fill(
                    child: CircleAvatar(
                      radius: 56,
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
                    onTap: _showAvatarOptions,
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _brandColor,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2.5,
                        ),
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
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (_isEditing) ...[
                  AuthTextField(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: validateName,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _aboutController,
                    label: 'About me',
                    icon: Icons.info_outline_rounded,
                    textInputAction: TextInputAction.done,
                  ),
                ] else ...[
                  Center(
                    child: Text(
                      _user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _user.aboutMe.isNotEmpty
                          ? _user.aboutMe
                          : 'No bio added yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _user.phoneNumber,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _onCancelEdit,
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
                          isLoading: _isSaving,
                          onPressed: _onSaveProfile,
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _onEditProfile,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Preferences',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Change Theme'),
              secondary: Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
                child: Icon(
                  isDarkTheme
                      ? Icons.nightlight_rounded
                      : Icons.wb_sunny_rounded,
                  color: isDarkTheme ? Colors.black : Colors.white,
                ),
              ),
              value: isDarkTheme,
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
    );
  }
}
