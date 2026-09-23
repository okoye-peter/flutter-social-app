import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether onboarding has been completed, read live by the router's
/// redirect logic (see `buildRouter`) — a plain bool captured once at app
/// launch would leave the router stuck thinking onboarding is incomplete
/// even after `OnboardingRepository.completeOnboarding()` persists it,
/// since nothing would ever update that captured value.
class OnboardingStatusNotifier extends ValueNotifier<bool> {
  OnboardingStatusNotifier(super.hasSeenOnboarding);
}

class OnboardingRepository {
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
