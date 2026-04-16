import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';

/// Full-width complexity slider widget — can be used in settings and onboarding.
class ComplexityDial extends ConsumerWidget {
  const ComplexityDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complexity = ref.watch(complexityProvider);
    final notifier = ref.read(complexityProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Simple',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accentBlue.withOpacity(0.4)),
              ),
              child: Text(
                complexityLabel(complexity),
                style: const TextStyle(
                  color: AppTheme.accentBlueLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              'Expert',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Slider(
          value: complexity.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: (val) => notifier.setComplexity(val.round()),
        ),
      ],
    );
  }
}

/// Compact inline version for the intel sheet header.
class ComplexityMiniDial extends ConsumerWidget {
  const ComplexityMiniDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complexity = ref.watch(complexityProvider);
    final notifier = ref.read(complexityProvider.notifier);

    return Row(
      children: [
        const Icon(Icons.psychology_outlined, color: AppTheme.accentBlueLight, size: 16),
        const SizedBox(width: 6),
        Text(
          complexityLabel(complexity),
          style: const TextStyle(
            color: AppTheme.accentBlueLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: complexity.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (val) => notifier.setComplexity(val.round()),
            ),
          ),
        ),
      ],
    );
  }
}
