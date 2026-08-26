import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/core/helpers/app_toast.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/create_post_model.dart';
import 'package:social_app/models/sound_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/repositories/sound_repository.dart';
import 'package:social_app/viewmodels/posts/post_bloc.dart';
import 'package:social_app/views/feeds/widgets/add_media_badge.dart';
import 'package:social_app/views/feeds/widgets/compose_option_tile.dart';
import 'package:social_app/views/feeds/widgets/remove_media_button.dart';
import 'package:social_app/views/feeds/widgets/text_background.dart';
import 'package:social_app/views/feeds/widgets/video_background.dart';
import 'package:video_player/video_player.dart';

/// Mirrors the backend's MAX_CAPTION_LENGTH (see services/post.ts).
const _maxCaptionLength = 2200;

/// Composes a new post — text, image, or video, mirroring the backend's
/// `MediaType`, which is derived from whatever media (if any) gets
/// attached rather than picked explicitly.
class CreateFeedScreen extends StatefulWidget {
  const CreateFeedScreen({super.key});

  @override
  State<CreateFeedScreen> createState() => _CreateFeedScreenState();
}

class _CreateFeedScreenState extends State<CreateFeedScreen> {
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  ComposeMediaType _mediaType = ComposeMediaType.none;
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  VideoPlayerController? _videoController;
  String _caption = '';
  SoundModel? _selectedSound;

  /// Fixed once per compose session so the text-post preview color
  /// doesn't jump around as the caption is typed.
  final _textBackgroundSeed = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() {
      setState(() => _caption = _captionController.text);
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _caption.trim().isNotEmpty || _mediaType != ComposeMediaType.none;

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    _disposeVideo();
    setState(() {
      _imageBytes = bytes;
      _videoBytes = null;
      _mediaType = ComposeMediaType.image;
    });
  }

  Future<void> _pickVideo(ImageSource source) async {
    Navigator.of(context).pop();
    final picked = await _imagePicker.pickVideo(source: source);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final controller = VideoPlayerController.file(File(picked.path))
      ..setLooping(true)
      ..setVolume(0);
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }

    _disposeVideo();
    setState(() {
      _imageBytes = null;
      _videoBytes = bytes;
      _videoController = controller..play();
      _mediaType = ComposeMediaType.video;
      _selectedSound = null;
    });
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  void _removeMedia() {
    setState(() {
      _imageBytes = null;
      _videoBytes = null;
      _disposeVideo();
      _mediaType = ComposeMediaType.none;
    });
  }

  void _createPost(BuildContext context) {
    final media = switch (_mediaType) {
      ComposeMediaType.image => _imageBytes,
      ComposeMediaType.video => _videoBytes,
      ComposeMediaType.none => null,
    };

    context.read<PostBloc>().add(
      CreatePostEvent(
        post: CreatePostModel(
          kind: PostKind.post.name.toUpperCase(),
          caption: _captionController.text.trim(),
          soundId: _mediaType == ComposeMediaType.video
              ? null
              : _selectedSound?.id,
          file: media,
          mediaType: switch (_mediaType) {
            ComposeMediaType.image => MediaType.image,
            ComposeMediaType.video => MediaType.video,
            ComposeMediaType.none => null,
          },
        ),
      ),
    );
  }

  void _showMediaPicker() {
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
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Photo from gallery'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video from gallery'),
                onTap: () => _pickVideo(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.video_camera_back_outlined),
                title: const Text('Record a video'),
                onTap: () => _pickVideo(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<List<SoundModel>> _fetchSounds() {
    return SoundRepository().listSounds();
  }

  void _showSoundPicker() {
    final soundsFuture = _fetchSounds();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: FutureBuilder<List<SoundModel>>(
              future: soundsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load sounds',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }

                final sounds = snapshot.data ?? const [];
                if (sounds.isEmpty) {
                  return const Center(child: Text('No sounds yet'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sounds.length + (_selectedSound == null ? 0 : 1),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (_selectedSound != null && index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.music_off_rounded),
                        title: const Text('Remove sound'),
                        onTap: () {
                          setState(() => _selectedSound = null);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    }

                    final soundIndex = _selectedSound == null
                        ? index
                        : index - 1;
                    final sound = sounds[soundIndex];
                    final selected = sound.id == _selectedSound?.id;

                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.music_note_rounded,
                        color: selected ? brandColor : null,
                      ),
                      title: Text(sound.title),
                      subtitle: Text('${sound.usageCount} uses'),
                      onTap: () {
                        setState(() => _selectedSound = sound);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaPreview() {
    switch (_mediaType) {
      case ComposeMediaType.image:
        return Image.memory(_imageBytes!, fit: BoxFit.cover);
      case ComposeMediaType.video:
        final controller = _videoController;
        return controller != null && controller.value.isInitialized
            ? VideoBackground(controller: controller)
            : const ColoredBox(color: Colors.black);
      case ComposeMediaType.none:
        // Live preview of the WhatsApp-style text post this becomes
        // when nothing is attached — same widget the feed itself uses.
        return TextBackground(
          text: _caption.trim().isEmpty
              ? 'Your text post will look like this'
              : _caption,
          colorSeed: _textBackgroundSeed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final UserModel? user = getIt<UserCache>().current;

    return BlocProvider(
      create: (context) => PostBloc(),
      child: BlocConsumer<PostBloc, PostState>(
        listener: (context, state) {
          if (state is PostCreatedState) {
            AppToast.success('post created successfully');
            context.pop();
          }

          if (state is PostErrorState) {
            AppToast.error(state.message);
          }
        },
        builder: (context, state) {
          final bool isLoading = state is PostLoadingState;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, size: 26),
              ),
              title: const Text('New post'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton(
                    onPressed: _canPost && isLoading == false
                        ? () => _createPost(context)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: brandColor,
                      disabledBackgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: isLoading ? const CircularProgressIndicator() : const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          source: (user?.image.trim().isNotEmpty ?? false)
                              ? user!.image
                              : (user?.getInitials ?? '?'),
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          user?.username ?? 'you',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _captionController,
                      maxLines: null,
                      minLines: 3,
                      maxLength: _maxCaptionLength,
                      style: const TextStyle(fontSize: 16),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_caption.length}/$_maxCaptionLength',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _mediaType == ComposeMediaType.none
                          ? _showMediaPicker
                          : null,
                      child: AspectRatio(
                        aspectRatio: 6 / 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildMediaPreview(),
                              if (_mediaType == ComposeMediaType.none) ...[
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: AddMediaBadge(),
                                ),
                              ] else
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: RemoveMediaButton(onTap: _removeMedia),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_mediaType != ComposeMediaType.video)
                      ComposeOptionTile(
                        icon: Icons.music_note_rounded,
                        label: _selectedSound == null
                            ? 'Add sound'
                            : _selectedSound!.title,
                        subtitle: _selectedSound == null
                            ? "Use audio from a video you've posted"
                            : 'Tap to change or remove sound',
                        onTap: _showSoundPicker,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
