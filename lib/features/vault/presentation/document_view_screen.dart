import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:magnum_opus/core/database/database_helper.dart';
import 'package:magnum_opus/core/theme/app_theme.dart';
import 'package:magnum_opus/features/settings/providers/settings_provider.dart';
import 'package:magnum_opus/features/vault/models/document_model.dart';
import 'package:magnum_opus/features/vault/presentation/document_chat_screen.dart';
import 'package:magnum_opus/features/vault/providers/vault_provider.dart';

// ─── HTML templates (raw strings avoid escaping issues) ───────────────────────

const _kDocxTemplate = r'''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
body{font-family:Georgia,serif;padding:20px 22px;line-height:1.75;color:#E2E2E2;background:#0A0A0A;margin:0}
h1,h2,h3,h4{font-family:-apple-system,sans-serif;color:#FFF;margin:1.2em 0 .5em}
h1{font-size:1.4em}h2{font-size:1.2em}h3{font-size:1.05em}
p{margin:0 0 .9em}strong,b{color:#FFF}
table{width:100%;border-collapse:collapse;margin:1em 0}
td,th{border:1px solid #2A2A2A;padding:7px 10px;text-align:left;font-size:.9em}
th{background:#1A1A1A;color:#FFF;font-weight:600}
ul,ol{padding-left:1.5em;margin:.4em 0 .9em}li{margin:.25em 0}
a{color:#4FC3F7}img{max-width:100%;height:auto}
blockquote{border-left:3px solid #4FC3F7;margin:1em 0;padding-left:1em;color:#AAA}
</style>
<script>__MAMMOTH__</script>
</head><body>
<div id="c"><p style="color:#555">Rendering document...</p></div>
<script>
(function(){
var b="__B64__",bin=atob(b),arr=new Uint8Array(bin.length);
for(var i=0;i<bin.length;i++)arr[i]=bin.charCodeAt(i);
mammoth.convertToHtml({arrayBuffer:arr.buffer})
  .then(function(r){document.getElementById("c").innerHTML=r.value||'<p style="color:#666">No text content.</p>';})
  .catch(function(e){document.getElementById("c").innerHTML='<p style="color:#e57373">Error: '+e+'</p>';});
})();
</script></body></html>''';

const _kPptxTemplate = r'''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box}
body{margin:0;padding:12px;background:#0A0A0A;font-family:-apple-system,sans-serif}
.slide{background:#131325;border-radius:12px;padding:22px 24px;margin-bottom:14px;border:1px solid #2A2A4A;min-height:160px}
.sn{color:#4FC3F7;font-size:9px;font-weight:700;letter-spacing:1.2px;margin-bottom:10px}
.st{color:#FFF;font-size:18px;font-weight:700;margin-bottom:12px;line-height:1.3}
.sb p{color:#C8CDD5;font-size:13.5px;line-height:1.65;margin:0 0 5px}
.se{color:#444;font-style:italic;font-size:12px}
#status{color:#4FC3F7;font-size:13px;padding:30px;text-align:center}
</style>
<script>__JSZIP__</script>
</head><body>
<div id="status">Parsing presentation...</div>
<div id="slides"></div>
<script>
(function(){
function esc(s){return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}
function parse(xml,idx,tot){
  var doc=(new DOMParser()).parseFromString(xml,"text/xml");
  var sps=doc.getElementsByTagName("p:sp"),title="",body=[];
  for(var i=0;i<sps.length;i++){
    var ph=sps[i].getElementsByTagName("p:ph")[0];
    var type=ph?ph.getAttribute("type"):"";
    var txb=sps[i].getElementsByTagName("p:txBody")[0];
    if(!txb)continue;
    var paras=txb.getElementsByTagName("a:p"),lines=[];
    for(var j=0;j<paras.length;j++){
      var runs=paras[j].getElementsByTagName("a:r"),line="";
      for(var k=0;k<runs.length;k++){var t=runs[k].getElementsByTagName("a:t")[0];if(t)line+=t.textContent;}
      if(line.trim())lines.push(line.trim());
    }
    if(type==="title"||type==="ctrTitle")title=lines.join(" ");
    else body=body.concat(lines);
  }
  return{idx:idx,tot:tot,title:title,body:body};
}
var raw=atob("__B64__"),bytes=new Uint8Array(raw.length);
for(var i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);
JSZip.loadAsync(bytes).then(function(zip){
  var keys=Object.keys(zip.files).filter(function(f){
    return f.indexOf("ppt/slides/slide")==0&&f.slice(-4)===".xml"&&f.indexOf("/_rels/")<0;
  }).sort(function(a,b){
    return parseInt(a.replace(/[^0-9]/g,""))-parseInt(b.replace(/[^0-9]/g,""));
  });
  if(!keys.length){document.getElementById("status").textContent="No slides found.";return;}
  document.getElementById("status").remove();
  var con=document.getElementById("slides");
  return Promise.all(keys.map(function(f,i){
    return zip.files[f].async("string").then(function(x){return parse(x,i+1,keys.length);});
  })).then(function(slides){
    slides.forEach(function(s){
      var bh=s.body.length?'<div class="sb">'+s.body.map(function(l){return'<p>'+esc(l)+'</p>';}).join("")+'</div>':(!s.title?'<div class="se">(No text on this slide)</div>':'');
      con.insertAdjacentHTML("beforeend",'<div class="slide"><div class="sn">SLIDE '+s.idx+' / '+s.tot+'</div>'+(s.title?'<div class="st">'+esc(s.title)+'</div>':'')+bh+'</div>');
    });
  });
}).catch(function(e){document.getElementById("slides").innerHTML='<p style="color:#e57373;padding:20px">Error: '+e+'</p>';});
})();
</script></body></html>''';

