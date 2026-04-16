import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/presentation/pdf_viewer_screen.dart';
import 'package:magnum_opus/features/vault/presentation/document_view_screen.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final documents = vaultState.documents;
    final recentDocuments = List.of(documents)
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Magnum Opus'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'VAULT'),
              Tab(text: 'RECENTS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentList(
                context, ref, documents, vaultState.indexingDocumentIds),
            _buildDocumentList(
                context, ref, recentDocuments, vaultState.indexingDocumentIds),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showIngestSheet(context, ref),
          child: const Icon(Icons.add),
        ),
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
                  subtitle: 'MP3, M4A, WAV — transcribed by AI',
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
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Vault is empty',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add PDF, EPUB, DOCX,\nXLSX, PPTX, audio, or a web URL',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final isIndexing = indexingIds.contains(doc.id);
        final typeColor = _colorForType(doc.fileType);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                _openDocument(context, doc);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(_iconForType(doc.fileType),
                        color: typeColor, size: 22),
                  ),
                  title: Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        // File type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            doc.fileType.toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${doc.fileSizeMb.toStringAsFixed(1)} MB',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                        if (doc.totalPages > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${doc.totalPages} ${_pageLabel(doc.fileType)}',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                        if (isIndexing) ...[
                          const SizedBox(width: 10),
                          const _PulsingIndicator(),
                        ],
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Color(0xFFFF5252)),
                    onPressed: () => ref
                        .read(vaultProvider.notifier)
                        .deleteDocument(doc.id, doc.filePath),
                  ),
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
        _slideRoute(
          PdfViewerScreen(
            id: doc.id,
            filePath: doc.filePath,
            title: doc.title,
          ),
        ),
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

  static Color _colorForType(String type) {
    switch (type) {
      case 'epub':
        return AppTheme.badgeEpub;
      case 'docx':
        return AppTheme.badgeDocx;
      case 'xlsx':
        return AppTheme.badgeXlsx;
      case 'pptx':
        return AppTheme.badgePptx;
      case 'csv':
        return AppTheme.badgeCsv;
      case 'txt':
        return AppTheme.badgeTxt;
      case 'audio':
        return AppTheme.badgeAudio;
      case 'url':
        return AppTheme.badgeUrl;
      default:
        return AppTheme.badgePdf;
    }
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'epub':
        return Icons.menu_book_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'csv':
        return Icons.grid_on_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      case 'audio':
        return Icons.headphones_outlined;
      case 'url':
        return Icons.language_outlined;
      default:
        return Icons.picture_as_pdf_outlined;
    }
  }

  static String _pageLabel(String type) {
    switch (type) {
      case 'audio':
      case 'url':
      case 'epub':
      case 'docx':
      case 'xlsx':
      case 'pptx':
      case 'csv':
      case 'txt':
        return 'chunks';
      default:
        return 'pages';
    }
  }
}

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
