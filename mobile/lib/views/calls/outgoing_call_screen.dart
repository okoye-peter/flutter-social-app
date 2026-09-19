import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/core/enums/app_enums.dart';
import 'package:social_app/viewmodels/call/call_bloc.dart';
import 'package:social_app/views/calls/widgets/call_control_button.dart';
import 'package:social_app/views/calls/widgets/caller_avatar.dart';

class OutgoingCallScreen extends StatelessWidget {
  const OutgoingCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: BlocBuilder<CallBloc, CallState>(
            builder: (context, state) {
              // SizedBox.expand: a bare Column hugs its widest child and
              // gets placed at the left edge instead of centered.
              return SizedBox.expand(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CallerAvatar(user: state.otherUser, radius: 56),
                  const SizedBox(height: 20),
                  Text(
                    state.otherUser?.name ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.type == CallType.video ? 'Video calling…' : 'Calling…',
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 64),
                  CallControlButton(
                    icon: Icons.call_end,
                    backgroundColor: Colors.red,
                    onPressed: () => context.read<CallBloc>().add(const LeaveCallEvent()),
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
