import 'package:flutter/material.dart';

/// Single-line notes field.
class NotesSection extends StatelessWidget {
  const NotesSection({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: 'ملاحظات',
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
