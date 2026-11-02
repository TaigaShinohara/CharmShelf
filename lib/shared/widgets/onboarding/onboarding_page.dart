import 'package:flutter/material.dart';

class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.label,
    this.content,
    this.canProceed = true,
    this.descriptionBeforeContent = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final String? label;
  final Widget? content;
  final bool canProceed;
  final bool descriptionBeforeContent;
}
