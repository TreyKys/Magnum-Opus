import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';
import 'package:magnum_opus/features/vault/presentation/pdf_viewer_screen.dart';
import 'package:magnum_opus/features/economy/providers/economy_provider.dart';
import 'package:magnum_opus/features/economy/presentation/magnum_banner_ad.dart';

import 'package:magnum_opus/features/tools/presentation/pdf_splicer_tool.dart';
import 'package:magnum_opus/features/tools/presentation/pdf_welder_tool.dart';
import 'package:magnum_opus/features/tools/presentation/pdf_compressor_tool.dart';
import 'package:magnum_opus/features/tools/presentation/text_ripper_tool.dart';
import 'package:magnum_opus/features/tools/presentation/pro_tool_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final documents = vaultState.documents;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MAGNUM OPUS',
          style: TextStyle(
            fontFamily: 'Bricolage Grotesque',
            letterSpacing: 2.0,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined, color: Colors.cyanAccent),
            onPressed: () {
              HapticFeedback.lightImpact();
              // Implement search functionality later
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.cyanAccent),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildToolsCarousel(context),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'THE VAULT',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFFB026FF),
                    ),
              ),
            ),
          ),
          documents.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Vault is empty.\nTap + to import files.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white54),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = documents[index];
                        final isIndexing = vaultState.indexingDocumentIds.contains(doc.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Card(
                            elevation: 0.0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white10, width: 1),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1A1A1A),
                                    Color(0xFF121212),
                                  ],
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: Icon(
                                  _getFileIcon(doc.title),
                                  color: _getFileColor(doc.title),
                                  size: 36,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        doc.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          doc.totalPages > 0
                                              ? '${doc.fileSizeMb.toStringAsFixed(2)} MB • ${doc.totalPages} Pages'
                                              : '${doc.fileSizeMb.toStringAsFixed(2)} MB',
                                          style: Theme.of(context).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isIndexing) ...[
                                        const SizedBox(width: 8),
                                        const _PulsingIndicator(),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                                  onPressed: () {
                                    ref.read(vaultProvider.notifier).deleteDocument(doc.id, doc.filePath);
                                  },
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PdfViewerScreen(
                                        id: doc.id,
                                        filePath: doc.filePath,
                                        title: doc.title,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: documents.length,
                    ),
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(vaultProvider.notifier).ingestPdf();
        },
        backgroundColor: const Color(0xFF00E5FF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      bottomNavigationBar: const MagnumBannerAd(),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'docx': return Icons.article_outlined;
      case 'xlsx': return Icons.table_chart_outlined;
      case 'pptx': return Icons.slideshow_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  Color _getFileColor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return const Color(0xFF8A1C1C); // Muted Crimson
      case 'docx': return const Color(0xFF1A3B70); // Deep Sapphire
      case 'xlsx': return const Color(0xFF145A32); // Cyber Emerald
      case 'pptx': return const Color(0xFFA04000); // Burnt Orange/Ruby
      default: return Colors.white54;
    }
  }

  Widget _buildToolsCarousel(BuildContext context) {
    final List<Map<String, dynamic>> tools = [
      // Free
      {'name': 'Splicer', 'icon': Icons.call_split, 'color': Colors.cyanAccent, 'isPro': false},
      {'name': 'Welder', 'icon': Icons.merge_type, 'color': Colors.cyanAccent, 'isPro': false},
      {'name': 'Compressor', 'icon': Icons.compress, 'color': Colors.cyanAccent, 'isPro': false},
      {'name': 'Text Ripper', 'icon': Icons.text_snippet_outlined, 'color': Colors.cyanAccent, 'isPro': false},
      // Pro
      {'name': 'AI Synthesizer', 'icon': Icons.auto_awesome, 'color': const Color(0xFFB026FF), 'isPro': true},
      {'name': 'Universal Converter', 'icon': Icons.transform, 'color': const Color(0xFFB026FF), 'isPro': true},
      {'name': 'Vault Engine', 'icon': Icons.lock_outline, 'color': const Color(0xFFB026FF), 'isPro': true},
      {'name': 'Image Stripper', 'icon': Icons.image_search, 'color': const Color(0xFFB026FF), 'isPro': true},
      {'name': 'Translator', 'icon': Icons.translate, 'color': const Color(0xFFB026FF), 'isPro': true},
      {'name': 'Watermark', 'icon': Icons.branding_watermark_outlined, 'color': const Color(0xFFB026FF), 'isPro': true},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MAGNUM TOOLS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFF00E5FF),
                    ),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final economyState = ref.watch(economyProvider);
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          economyState.isPro ? 'Infinite Energy' : '${economyState.energy} Energy',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.amber),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Widget destination;

                    switch (tool['name']) {
                      case 'Splicer': destination = const PdfSplicerTool(); break;
                      case 'Welder': destination = const PdfWelderTool(); break;
                      case 'Compressor': destination = const PdfCompressorTool(); break;
                      case 'Text Ripper': destination = const TextRipperTool(); break;

                      // Pro Tools
                      case 'AI Synthesizer':
                        destination = ProToolShell(
                          toolName: 'AI Synthesizer', icon: Icons.auto_awesome, actionLabel: 'Select Doc to Summarize',
                          description: '1-tap executive summary generation.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating API call to cloud function... (Local compiler limited)')));
                          },
                        ); break;
                      case 'Universal Converter':
                         destination = ProToolShell(
                          toolName: 'Universal Converter', icon: Icons.transform, actionLabel: 'Select DOCX/XLSX to Convert',
                          description: 'Convert DOCX, XLSX, and PPTX natively to PDF.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating cloud conversion...')));
                          },
                        ); break;
                      case 'Vault Engine':
                         destination = ProToolShell(
                          toolName: 'Vault Engine', icon: Icons.lock_outline, actionLabel: 'Encrypt File',
                          description: 'Military-grade AES encryption.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying 256-bit AES encryption...')));
                          },
                        ); break;
                      case 'Image Stripper':
                         destination = ProToolShell(
                          toolName: 'Image Stripper', icon: Icons.image_search, actionLabel: 'Extract Images',
                          description: 'Pull all diagrams and images into your gallery.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting embedded image streams...')));
                          },
                        ); break;
                      case 'Translator':
                         destination = ProToolShell(
                          toolName: 'Translator', icon: Icons.translate, actionLabel: 'Translate Doc',
                          description: 'AI-powered document translation retaining format.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Initiating translation pipeline...')));
                          },
                        ); break;
                      case 'Watermark':
                         destination = ProToolShell(
                          toolName: 'Watermark', icon: Icons.branding_watermark_outlined, actionLabel: 'Add Watermark',
                          description: 'Stamp a custom transparent logo across all pages.',
                          onSimulatedAction: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying transparent overlay...')));
                          },
                        ); break;
                      default: destination = Scaffold(appBar: AppBar(title: const Text('Error')));
                    }

                    Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Icon(
                              tool['icon'] as IconData,
                              color: tool['color'] as Color,
                              size: 40,
                            ),
                            if (tool['isPro'] as bool)
                              const Padding(
                                padding: EdgeInsets.only(left: 24.0, bottom: 24.0),
                                child: Icon(Icons.star, color: Colors.amber, size: 14),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tool['name'] as String,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

}

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
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
          builder: (context, child) {
            return Opacity(
              opacity: 0.3 + (_controller.value * 0.7),
              child: child,
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF00E5FF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Indexing...',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
