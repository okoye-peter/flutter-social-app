import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:social_app/core/enums/app_enums.dart';

/// Themed [Fluttertoast] wrapper — red/white for errors, green for success,
/// amber/black for warnings, and a neutral dark toast for everything else.
class AppToast {
  AppToast._();

  static void success(String message) => _show(message, ToastKind.success);

  static void error(String message) => _show(message, ToastKind.error);

  static void warning(String message) => _show(message, ToastKind.warning);

  static void show(String message) => _show(message, ToastKind.info);

  static void _show(String message, ToastKind kind) {
    final style = _styleFor(kind);

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: style.background,
      textColor: style.foreground,
      fontSize: 15,
    );
  }

  static _ToastStyle _styleFor(ToastKind kind) {
    switch (kind) {
      case ToastKind.success:
        return const _ToastStyle(
          background: Color(0xFF2E7D32),
          foreground: Colors.white,
        );
      case ToastKind.error:
        return const _ToastStyle(
          background: Color(0xFFD32F2F),
          foreground: Colors.white,
        );
      case ToastKind.warning:
        return const _ToastStyle(
          background: Color(0xFFFFA000),
          foreground: Colors.black87,
        );
      case ToastKind.info:
        return const _ToastStyle(
          background: Color(0xFF323232),
          foreground: Colors.white,
        );
    }
  }
}

class _ToastStyle {
  const _ToastStyle({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
