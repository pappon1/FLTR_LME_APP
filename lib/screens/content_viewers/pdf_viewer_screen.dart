import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final bool isNetwork;
  final String? title;

  const PDFViewerScreen({
    super.key,
    required this.filePath,
    this.isNetwork = false,
    this.title,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  bool _isHorizontal = false;
  PDFViewController? _pdfViewController;
  
  // Storage key for last read page
  String get _storageKey => 'pdf_last_page_${widget.filePath.hashCode}';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on while reading
    _prepareFile();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _prepareFile() async {
    try {
      if (widget.isNetwork) {
        final response = await http.get(Uri.parse(widget.filePath));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/temp_pdf_${widget.filePath.hashCode}.pdf');
          await file.writeAsBytes(response.bodyBytes);
          _localPath = file.path;
        } else {
          throw Exception("Failed to download PDF (Status: ${response.statusCode})");
        }
      } else {
        _localPath = widget.filePath;
      }

      // Load last read page
      final prefs = await SharedPreferences.getInstance();
      _currentPage = prefs.getInt(_storageKey) ?? 0;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPageChanged(int? page, int? total) {
    if (page != null) {
      setState(() => _currentPage = page);
      // Save progress
      unawaited(SharedPreferences.getInstance().then((prefs) {
        prefs.setInt(_storageKey, page);
      }));
    }
  }

  void _jumpToPage(int page) {
    _pdfViewController?.setPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.title ?? _localPath?.split('/').last ?? 'PDF Viewer',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_isHorizontal ? Icons.swap_vert : Icons.swap_horiz),
            tooltip: _isHorizontal ? "Vertical Scroll" : "Horizontal Swipe",
            onPressed: () => setState(() => _isHorizontal = !_isHorizontal),
          ),
          if (_isReady && _totalPages > 0)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _showJumpToPageDialog,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading) _buildShimmerLoader(),
          if (!_isLoading && _localPath != null)
            PDFView(
              filePath: _localPath!,
              enableSwipe: true,
              swipeHorizontal: _isHorizontal,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              defaultPage: _currentPage,
              fitPolicy: FitPolicy.BOTH,
              onRender: (pages) {
                setState(() {
                  _totalPages = pages!;
                  _isReady = true;
                });
              },
              onViewCreated: (controller) => _pdfViewController = controller,
              onPageChanged: _onPageChanged,
              onError: (error) => _handleError(error.toString()),
            ),
          
          // Floating Page Indicator
          if (_isReady && _totalPages > 0)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black87 : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_currentPage + 1}",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        " / $_totalPages",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 1.0, end: 0.0),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(3, (index) => 
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog() {
    double tempPage = _currentPage.toDouble();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Jump to Page"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Page: ${(tempPage + 1).toInt()} of $_totalPages"),
              const SizedBox(height: 16),
              Slider(
                value: tempPage,
                min: 0,
                max: (_totalPages - 1).toDouble(),
                activeColor: const Color(0xFF22C55E),
                onChanged: (val) {
                  setDialogState(() => tempPage = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _jumpToPage(tempPage.toInt());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
              ),
              child: const Text("Go"),
            ),
          ],
        ),
      ),
    );
  }
}
