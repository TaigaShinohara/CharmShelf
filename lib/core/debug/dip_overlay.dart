import 'package:flutter/material.dart';

import 'dip_feature_registry.dart';
import 'dip_menu.dart';

/// DIPメニューを表示するオーバーレイ
class DipOverlay extends StatefulWidget {
  const DipOverlay({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  State<DipOverlay> createState() => DipOverlayState();
}

class DipOverlayState extends State<DipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final features = DipFeatureRegistry.instance.featuresByCategory;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 背景タップで閉じる
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _close,
                child: Container(color: Colors.black54),
              ),
            ),
          ),
          // メニューパネル
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: DipMenu(features: features, onClose: _close),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
