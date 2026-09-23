import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';

enum CallTone { none, incoming, outgoing }

// In-app call sounds only. When the app is backgrounded/killed, the native
// CallKit/ConnectionService screen (call_kit_service.dart) rings by itself.
// Driven from CallBloc.onChange so the tone always follows call status.
class CallRingtoneService {
  final AudioPlayer _player = AudioPlayer();
  CallTone _current = CallTone.none;

  // Incoming calls ring with the device's own ringtone (Android: the
  // user's chosen ringtone; iOS doesn't expose it to apps, so the system
  // default ring sound plays). Outgoing ringback is a bundled tone.
  static const _outgoingAsset = 'assets/audio/outgoing_ringback.wav';

  Future<void> play(CallTone tone) async {
    if (tone == _current) return;
    _current = tone;
    try {
      await _player.stop();
      await FlutterRingtonePlayer().stop();
      if (tone == CallTone.none) return;
      if (tone == CallTone.incoming) {
        await FlutterRingtonePlayer().playRingtone(looping: true, asAlarm: false);
        return;
      }
      await _player.setAsset(_outgoingAsset);
      await _player.setLoopMode(LoopMode.one);
      // Guard against a newer state change landing while the asset loaded.
      if (_current == tone) await _player.play();
    } catch (e) {
      if (kDebugMode) debugPrint('Call tone failed: $e');
    }
  }

  Future<void> stop() => play(CallTone.none);

  Future<void> dispose() => _player.dispose();
}
