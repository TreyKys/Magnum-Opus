import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/theme/theme_provider.dart';
import 'package:myapp/features/vault/providers/vault_provider.dart';
import 'package:myapp/features/vault/presentation/pdf_loading_screen.dart';
import 'package:myapp/features/vault/models/document_model.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(vaultProvider);
    final themeMode = ref.watch(themeProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MAGNUM VAULT'),
          actions: [
            IconButton(
              icon: Icon(themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                ref.read(themeProvider.notifier).toggle();
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vault'),
              Tab(text: 'Recents'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentList(context, ref, documents),
            _buildDocumentList(context, ref, _getRecentDocuments(documents)),
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

  List<DocumentModel> _getRecentDocuments(List<DocumentModel> docs) {
    final sorted = List<DocumentModel>.from(docs);
    sorted.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    return sorted;
  }

  Widget _buildDocumentList(BuildContext context, WidgetRef ref, List<DocumentModel> documents) {
    if (documents.isEmpty) {
      return Center(
        child: Text(
          'Vault is empty.\nTap + to import a PDF.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfLoadingScreen(
                      document: doc,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${doc.fileSizeMb.toStringAsFixed(2)} MB • ${doc.totalPages} Pages',
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
                      onPressed: () {
                        ref.read(vaultProvider.notifier).deleteDocument(doc.id, doc.filePath);
                      },
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
}
