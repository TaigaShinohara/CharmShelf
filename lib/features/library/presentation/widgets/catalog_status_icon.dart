import 'package:flutter/material.dart';

class CatalogStatusIcon extends StatelessWidget {
  const CatalogStatusIcon.pin({super.key, this.size = 21})
    : _type = _CatalogStatusIconType.pin;
  const CatalogStatusIcon.favorite({super.key, this.size = 21})
    : _type = _CatalogStatusIconType.favorite;
  const CatalogStatusIcon.hidden({super.key, this.size = 21})
    : _type = _CatalogStatusIconType.hidden;

  final _CatalogStatusIconType _type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: _type == _CatalogStatusIconType.favorite
          ? [
              Color.lerp(colorScheme.error, Colors.white, 0.28)!,
              colorScheme.error,
            ]
          : [
              Colors.white,
              Color.lerp(Colors.white, colorScheme.primary, 0.18)!,
            ],
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: gradient.createShader,
        child: Icon(
          switch (_type) {
            _CatalogStatusIconType.favorite => Icons.favorite,
            _CatalogStatusIconType.hidden => Icons.visibility_off,
            _CatalogStatusIconType.pin => Icons.push_pin,
          },
          color: Colors.white,
          size: size * 0.71,
        ),
      ),
    );
  }
}

enum _CatalogStatusIconType { pin, favorite, hidden }
