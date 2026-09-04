import 'package:flutter/material.dart';

import 'glass_card.dart';

/// A metric tile card with a glow icon and value.
///
/// All colors are derived from the active Material 3 `ColorScheme` so
/// the tile reads correctly in both light and dark mode. A legacy
/// `textColor` parameter is kept for back-compat with call sites that
/// wanted white-on-dark, but it now only acts as a hint: when not
/// explicitly overridden, we use `scheme.onSurface` instead of
/// `Colors.white` (which used to be unreadable on a light card).
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.textColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = scheme.onSurface;
    final effectiveText =
        textColor == Colors.transparent ? fallback : textColor;
    final muted = effectiveText.withValues(alpha: 0.6);
    
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: effectiveText,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
