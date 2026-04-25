import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/presentation/document_chat_screen.dart';
import 'package:magnum_opus/features/vault/presentation/document_view_screen.dart';
import 'package:magnum_opus/features/vault/presentation/pdf_viewer_screen.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final documents = vaultState.documents;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          documents.isEmpty ? 'Library' : 'Library  (${documents.length})',
        ),
        automaticallyImplyLeading: false,
      ),
      body: _buildDocumentList(
          context, ref, documents, vaultState.indexingDocumentIds),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIngestSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showIngestSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ADD TO VAULT',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
                _IngestOption(
                  icon: Icons.description_outlined,
                  iconColor: AppTheme.accentBlueLight,
                  title: 'Documents',
                  subtitle: 'PDF, EPUB, DOCX, TXT, CSV',
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(vaultProvider.notifier).ingestDocument();
                  },
                ),
                _IngestOption(
                  icon: Icons.table_chart_outlined,
                  iconColor: AppTheme.badgeXlsx,
                  title: 'Data & Slides',
                  subtitle: 'XLSX, PPTX',
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(vaultProvider.notifier).ingestData();
                  },
                ),
                _IngestOption(
                  icon: Icons.headphones_outlined,
                  iconColor: AppTheme.badgeAudio,
                  title: 'Audio',
                  subtitle: 'MP3, M4A, WAV — auto-transcribed',
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(vaultProvider.notifier).ingestAudio();
                  },
                ),
                _IngestOption(
                  icon: Icons.language_outlined,
                  iconColor: AppTheme.badgeUrl,
                  title: 'Web URL',
                  subtitle: 'Paste a link to scrape and index',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUrlDialog(context, ref);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Scrape Web URL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  Widget _buildDocumentList(
    BuildContext context,
    WidgetRef ref,
    List<DocumentModel> documents,
    Set<String> indexingIds,
  ) {
    if (documents.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final isIndexing = indexingIds.contains(doc.id);
        final typeColor = _colorForType(doc.fileType);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Colored accent strip
                    Container(width: 4, color: typeColor),
                    // Card content
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _openDocument(context, doc);
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Format icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: typeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    _iconForType(doc.fileType),
                                    color: typeColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title + meta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        doc.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          _TypeBadge(
                                            label: doc.fileType.toUpperCase(),
                                            color: typeColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${doc.fileSizeMb.toStringAsFixed(1)} MB',
                                            style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 12),
                                          ),
                                          if (doc.totalPages > 0) ...[
                                            const SizedBox(width: 5),
                                            Text(
                                              '· ${doc.totalPages} ${_pageLabel(doc.fileType)}',
                                              style: const TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 12),
                                            ),
                                          ],
                                          if (isIndexing) ...[
                                            const SizedBox(width: 10),
                                            const _PulsingIndicator(),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatRelativeDate(doc.lastAccessed),
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Chat
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      color: AppTheme.textMuted, size: 18),
                                  onPressed: () => Navigator.push(
                                    context,
                                    _slideRoute(DocumentChatScreen(document: doc)),
                                  ),
                                ),
                                // Delete
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFFF5252)),
                                  onPressed: () => ref
                                      .read(vaultProvider.notifier)
                                      .deleteDocument(doc.id, doc.filePath),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openDocument(BuildContext context, DocumentModel doc) {
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
  }

  static PageRouteBuilder _slideRoute(Widget page) {
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

  static String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  static Color _colorForType(String type) {
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

  static IconData _iconForType(String type) {
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

  static String _pageLabel(String type) {
    if (type == 'pdf') return 'pages';
    return 'chunks';
  }
}

// ─── Type badge pill ──────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Empty state with animated badge grid ─────────────────────────────────────

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  static const _badges = [
    ('PDF',  AppTheme.badgePdf),
    ('EPUB', AppTheme.badgeEpub),
    ('DOCX', AppTheme.badgeDocx),
    ('XLSX', AppTheme.badgeXlsx),
    ('PPTX', AppTheme.badgePptx),
    ('CSV',  AppTheme.badgeCsv),
    ('MP3',  AppTheme.badgeAudio),
    ('URL',  AppTheme.badgeUrl),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final badge in _badges)
                      _EmptyBadgePill(label: badge.$1, color: badge.$2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your vault is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap + to add your first document',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBadgePill extends StatelessWidget {
  final String label;
  final Color color;

  const _EmptyBadgePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Ingest option row ────────────────────────────────────────────────────────

class _IngestOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _IngestOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      onTap: onTap,
    );
  }
}

// ─── Pulsing indexing indicator ───────────────────────────────────────────────

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Opacity(
            opacity: 0.3 + (_controller.value * 0.7),
            child: child,
          ),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.accentBlueLight,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'Indexing...',
          style: TextStyle(
            color: AppTheme.accentBlueLight,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