// ─── Screen ───────────────────────────────────────────────────────────────────

class DocumentViewScreen extends ConsumerStatefulWidget {
  final DocumentModel document;
  const DocumentViewScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends ConsumerState<DocumentViewScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String _loadingMessage = 'Opening document...';

  WebViewController? _webViewController;
  String _textContent = '';
  List<String> _tableHeaders = [];
  List<List<String>> _tableRows = [];

  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _selectedTip = '';

  static const _tips = [
    'Use active recall and spaced repetition to remember document content.',
    'Read the conclusion first to understand the author\'s destination.',
    'Skim headings before reading to build a mental map of the text.',
    'Summarize each section in your own words to improve comprehension.',
    'Take breaks every 25 minutes to maintain peak cognitive focus.',
    'Magnum Opus uses Isolate spawning to handle massive documents efficiently.',
    'All data stays on your device. Zero external servers. Complete privacy.',
    'The Complexity Dial scales from ELI5 to expert-level — try it!',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTip = _tips[Random().nextInt(_tips.length)];
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _hoverAnimation = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    _loadContent();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final ft = widget.document.fileType;
    switch (ft) {
      case 'docx':
        _loadingMessage = 'Rendering Word document...';
        await _initDocxViewer();
      case 'pptx':
        _loadingMessage = 'Rendering presentation...';
        await _initPptxViewer();
      case 'epub':
        _loadingMessage = 'Opening e-book...';
        await _initEpubViewer();
      case 'xlsx':
        _loadingMessage = 'Reading spreadsheet...';
        await _loadXlsx();
      case 'csv':
        _loadingMessage = 'Parsing CSV...';
        await _loadCsv();
      case 'txt':
        _loadingMessage = 'Loading text...';
        await _loadTxt();
      default:
        _loadingMessage = 'Loading...';
        await _loadChunks();
    }
    DatabaseHelper.instance.updateDocumentLastAccessed(widget.document.id);
    if (mounted) setState(() => _isLoading = false);
  }

  // ── DOCX ─────────────────────────────────────────────────────────────────────

  Future<void> _initDocxViewer() async {
    final js = await rootBundle.loadString('assets/js/mammoth.min.js');
    final bytes = await File(widget.document.filePath).readAsBytes();
    final b64 = base64Encode(bytes);
    final html = _kDocxTemplate
        .replaceFirst('__MAMMOTH__', js)
        .replaceFirst('__B64__', b64);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..loadHtmlString(html);
  }

  // ── PPTX ─────────────────────────────────────────────────────────────────────

  Future<void> _initPptxViewer() async {
    final js = await rootBundle.loadString('assets/js/jszip.min.js');
    final bytes = await File(widget.document.filePath).readAsBytes();
    final b64 = base64Encode(bytes);
    final html = _kPptxTemplate
        .replaceFirst('__JSZIP__', js)
        .replaceFirst('__B64__', b64);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..loadHtmlString(html);
  }

  // ── EPUB ─────────────────────────────────────────────────────────────────────

