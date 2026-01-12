import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final bool isNetwork;

  const PDFViewerScreen({super.key, required this.filePath, this.isNetwork = false});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  String? _localPath;
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    if (widget.isNetwork) {
      try {
        final url = widget.filePath;
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/temp_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await file.writeAsBytes(response.bodyBytes);
          if (mounted) {
            setState(() {
              _localPath = file.path;
              _isLoading = false;
            });
          }
        } else {
             _handleError("Failed to download PDF");
        }
      } catch (e) {
        _handleError(e.toString());
      }
    } else {
      // Local file
      setState(() {
        _localPath = widget.filePath;
        _isLoading = false;
      });
    }
  }

  void _handleError(String error) {
    if(mounted) {
        setState(() {
            _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_localPath?.split('/').last ?? 'PDF Viewer'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
            if (_totalPages > 0)
                Center(child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text('${_currentPage + 1} / $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                ))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _localPath != null 
              ? PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  pageSnap: true,
                  fitPolicy: FitPolicy.BOTH,
                  onRender: (pages) {
                    setState(() {
                      _totalPages = pages!;
                    });
                  },
                  onViewCreated: (PDFViewController pdfViewController) {
                    _pdfViewController = pdfViewController;
                  },
                  onPageChanged: (int? page, int? total) {
                    setState(() {
                      _currentPage = page!;
                    });
                  },
                  onError: (error) {
                    print(error.toString());
                  },
                  onPageError: (page, error) {
                    print('$page: ${error.toString()}');
                  },
                )
              : const Center(child: Text("Could not load PDF")),
    );
  }
}
