import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/features/vault/providers/vault_provider.dart';
import 'package:myapp/features/vault/presentation/pdf_loading_screen.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultState = ref.watch(vaultProvider);
    final documents = vaultState.documents;

    // Sort documents for recents (already sorted by last_accessed DESC in db, but let's be sure)
    final recentDocuments = List.of(documents)..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MAGNUM VAULT'),
          bottom: TabBar(
            onTap: (index) {
              HapticFeedback.lightImpact();
            },
            indicator: BoxDecoration(
              border: const Border(
                bottom: BorderSide(
                  color: Color(0xFF00E5FF),
                  width: 2.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            tabs: const [
              Tab(text: 'VAULT'),
              Tab(text: 'RECENTS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentList(context, ref, documents, vaultState.indexingDocumentIds),
            _buildDocumentList(context, ref, recentDocuments, vaultState.indexingDocumentIds),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ref.read(vaultProvider.notifier).ingestPdf();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildDocumentList(BuildContext context, WidgetRef ref, List documents, Set<String> indexingIds) {
    if (documents.isEmpty) {
      return const Center(
        child: Text(
          'Vault is empty.\nTap + to import a PDF.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final isIndexing = indexingIds.contains(doc.id);

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
                leading: const Icon(
                Icons.description_outlined,
                color: Colors.cyanAccent,
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
                        '${doc.fileSizeMb.toStringAsFixed(2)} MB • ${doc.totalPages} Pages',
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
                    builder: (context) => PdfLoadingScreen(
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
