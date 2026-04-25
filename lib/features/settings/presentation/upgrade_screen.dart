import 'package:flutter/material.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';

class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Upgrade',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 28),
            const _TierCard(
              tier: 'Free',
              price: 'Current plan',
              isCurrent: true,
              features: [
                '5 AI queries per day',
                '5 active chat sessions',
                '3 audio document ingests',
                'PDF, DOCX, PPTX, XLSX, EPUB',
                'Gemini 2.5 Flash powered',
              ],
            ),
            const SizedBox(height: 16),
            const _TierCard(
              tier: 'Pro',
              price: '\$7.99 / month',
              isCurrent: false,
              features: [
                'Unlimited AI queries',
                'Unlimited chat sessions',
                'Unlimited audio ingests',
                'Priority response speed',
                'All Free features included',
              ],
            ),
            const SizedBox(height: 16),
            const _TierCard(
              tier: 'Lifetime',
              price: '\$159.99 once',
              isCurrent: false,
              isLifetime: true,
              features: [
                'Everything in Pro — forever',
                'All future feature updates',
                'No recurring charges',
                'Priority support',
              ],
            ),
            const SizedBox(height: 28),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bolt, color: AppTheme.accentBlue, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unlock Your Full Potential',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Upgrade for unlimited access to your AI document intelligence assistant.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final String tier;
  final String price;
  final bool isCurrent;
  final bool isLifetime;
  final List<String> features;

  const _TierCard({
    required this.tier,
    required this.price,
    required this.isCurrent,
    required this.features,
    this.isLifetime = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent
        ? AppTheme.border
        : isLifetime
            ? const Color(0xFFFFD700)
            : AppTheme.accentBlue;

    final badgeColor = isCurrent
        ? AppTheme.surfaceVariant
        : isLifetime
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : AppTheme.accentBlue.withOpacity(0.12);

    final badgeTextColor = isCurrent
        ? AppTheme.textMuted
        : isLifetime
            ? const Color(0xFFFFD700)
            : AppTheme.accentBlueLight;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 1 : 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(
                          color: isCurrent ? AppTheme.textMuted : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'YOUR PLAN',
                    style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isCurrent ? AppTheme.textMuted : AppTheme.accentBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                            color: isCurrent ? AppTheme.textMuted : Colors.white70,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
          if (!isCurrent) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLifetime
                      ? const Color(0xFFFFD700).withOpacity(0.15)
                      : AppTheme.accentBlue.withOpacity(0.15),
                  disabledBackgroundColor: isLifetime
                      ? const Color(0xFFFFD700).withOpacity(0.15)
                      : AppTheme.accentBlue.withOpacity(0.15),
                  foregroundColor: isLifetime
                      ? const Color(0xFFFFD700)
                      : AppTheme.accentBlueLight,
                  disabledForegroundColor: isLifetime
                      ? const Color(0xFFFFD700)
                      : AppTheme.accentBlueLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_outlined, color: AppTheme.accentBlueLight, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Powered by Gemini 2.5 Flash · All processing on-device',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
