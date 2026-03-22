import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magnum_opus/features/vault/presentation/dashboard_screen.dart';

class IntroScreen extends ConsumerStatefulWidget {
  final bool fromSettings;
  const IntroScreen({super.key, this.fromSettings = false});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'The Ultimate Reader',
      'description': 'Instantly parse PDF, DOCX, XLSX, and PPTX with local AI intelligence.',
      'icon': 'description',
    },
    {
      'title': 'Surround Sound AI',
      'description': 'Never lose context. Our microscopic RAG engine remembers your exact chat history across massive documents.',
      'icon': 'speaker_group',
    },
    {
      'title': 'Sniper Vision',
      'description': 'Point. Shoot. Solve. Multimodal image capture extracts meaning from complex diagrams and formulas instantly.',
      'icon': 'my_location',
    },
    {
      'title': '10 Micro-Tools',
      'description': 'Merge, split, compress, extract, translate, and encrypt your files offline with military-grade precision.',
      'icon': 'build_circle',
    },
    {
      'title': 'The Economy',
      'description': 'Start with free AI Energy. Refill it via ads, or unlock Magnum Pro for infinite power and premium tools.',
      'icon': 'bolt',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() async {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (!widget.fromSettings) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_seen_intro', true);
      }
      if (mounted) {
        if (widget.fromSettings) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    }
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'description': return Icons.description_outlined;
      case 'speaker_group': return Icons.speaker_group_outlined;
      case 'my_location': return Icons.my_location_outlined;
      case 'build_circle': return Icons.build_circle_outlined;
      case 'bolt': return Icons.bolt_outlined;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A1A1A),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                          ),
                          child: Icon(
                            _getIcon(page['icon']!),
                            size: 80,
                            color: const Color(0xFFB026FF),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          page['title']!,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          page['description']!,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF00E5FF)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: _onNext,
                    backgroundColor: const Color(0xFFB026FF),
                    child: Icon(
                      _currentPage == _pages.length - 1 ? Icons.check : Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