  Future<void> _initEpubViewer() async {
    try {
      final bytes = await File(widget.document.filePath).readAsBytes();
      final html = _buildEpubHtml(bytes);
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0A0A0A))
        ..loadHtmlString(html);
    } catch (_) {
      await _loadChunks();
    }
  }

  String _buildEpubHtml(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) throw Exception('Not a valid EPUB');
    final containerStr = utf8.decode(containerFile.content as List<int>, allowMalformed: true);
    final opfMatch = RegExp(r'full-path="([^"]+)"').firstMatch(containerStr);
    if (opfMatch == null) throw Exception('No OPF found');
    final opfPath = opfMatch.group(1)!;
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';

    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) throw Exception('OPF missing');
    final opfStr = utf8.decode(opfFile.content as List<int>, allowMalformed: true);

    final manifest = <String, String>{};
    for (final m in RegExp(r'<item[^>]+id="([^"]+)"[^>]+href="([^"]+)"', caseSensitive: false).allMatches(opfStr)) {
      manifest[m.group(1)!] = m.group(2)!;
    }

    final chapters = <String>[];
    for (final m in RegExp(r'<itemref[^>]+idref="([^"]+)"', caseSensitive: false).allMatches(opfStr)) {
      final href = manifest[m.group(1)!];
      if (href == null) continue;
      final file = archive.findFile(opfDir + href);
      if (file == null) continue;
      final src = utf8.decode(file.content as List<int>, allowMalformed: true);
      final body = RegExp(r'<body[^>]*>([\s\S]*?)</body>', caseSensitive: false).firstMatch(src)?.group(1) ?? src;
      chapters.add(body);
    }

    final combined = chapters.isEmpty
        ? '<p>Could not extract content from this EPUB.</p>'
        : chapters.join('\n<hr style="border-color:#1A1A1A;margin:2em 0">\n');

    return '''<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
html,body{margin:0;padding:0;background:#0A0A0A;color:#E2E2E2}
body{font-family:Georgia,serif;padding:20px 22px;line-height:1.8;font-size:16px}
h1,h2,h3,h4,h5,h6{font-family:-apple-system,sans-serif;color:#FFF;margin:1.3em 0 .5em}
p{margin:0 0 1em}a{color:#4FC3F7;text-decoration:none}strong,b{color:#FFF}
img{max-width:100%;height:auto;border-radius:4px;margin:1em 0}
table{width:100%;border-collapse:collapse;margin:1em 0}
td,th{border:1px solid #2A2A2A;padding:6px 10px;font-size:.9em}
th{background:#1A1A1A;color:#FFF;font-weight:600}
ul,ol{padding-left:1.5em;margin:.5em 0 1em}li{margin:.3em 0}
blockquote{border-left:3px solid #4FC3F7;margin:1em 0;padding-left:1em;color:#AAA}
</style>
</head><body>$combined</body></html>''';
  }

  // ── XLSX ─────────────────────────────────────────────────────────────────────

  Future<void> _loadXlsx() async {
    try {
      final bytes = await File(widget.document.filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes.toList());
      final sheetName = excel.tables.keys.firstOrNull;
      if (sheetName == null) return;
      final sheet = excel.tables[sheetName]!;
      final headers = <String>[];
      final rows = <List<String>>[];
      for (int i = 0; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        final cells = List<String>.generate(
          sheet.maxCols,
          (j) => j < row.length ? (row[j]?.value?.toString() ?? '') : '',
        );
        if (cells.every((c) => c.isEmpty)) continue;
        if (headers.isEmpty) {
          headers.addAll(cells);
        } else {
          rows.add(cells);
        }
      }
      _tableHeaders = headers.isEmpty ? ['Column 1'] : headers;
      _tableRows = rows;
    } catch (_) {}
  }

  // ── CSV ──────────────────────────────────────────────────────────────────────

  Future<void> _loadCsv() async {
    try {
      final text = await File(widget.document.filePath).readAsString();
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final headers = <String>[];
      final rows = <List<String>>[];
      for (int i = 0; i < lines.length; i++) {
        final cells = _parseCsvLine(lines[i]);
        if (i == 0) {
          headers.addAll(cells);
        } else {
          rows.add(_padRow(cells, headers.length));
        }
      }
      _tableHeaders = headers.isEmpty ? ['Column 1'] : headers;
      _tableRows = rows;
    } catch (_) {}
  }

  // ── TXT ──────────────────────────────────────────────────────────────────────

  Future<void> _loadTxt() async {
    try {
      _textContent = await File(widget.document.filePath).readAsString();
    } catch (_) {}
  }

  // ── Audio / URL (SQLite chunks) ───────────────────────────────────────────────

  Future<void> _loadChunks() async {
    final chunks = await DatabaseHelper.instance.getAllDocumentChunks(widget.document.id);
    _textContent = chunks.map((c) => c['extracted_text'] as String).join('\n\n');
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final vaultState = ref.watch(vaultProvider);
    final isIndexing = vaultState.indexingDocumentIds.contains(widget.document.id);

    ref.listen<VaultState>(vaultProvider, (prev, next) {
      final was = prev?.indexingDocumentIds.contains(widget.document.id) ?? false;
      final now = next.indexingDocumentIds.contains(widget.document.id);
      if (was && !now && _textContent.isEmpty && _webViewController == null) {
        _loadContent();
      }
    });

    final typeColor = _colorForType(widget.document.fileType);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(typeColor),
      floatingActionButton: (!_isLoading && !isIndexing)
          ? FloatingActionButton.extended(
              heroTag: 'chat_fab_doc',
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DocumentChatScreen(document: widget.document),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          if (!_isLoading && !isIndexing) _buildContent(),
          if (_isLoading || isIndexing)
            Container(
              color: AppTheme.background,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _hoverAnimation,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _hoverAnimation.value),
                        child: child,
                      ),
                      child: Icon(
                        _iconForType(widget.document.fileType),
                        size: 80,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      isIndexing
                          ? (widget.document.fileType == 'audio'
                              ? 'Transcribing audio...'
                              : 'Processing document...')
                          : _loadingMessage,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 40),
                    if (settings.showReadingTips)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _selectedTip,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white54,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color typeColor) {
    return AppBar(
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.document.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          Text(
            '${widget.document.totalPages} sections · ${widget.document.fileSizeMb.toStringAsFixed(1)} MB',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.document.fileType.toUpperCase(),
              style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (widget.document.fileType) {
      case 'docx':
      case 'pptx':
      case 'epub':
        return _webViewController != null
            ? WebViewWidget(controller: _webViewController!)
            : _buildEmptyState();
      case 'xlsx':
      case 'csv':
        return _buildTableViewer();
      default:
        return _buildTextReader();
    }
  }

  Widget _buildTextReader() {
    final type = widget.document.fileType;
    if (_textContent.isEmpty) return _buildEmptyState();
    return CustomScrollView(
      slivers: [
        if (type == 'audio' || type == 'url')
          SliverToBoxAdapter(child: _buildTypeBanner(type)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverToBoxAdapter(
            child: type == 'url'
                ? MarkdownWidget(
                    data: _textContent,
                    shrinkWrap: true,
                    config: MarkdownConfig.darkConfig,
                  )
                : SelectableText(
                    _textContent,
                    style: const TextStyle(
                      fontSize: 16.5,
                      height: 1.72,
                      color: Color(0xFFE2E2E2),
                      letterSpacing: 0.15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBanner(String type) {
    final isAudio = type == 'audio';
    final color = _colorForType(type);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(isAudio ? Icons.mic_none : Icons.language_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            isAudio ? 'Auto-transcribed from audio' : 'AI-generated web summary',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTableViewer() {
    if (_tableHeaders.isEmpty) return _buildEmptyState();
    final cappedRows = _tableRows.take(1000).toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surfaceVariant,
          child: Row(children: [
            Icon(_iconForType(widget.document.fileType),
                color: _colorForType(widget.document.fileType), size: 15),
            const SizedBox(width: 8),
            Text(
              '${cappedRows.length} rows · ${_tableHeaders.length} columns'
              '${_tableRows.length > 1000 ? ' (first 1 000)' : ''}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ]),
        ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.surface),
                  dividerThickness: 0.5,
                  horizontalMargin: 14,
                  columnSpacing: 20,
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 56,
                  columns: _tableHeaders
                      .map((h) => DataColumn(
                            label: SizedBox(
                              width: 130,
                              child: Text(h,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ))
                      .toList(),
                  rows: cappedRows.asMap().entries.map((e) {
                    return DataRow(
                      color: WidgetStateProperty.all(
                        e.key.isEven ? AppTheme.background : AppTheme.surface.withOpacity(0.6),
                      ),
                      cells: e.value
                          .map((cell) => DataCell(SizedBox(
                                width: 130,
                                child: Text(cell,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 13)),
                              )))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForType(widget.document.fileType),
                color: AppTheme.textMuted, size: 52),
            const SizedBox(height: 20),
            const Text('No content extracted yet',
                style: TextStyle(
                    color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('The document may still be processing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQ = !inQ;
      } else if (ch == ',' && !inQ) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  List<String> _padRow(List<String> row, int len) {
    if (row.length >= len) return row.take(len).toList();
    return [...row, ...List.filled(len - row.length, '')];
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
}
