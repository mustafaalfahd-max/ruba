import 'package:flutter/material.dart';

import '../../theme.dart';

/// الإطار الموحّد لشاشات المكدّس: سهم رجوع، عنوان، وإجراء اختياري في الطرف.
class StackScaffold extends StatelessWidget {
  const StackScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.bottom,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: RC.hair(.07))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(Icons.arrow_forward_rounded,
                          size: 23, color: RC.ink2),
                      tooltip: 'رجوع',
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (actionLabel != null)
                      TextButton(
                        onPressed: onAction,
                        child: Text(
                          actionLabel!,
                          style: TextStyle(color: RC.cyanDark, fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: child),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      );
}
