import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppBrandIcon extends StatefulWidget {
  const AppBrandIcon({
    super.key,
    this.size = 48,
    this.fit = BoxFit.contain,
    this.semanticsLabel = 'CharmShelf icon',
  });

  static const String assetPath = 'assets/images/icon/private_shelf_icon.svg';

  final double size;
  final BoxFit fit;
  final String semanticsLabel;

  @override
  State<AppBrandIcon> createState() => _AppBrandIconState();
}

class _AppBrandIconState extends State<AppBrandIcon> {
  late final Future<String> _svgContentFuture;

  @override
  void initState() {
    super.initState();
    _svgContentFuture = rootBundle.loadString(AppBrandIcon.assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _svgContentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasData) {
          return SvgPicture.string(
            snapshot.data!,
            width: widget.size,
            height: widget.size,
            fit: widget.fit,
            semanticsLabel: widget.semanticsLabel,
            placeholderBuilder: (_) => SizedBox(
              width: widget.size,
              height: widget.size,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(widget.size * 0.22),
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              size: widget.size * 0.48,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        );
      },
    );
  }
}
