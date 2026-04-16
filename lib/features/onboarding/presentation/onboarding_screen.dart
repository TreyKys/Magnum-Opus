import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/onboarding/providers/onboarding_provider.dart';
import 'package:magnum_opus/features/settings/providers/complexity_provider.dart';
import 'package:magnum_opus/features/settings/widgets/complexity_dial.dart';
import 'package:magnum_opus/features/vault/presentation/vault_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedPersona = '';

  // Rotating tagline
  final List<String> _taglineWords = [
    'Research',
    'Study',
    'Work',
    'Everyday',
    'Academic',
    'Professional',
    'Deep Work',
    'Analytical',
  ];
  int _taglineIndex = 0;
  Timer? _taglineTimer;

  // Page entrance animations
  late List<AnimationController> _pageControllers;
  late List<Animation<Offset>> _pageSlides;
  late List<Animation<double>> _pageFades;

  @override
  void initState() {
    super.initState();

    // Setup per-page animation controllers
    _pageControllers = List.generate(
      5,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _pageSlides = _pageControllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _pageFades = _pageControllers
        .map((c) => Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Start first page animation
    _pageControllers[0].forward();

    // Tagline rotation
    _taglineTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      setState(() {
        _taglineIndex = (_taglineIndex + 1) % _taglineWords.length;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _taglineTimer?.cancel();
    for (final c in _pageControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _pageControllers[page].forward(from: 0);
  }

  void _finish() {
    if (_selectedPersona.isEmpty) return;
    ref.read(onboardingProvider.notifier).complete(_selectedPersona);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const VaultScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildPage1(),
                  _buildPage2(),
                  _buildPage3(),
                  _buildPage4(),
                  _buildPage5(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── Page 1: Welcome ──────────────────────────────────────────────────────

  Widget _buildPage1() {
    return _PageWrapper(
      slideAnimation: _pageSlides[0],
      fadeAnimation: _pageFades[0],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            // Wordmark
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Magnum Opus',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Rotating tagline
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Your ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _taglineWords[_taglineIndex],
                    key: ValueKey(_taglineIndex),
                    style: const TextStyle(
                      color: AppTheme.accentBlueLight,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Partner for Docs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Every format. One intelligent interface.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            // Format badge grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormatBadge('PDF', AppTheme.badgePdf),
                _FormatBadge('EPUB', AppTheme.badgeEpub),
                _FormatBadge('DOCX', AppTheme.badgeDocx),
                _FormatBadge('XLSX', AppTheme.badgeXlsx),
                _FormatBadge('PPTX', AppTheme.badgePptx),
                _FormatBadge('CSV', AppTheme.badgeCsv),
                _FormatBadge('TXT', AppTheme.badgeTxt),
                _FormatBadge('MP3', AppTheme.badgeAudio),
                _FormatBadge('URL', AppTheme.badgeUrl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 2: The Brain ────────────────────────────────────────────────────

  Widget _buildPage2() {
    return _PageWrapper(
      slideAnimation: _pageSlides[1],
      fadeAnimation: _pageFades[1],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Text(
              'Anti-Hallucination',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Architecture',
              style: TextStyle(
                color: AppTheme.accentBlueLight,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Three layers that keep the AI grounded in your documents.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _BrainCard(
              step: '01',
              title: 'Global Skeleton',
              description:
                  'A 200-word macro-summary is generated on ingest and pinned to every query. The AI never loses the overarching context.',
              icon: Icons.account_tree_outlined,
              color: AppTheme.accentBlue,
            ),
            const SizedBox(height: 16),
            _BrainCard(
              step: '02',
              title: 'Top-15 Semantic Fetch',
              description:
                  'Retrieves the 15 most relevant chunks plus their adjacent paragraphs, ensuring unbroken context continuity.',
              icon: Icons.manage_search,
              color: AppTheme.accentBlueLight,
            ),
            const SizedBox(height: 16),
            _BrainCard(
              step: '03',
              title: 'Traceback Citations',
              description:
                  'Every AI response ends with exact source references — [Source: Page 42] — so you can verify every claim.',
              icon: Icons.verified_outlined,
              color: const Color(0xFF16A34A),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 3: Complexity Dial ──────────────────────────────────────────────

  Widget _buildPage3() {
    return _PageWrapper(
      slideAnimation: _pageSlides[2],
      fadeAnimation: _pageFades[2],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Text(
              'Your Complexity Dial',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Slide to control how deep the AI goes. It resets nothing — it simply changes how the AI speaks.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            const ComplexityDial(),
            const SizedBox(height: 32),
            _ComplexityPreviewCard(),
          ],
        ),
      ),
    );
  }

  // ─── Page 4: Pro Features ─────────────────────────────────────────────────

  Widget _buildPage4() {
    return _PageWrapper(
      slideAnimation: _pageSlides[3],
      fadeAnimation: _pageFades[3],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Text(
              'Magnum Opus Pro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '\$7.99 / month  ·  \$69.99 / year  ·  \$159.99 lifetime',
              style:
                  TextStyle(color: AppTheme.accentBlueLight, fontSize: 13),
            ),
            const SizedBox(height: 32),
            _ProFeatureRow(
              icon: Icons.all_inclusive,
              title: 'Unlimited Queries',
              subtitle: 'No daily caps. Query forever.',
            ),
            _ProFeatureRow(
              icon: Icons.mic_outlined,
              title: 'Audio Transcription',
              subtitle: 'Upload lectures — AI transcribes & indexes.',
            ),
            _ProFeatureRow(
              icon: Icons.language,
              title: 'URL Scraping',
              subtitle: 'Turn any web page into a queryable document.',
            ),
            _ProFeatureRow(
              icon: Icons.picture_as_pdf_outlined,
              title: '1-Tap Export',
              subtitle: 'Compile chat threads into clean PDF reports.',
            ),
            _ProFeatureRow(
              icon: Icons.menu_book_outlined,
              title: 'EPUB & DOCX Ingestion',
              subtitle: 'Textbooks, papers, and Word documents.',
            ),
            _ProFeatureRow(
              icon: Icons.table_chart_outlined,
              title: 'XLSX & PPTX Support',
              subtitle: 'Financial models and slide decks.',
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Free tier: PDF & TXT · 5 queries/day · 1 free audio transcription · Unlimited document size',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 5: Persona ─────────────────────────────────────────────────────

  Widget _buildPage5() {
    const personas = [
      _PersonaData('Student', Icons.school_outlined,
          'Lecture notes, textbooks, past papers'),
      _PersonaData('Researcher', Icons.biotech_outlined,
          'Papers, whitepapers, datasets'),
      _PersonaData('Professional', Icons.business_center_outlined,
          'Reports, contracts, briefings'),
      _PersonaData('Founder', Icons.rocket_launch_outlined,
          'Market research, pitch decks, legal'),
      _PersonaData('Analyst', Icons.analytics_outlined,
          'Financial models, spreadsheets, slides'),
      _PersonaData('Curious Mind', Icons.explore_outlined,
          'Books, articles, anything that interests you'),
    ];

    return _PageWrapper(
      slideAnimation: _pageSlides[4],
      fadeAnimation: _pageFades[4],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'How will you use\nMagnum Opus?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'This helps us tailor your default experience.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: personas
                    .map((p) => _PersonaCard(
                          data: p,
                          selected: _selectedPersona == p.label,
                          onTap: () => setState(
                              () => _selectedPersona = p.label),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPersona.isNotEmpty ? _finish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  disabledBackgroundColor: AppTheme.border,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Bottom navigation ────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back / Skip
          if (_currentPage > 0)
            TextButton(
              onPressed: () => _goToPage(_currentPage - 1),
              child: const Text(
                'Back',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            const SizedBox(width: 64),
          // Dot indicators
          Row(
            children: List.generate(
              5,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? AppTheme.accentBlue
                      : AppTheme.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          // Next
          if (_currentPage < 4)
            TextButton(
              onPressed: () => _goToPage(_currentPage + 1),
              child: const Text(
                'Next',
                style: TextStyle(
                  color: AppTheme.accentBlueLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 64),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PageWrapper extends StatelessWidget {
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;
  final Widget child;

  const _PageWrapper({
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _FormatBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BrainCard extends StatelessWidget {
  final String step;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _BrainCard({
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$step  $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplexityPreviewCard extends ConsumerWidget {
  const _ComplexityPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complexity = ref.watch(complexityProvider);
    final label = complexityLabel(complexity);

    final String exampleText;
    if (complexity <= 20) {
      exampleText =
          'Think of it like a recipe. The document is your cookbook and I\'m the chef who reads it for you!';
    } else if (complexity <= 45) {
      exampleText =
          'This section explains the core concept in straightforward terms, breaking it into steps you can follow.';
    } else if (complexity <= 65) {
      exampleText =
          'The document presents a structured framework with three key components: methodology, implementation, and evaluation criteria.';
    } else if (complexity <= 80) {
      exampleText =
          'The author employs a mixed-methods approach, combining quantitative regression analysis with qualitative thematic coding to establish causal inference.';
    } else {
      exampleText =
          'The epistemological underpinnings rely on Bayesian inference under a frequentist-compatible prior, yielding a posterior predictive distribution across the latent variable space.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accentBlue, size: 14),
              const SizedBox(width: 6),
              Text(
                'Response preview — $label mode',
                style: const TextStyle(
                  color: AppTheme.accentBlueLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              exampleText,
              key: ValueKey(label),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppTheme.accentBlueLight, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonaData {
  final String label;
  final IconData icon;
  final String description;
  const _PersonaData(this.label, this.icon, this.description);
}

class _PersonaCard extends StatelessWidget {
  final _PersonaData data;
  final bool selected;
  final VoidCallback onTap;

  const _PersonaCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentBlue.withOpacity(0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.accentBlue : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              data.icon,
              color: selected ? AppTheme.accentBlueLight : AppTheme.textMuted,
              size: 24,
            ),
            const Spacer(),
            Text(
              data.label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
