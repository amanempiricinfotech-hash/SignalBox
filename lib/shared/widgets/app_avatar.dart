import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/installed_apps_provider.dart';

/// Avatar for an application.
///
/// Shows the real launcher icon read from the device's package manager. While
/// it loads, or when the app is not installed (history is kept after an
/// uninstall), it falls back to a monogram on a colour derived from the
/// package name, which stays stable across restarts.
class AppAvatar extends ConsumerWidget {
  const AppAvatar({
    required this.packageName,
    required this.label,
    this.size = 40,
    super.key,
  });

  final String packageName;
  final String label;
  final double size;

  static const List<Color> _palette = [
    Color(0xFF3E63DD),
    Color(0xFF2E9E5B),
    Color(0xFFE5A32A),
    Color(0xFF8E4EC6),
    Color(0xFFE5484D),
    Color(0xFF0D9488),
    Color(0xFFD6409F),
  ];

  Color get _color {
    if (packageName.isEmpty) return _palette.first;
    final hash = packageName.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = packageName.isEmpty
        ? null
        : ref.watch(appIconProvider(packageName)).valueOrNull;

    return Semantics(
      label: '$label icon',
      child: SizedBox(
        width: size,
        height: size,
        child: icon == null
            ? _Monogram(label: label, color: _color, size: size)
            : ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.3),
                child: Image.memory(
                  icon,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stack) =>
                      _Monogram(label: label, color: _color, size: size),
                ),
              ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.label,
    required this.color,
    required this.size,
  });

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
