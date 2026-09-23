import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';
import 'package:social_app/views/calls/widgets/call_control_button.dart';
import 'package:social_app/views/calls/widgets/caller_avatar.dart';

class InCallScreen extends StatefulWidget {
  const InCallScreen({super.key});

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  bool _localRendererReady = false;

  @override
  void initState() {
    super.initState();
    final stream = context.read<CallBloc>().localStream;
    _initLocalRenderer(stream);
  }

  Future<void> _initLocalRenderer(MediaStream? stream) async {
    await _localRenderer.initialize();
    if (stream != null) _localRenderer.srcObject = stream;
    if (mounted) setState(() => _localRendererReady = true);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              final isVideo = state.type == CallType.video;
              final remoteRenderers = context.read<CallBloc>().remoteRenderers;
              final showRemoteVideo = isVideo && remoteRenderers.isNotEmpty;

              return Stack(
                children: [
                  if (showRemoteVideo)
                    _RemoteVideoArea(renderers: remoteRenderers)
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CallerAvatar(user: state.otherUser, radius: 56),
                          const SizedBox(height: 16),
                          Text(
                            state.otherUser?.name ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.status == CallStatus.connecting
                                ? 'Connecting…'
                                : _formatElapsed(state.elapsed),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  if (isVideo && _localRendererReady && state.localVideoEnabled)
                    Positioned(
                      top: 16,
                      right: 16,
                      width: 100,
                      height: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RTCVideoView(_localRenderer, mirror: true),
                      ),
                    ),
                  if (showRemoteVideo && state.status == CallStatus.active)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Text(
                        _formatElapsed(state.elapsed),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        CallControlButton(
                          icon: state.localMuted ? Icons.mic_off : Icons.mic,
                          onPressed: () => context.read<CallBloc>().add(const ToggleMuteEvent()),
                        ),
                        if (isVideo)
                          CallControlButton(
                            icon: state.localVideoEnabled ? Icons.videocam : Icons.videocam_off,
                            onPressed: () => context.read<CallBloc>().add(const ToggleCameraEvent()),
                          ),
                        CallControlButton(
                          icon: state.speakerOn ? Icons.volume_up : Icons.volume_off,
                          onPressed: () => context.read<CallBloc>().add(const ToggleSpeakerEvent()),
                        ),
                        CallControlButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          onPressed: () => context.read<CallBloc>().add(const LeaveCallEvent()),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RemoteVideoArea extends StatelessWidget {
  const _RemoteVideoArea({required this.renderers});

  final Map<String, RTCVideoRenderer> renderers;

  @override
  Widget build(BuildContext context) {
    final entries = renderers.entries.toList();
    if (entries.length == 1) {
      return RTCVideoView(
        entries.first.value,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: entries.length,
      itemBuilder: (context, index) => RTCVideoView(
        entries[index].value,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}
