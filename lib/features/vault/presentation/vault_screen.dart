import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/features/vault/providers/vault_provider.dart';
import 'package:myapp/features/vault/presentation/pdf_viewer_screen.dart';

class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAGNUM VAULT'),
      ),
      body: documents.isEmpty
          ? const Center(
              child: Text(
                'Vault is empty.\nTap + to import a PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Text(
                              '\${doc.fileSizeMb.toStringAsFixed(2)} MB',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '\${doc.totalPages} Pages',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {
                          ref.read(vaultProvider.notifier).deleteDocument(doc.id, doc.filePath);
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerScreen(
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(vaultProvider.notifier).ingestPdf();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
