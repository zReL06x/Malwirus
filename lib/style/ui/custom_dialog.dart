import 'package:flutter/material.dart';
import '../theme.dart';

Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  required VoidCallback onConfirm,
  required String cancelText,
  required VoidCallback onCancel,
  Widget? contentWidget,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.dialogBackground(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: title.isNotEmpty
          ? Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
              ),
            )
          : null,
      content: contentWidget ?? Text(message, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(confirmText, style: TextStyle(color: AppTheme.primaryColor)),
        ),
      ],
    ),
  );
}

/// Shows a lightweight, bottom toast-style notification using Overlay.
///
/// Follows app theming (light/dark) and matches the simple pop-up design
/// requested. Use this instead of SnackBar for ephemeral messages.
// Internal singleton state so toasts never stack
OverlayEntry? _appToastEntry;
bool _appToastActive = false;
String? _appToastQueuedMessage;
Duration? _appToastQueuedDuration;

void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1800),
}) {
  // If a toast is currently visible, queue the latest request and return.
  if (_appToastActive) {
    _appToastQueuedMessage = message;
    _appToastQueuedDuration = duration;
    return;
  }

  final overlay = Overlay.of(context);
  if (overlay == null) return;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // Remove any previous toasts by keying them uniquely if needed.
  _appToastActive = true;
  _appToastEntry?.remove();
  _appToastEntry = OverlayEntry(
    builder: (ctx) {
      // Position near bottom with safe area padding.
      final media = MediaQuery.of(ctx);
      final bottomPadding = media.viewInsets.bottom + media.padding.bottom;
      return Positioned(
        left: 16,
        right: 16,
        bottom: bottomPadding + 16,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(_appToastEntry!);
  Future.delayed(duration, () {
    try {
      _appToastEntry?.remove();
    } catch (_) {}
    _appToastEntry = null;
    _appToastActive = false;
    // If a toast was queued while showing, display it next
    final nextMessage = _appToastQueuedMessage;
    final nextDuration = _appToastQueuedDuration ?? const Duration(milliseconds: 1800);
    _appToastQueuedMessage = null;
    _appToastQueuedDuration = null;
    if (nextMessage != null) {
      // Use the same context; Overlay.of(context) still valid
      showAppToast(context, nextMessage, duration: nextDuration);
    }
  });
}
