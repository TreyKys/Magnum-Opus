import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/features/vault/providers/vault_provider.dart';
import 'package:myapp/features/vault/presentation/pdf_loading_screen.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(vaultProvider);

    // Sort documents for recents (already sorted by last_accessed DESC in db, but let's be sure)
    final recentDocuments = List.of(documents)..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MAGNUM VAULT'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'VAULT'),
              Tab(text: 'RECENTS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentList(context, ref, documents),
            _buildDocumentList(context, ref, recentDocuments),
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

  Widget _buildDocumentList(BuildContext context, WidgetRef ref, List documents) {
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Card(
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfLoadingScreen(
                      filePath: doc.filePath,
                      title: doc.title,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
