import 'package:flutter/material.dart';
import 'package:social_app/core/widgets/user_avatar.dart';
import 'package:social_app/models/user_model.dart';

/// UserAvatar for a possibly-not-yet-resolved call participant (the
/// other party's UserModel is fetched async after an incoming call
/// arrives — see CallBloc._processIncomingCall).
class CallerAvatar extends StatelessWidget {
  const CallerAvatar({super.key, required this.user, required this.radius});

  final UserModel? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final image = user?.image ?? '';
    return UserAvatar(
      source: image.trim().isNotEmpty ? image : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
      radius: radius,
    );
  }
}
