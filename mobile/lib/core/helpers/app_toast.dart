import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum _ToastKind { success, error, warning, info }

/// Themed [Fluttertoast] wrapper — red/white for errors, green for success,
/// amber/black for warnings, and a neutral dark toast for everything else.
class AppToast {
  AppToast._();

  static void success(String message) => _show(message, _ToastKind.success);

  static void error(String message) => _show(message, _ToastKind.error);

  static void warning(String message) => _show(message, _ToastKind.warning);

  static void show(String message) => _show(message, _ToastKind.info);

  static void _show(String message, _ToastKind kind) {
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

  static _ToastStyle _styleFor(_ToastKind kind) {
    switch (kind) {
      case _ToastKind.success:
        return const _ToastStyle(
          background: Color(0xFF2E7D32),
          foreground: Colors.white,
        );
      case _ToastKind.error:
        return const _ToastStyle(
          background: Color(0xFFD32F2F),
          foreground: Colors.white,
        );
      case _ToastKind.warning:
        return const _ToastStyle(
          background: Color(0xFFFFA000),
          foreground: Colors.black87,
        );
      case _ToastKind.info:
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
