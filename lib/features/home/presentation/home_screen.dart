import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/chat/presentation/standalone_chat_screen.dart';
import 'package:magnum_opus/features/chat/providers/standalone_chat_provider.dart';
import 'package:magnum_opus/features/onboarding/providers/onboarding_provider.dart';
import 'package:magnum_opus/features/settings/providers/energy_provider.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/presentation/document_chat_screen.dart';
import 'package:magnum_opus/features/vault/presentation/document_view_screen.dart';
import 'package:magnum_opus/features/vault/presentation/pdf_viewer_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final energy = ref.watch(energyProvider);
    final displayName = ref.watch(onboardingProvider).displayName;
    final docs = vaultState.documents; // already sorted lastAccessed DESC by vault_provider
    final recentDocs = docs.take(3).toList();

    const int queriesMax = 5;
    final int queriesUsed = queriesMax - energy;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _AppHeader(
              displayName: displayName,
              queriesUsed: queriesUsed,
              queriesMax: queriesMax,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _StatsRow(
              docCount: docs.length,
              queriesUsed: queriesUsed,
              queriesMax: queriesMax,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: _SectionLabel('RECENT DOCUMENTS'),
          ),
          SliverToBoxAdapter(
            child: recentDocs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'No documents yet',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  )
                : _RecentDocsList(
                    docs: recentDocs,
                    context: context,
                    ref: ref,
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: _SectionLabel('QUICK INGEST'),
          ),
          SliverToBoxAdapter(
            child: _QuickIngestGrid(context: context, ref: ref),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─── App Header ───────────────────────────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  final String displayName;
  final int queriesUsed;
  final int queriesMax;

  const _AppHeader({
    required this.displayName,
    required this.queriesUsed,
    required this.queriesMax,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MAGNUM OPUS',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeGreeting(displayName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.accentBlue,
                child: Text(
                  _initials(displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _timeGreeting(String name) {
    final hour = DateTime.now().hour;
    final String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }
    if (name.trim().isNotEmpty) {
      return '$greeting, $name.';
    }
    return greeting.trim().isNotEmpty ? '$greeting.' : greeting;
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'MO';
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'MO';
    return words
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int docCount;
  final int queriesUsed;
  final int queriesMax;

  const _StatsRow({
    required this.docCount,
    required this.queriesUsed,
    required this.queriesMax,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _StatCard(
            label: 'DOCUMENTS',
            value: '$docCount',
            valueColor: Colors.white,
            sub: 'in library',
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label: 'QUERIES TODAY',
            value: '$queriesUsed / $queriesMax',
            valueColor: AppTheme.accentBlue,
            sub: 'free tier',
          )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String sub;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.sub,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.accentBlue,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ─── Recent Docs List ─────────────────────────────────────────────────────────

class _RecentDocsList extends StatelessWidget {
  final List<DocumentModel> docs;
  final BuildContext context;
  final WidgetRef ref;

  const _RecentDocsList({
    required this.docs,
    required this.context,
    required this.ref,
  });

  @override
  Widget build(BuildContext ctx) {
    return Column(
      children: docs
          .map((doc) => Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _colorForType(doc.fileType).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForType(doc.fileType),
                      color: _colorForType(doc.fileType),
                      size: 18,
                    ),
                  ),
                  title: Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${doc.fileType.toUpperCase()} · ${_relativeDate(doc.lastAccessed)}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (doc.fileType == 'pdf') {
                      Navigator.push(
                        context,
                        _slideRoute(PdfViewerScreen(document: doc)),
                      );
                    } else {
                      Navigator.push(
                        context,
                        _slideRoute(DocumentViewScreen(document: doc)),
                      );
                    }
                  },
                ),
              ))
          .toList(),
    );
  }
}

// ─── Quick Ingest Grid ────────────────────────────────────────────────────────

class _QuickIngestGrid extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;

  const _QuickIngestGrid({required this.context, required this.ref});

  @override
  Widget build(BuildContext ctx) {
    final buttons = [
      _IngestButton(
        icon: Icons.description_outlined,
        iconColor: AppTheme.accentBlueLight,
        title: 'Documents',
        sub: 'PDF, EPUB, DOCX…',
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(vaultProvider.notifier).ingestDocument();
        },
      ),
      _IngestButton(
        icon: Icons.language_outlined,
        iconColor: AppTheme.badgeUrl,
        title: 'Web URL',
        sub: 'Scrape & index',
        onTap: () {
          HapticFeedback.lightImpact();
          _showUrlDialog(context, ref);
        },
      ),
      _IngestButton(
        icon: Icons.headphones_outlined,
        iconColor: AppTheme.badgeAudio,
        title: 'Audio',
        sub: 'MP3, M4A, WAV',
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(vaultProvider.notifier).ingestAudio();
        },
      ),
      _IngestButton(
        icon: Icons.camera_alt_outlined,
        iconColor: AppTheme.badgePptx,
        title: 'Sniper',
        sub: 'Capture & ask AI',
        onTap: () async {
          HapticFeedback.lightImpact();
          final picked = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (picked == null) return;
          final bytes = await picked.readAsBytes();
          final id = await ref
              .read(standaloneChatProvider.notifier)
              .createSession();
          if (id == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Session limit reached (5/5). Archive one to continue.'),
              ));
            }
            return;
          }
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StandaloneChatScreen(
                  sessionId: id,
                  initialImageBytes: bytes,
                ),
              ),
            );
          }
        },
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        children: buttons,
      ),
    );
  }
}

class _IngestButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _IngestButton({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── URL Dialog ───────────────────────────────────────────────────────────────

void _showUrlDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text(
        'Scrape Web URL',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'https://example.com/article',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: AppTheme.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.accentBlue),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          onPressed: () {
            final url = controller.text.trim();
            if (url.isNotEmpty) {
              Navigator.pop(ctx);
              ref.read(vaultProvider.notifier).ingestUrl(url);
            }
          },
          child: const Text('Scrape'),
        ),
      ],
    ),
  );
}

// ─── Shared Helpers ───────────────────────────────────────────────────────────

PageRouteBuilder<dynamic> _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

String _relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

Color _colorForType(String type) {
  switch (type) {
    case 'epub':  return AppTheme.badgeEpub;
    case 'docx':  return AppTheme.badgeDocx;
    case 'xlsx':  return AppTheme.badgeXlsx;
    case 'pptx':  return AppTheme.badgePptx;
    case 'csv':   return AppTheme.badgeCsv;
    case 'txt':   return AppTheme.badgeTxt;
    case 'audio': return AppTheme.badgeAudio;
    case 'url':   return AppTheme.badgeUrl;
    default:      return AppTheme.badgePdf;
  }
}

IconData _iconForType(String type) {
  switch (type) {
    case 'epub':  return Icons.menu_book_outlined;
    case 'docx':  return Icons.description_outlined;
    case 'xlsx':  return Icons.table_chart_outlined;
    case 'pptx':  return Icons.slideshow_outlined;
    case 'csv':   return Icons.grid_on_outlined;
    case 'txt':   return Icons.text_snippet_outlined;
    case 'audio': return Icons.headphones_outlined;
    case 'url':   return Icons.language_outlined;
    default:      return Icons.picture_as_pdf_outlined;
  }
}
