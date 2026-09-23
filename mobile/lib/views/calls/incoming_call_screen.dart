import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';
import 'package:social_app/views/calls/widgets/call_control_button.dart';
import 'package:social_app/views/calls/widgets/caller_avatar.dart';

/// Foreground-only in-app incoming-call screen. When the app is
/// backgrounded/locked, CallKit/ConnectionService's native screen is used
/// instead — this Flutter screen is never shown in that case.
class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              return SizedBox.expand(
                child: Column(
                children: [
                  const Spacer(),
                  CallerAvatar(user: state.otherUser, radius: 56),
                  const SizedBox(height: 20),
                  Text(
                    state.otherUser?.name ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.type == CallType.video ? 'Incoming video call' : 'Incoming voice call',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CallControlButton(
                          icon: Icons.call_end,
                          backgroundColor: Colors.red,
                          onPressed: () => context.read<CallBloc>().add(const DeclineCallEvent()),
                        ),
                        CallControlButton(
                          icon: Icons.call,
                          backgroundColor: Colors.green,
                          onPressed: () => context.read<CallBloc>().add(const AcceptCallEvent()),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
