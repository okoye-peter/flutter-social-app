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
import 'package:social_app/models/create_story_model.dart';
import 'package:social_app/models/user_model.dart';
import 'package:social_app/viewmodels/stories/story_bloc.dart';
import 'package:social_app/views/feeds/widgets/add_media_badge.dart';
import 'package:social_app/views/feeds/widgets/remove_media_button.dart';
import 'package:social_app/views/feeds/widgets/video_background.dart';
import 'package:video_player/video_player.dart';

/// Adds a story — unlike [CreateFeedScreen], a photo or video is
/// mandatory: there's no text-only story here, so the empty state is a
/// call to action rather than a live preview, and "Share" stays
/// disabled until media is attached.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  ComposeMediaType _mediaType = ComposeMediaType.none;
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  bool get _canShare => _mediaType != ComposeMediaType.none;

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    try {
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
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Could not load that photo');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    Navigator.of(context).pop();
    VideoPlayerController? controller;
    try {
      final picked = await _imagePicker.pickVideo(source: source);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      controller = VideoPlayerController.file(File(picked.path))
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
        _videoController = controller!..play();
        _mediaType = ComposeMediaType.video;
      });
    } catch (_) {
      controller?.dispose();
      if (!mounted) return;
      AppToast.error('Could not load that video');
    }
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

  void _onShare(BuildContext context) {
    final (media, mediaType) = switch (_mediaType) {
      ComposeMediaType.image => (_imageBytes, MediaType.image),
      ComposeMediaType.video => (_videoBytes, MediaType.video),
      ComposeMediaType.none => (null, null),
    };
    if (media == null || mediaType == null) return;

    context.read<StoryBloc>().add(
      CreateStoryEvent(
        story: CreateStoryModel(
          media: media,
          mediaType: mediaType,
          caption: _captionController.text.trim(),
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
        return _StoryEmptyState(onTap: _showMediaPicker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoryBloc(),
      child: BlocConsumer<StoryBloc, StoryState>(
        listener: (context, state) {
          if (state is LoadedCreateStoryState) {
            AppToast.success('Your story was shared');
            context.pop(true);
          } else if (state is StoryErrorState) {
            AppToast.error(state.message);
          }
        },
        builder: (context, state) {
          final isSharing = state is CreatingStoryState;
          return _buildScaffold(context, isSharing: isSharing);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, {required bool isSharing}) {
    final UserModel? user = getIt<UserCache>().current;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close, size: 26),
          tooltip: 'Close',
        ),
        title: const Text('Add to story'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: (_canShare && !isSharing)
                  ? () => _onShare(context)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: brandColor,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: isSharing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Share',
                      style: TextStyle(fontWeight: FontWeight.w700 , color: Colors.white),
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
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    user?.username ?? 'you',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _mediaType == ComposeMediaType.none
                    ? _showMediaPicker
                    : null,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildMediaPreview(),
                        if (_mediaType != ComposeMediaType.none)
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
              if (_mediaType != ComposeMediaType.none) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _captionController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Add a caption...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryEmptyState extends StatelessWidget {
  const _StoryEmptyState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF1A1A1A)),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white12,
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  size: 26,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add a photo or video',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'A story needs a photo or video — tap to choose one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
