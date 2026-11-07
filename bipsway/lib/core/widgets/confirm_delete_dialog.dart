import 'package:flutter/material.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({required this.title, required this.message, super.key});

  final String title;
  final String message;

  static Future<bool> show(
    BuildContext context, {
    String title = 'Confirm Delete',
    String message = 'This action cannot be undone.',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ConfirmDeleteDialog(
            title: title,
            message: message,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      );
}
