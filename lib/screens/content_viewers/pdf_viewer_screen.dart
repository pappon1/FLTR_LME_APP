import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

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
  // State Management (Optimized for high-speed scrolling)
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(0);
  final ValueNotifier<int> _totalPagesNotifier = ValueNotifier(0);
  final ValueNotifier<PdfTextSearchResult?> _searchResultNotifier = ValueNotifier(null);
  
  String? _localPath;
  bool _isLoading = true;
  bool _showControls = true;
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  Timer? _hideControlsTimer;
  Offset? _pointerDownPos;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  
  String get _storageKey => 'pdf_last_page_${widget.filePath.hashCode}';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _prepareFile();
    _startHideTimer();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _hideControlsTimer?.cancel();
    _searchResultNotifier.value?.removeListener(_onSearchResultChanged);
    _searchResultNotifier.dispose();
    _currentPageNotifier.dispose();
    _totalPagesNotifier.dispose();
    _pdfViewerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
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
          throw Exception("Failed to download PDF");
        }
      } else {
        _localPath = widget.filePath;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastPage = prefs.getInt(_storageKey) ?? 0;
      _currentPageNotifier.value = lastPage;

      if (mounted) setState(() => _isLoading = false);
      
      // Jump to last page after delay to ensure viewer is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (lastPage > 0) {
          _pdfViewerController.jumpToPage(lastPage + 1);
        }
      });
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  void _onSearchResultChanged() {
    // No more setState here! The ValueListenableBuilder will handle UI updates
    // for the match counter and navigation buttons without rebuilding the TextField.
    _searchResultNotifier.notifyListeners(); 
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearching) {
          _closeSearch();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Hide keyboard when tapping anywhere outside text fields
          final currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF8FAFC),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? const Color(0xFF111111) : Colors.white,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: isDark ? const Color(0xFF1F1F1F) : Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: Column(
            children: [
              // Premium Header - Now part of the Column (Linear Layout)
              _buildHeader(isDark),
              
              // PDF Content Area
              Expanded(
                child: Stack(
                  children: [
                    _isLoading || _localPath == null
                        ? _buildLoader()
                        : SfPdfViewer.file(
                            File(_localPath!),
                            key: _pdfViewerKey,
                            controller: _pdfViewerController,
                            onPageChanged: (details) {
                              _currentPageNotifier.value = details.newPageNumber - 1;
                              SharedPreferences.getInstance().then((prefs) {
                                prefs.setInt(_storageKey, details.newPageNumber - 1);
                              });
                            },
                            onDocumentLoaded: (details) {
                              _totalPagesNotifier.value = details.document.pages.count;
                            },
                            onTap: (details) {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _toggleControls();
                            },
                            enableDoubleTapZooming: true,
                            enableTextSelection: false, 
                            otherSearchTextHighlightColor: Colors.red.withOpacity(0.15), // Very light red (pale) for text clarity
                            currentSearchTextHighlightColor: Colors.red.withOpacity(0.4), // Medium red for active match
                            maxZoomLevel: 15.0,
                            pageSpacing: 2, 
                            canShowScrollHead: true,
                            canShowPaginationDialog: true, 
                            enableHyperlinkNavigation: false, 
                            pageLayoutMode: PdfPageLayoutMode.continuous,
                            interactionMode: PdfInteractionMode.pan,
                          ),


                
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3),
          const SizedBox(height: 20),
          Text("Loading HD PDF Engine...", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 15,
        left: 15,
        right: 15,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
          _buildGlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => Navigator.pop(context),
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _isSearching 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Live Match Badge (ValueListenable ensures it updates without rebuilding TextField)
                        ValueListenableBuilder<PdfTextSearchResult?>(
                          valueListenable: _searchResultNotifier,
                          builder: (context, result, _) {
                            if (result == null || result.totalInstanceCount == 0) return const SizedBox();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "${result.currentInstanceIndex}/${result.totalInstanceCount}",
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            );
                          },
                        ),
                        
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.text,
                            style: GoogleFonts.inter(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search PDF...",
                              border: InputBorder.none,
                              hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                              isDense: true,
                            ),
                            onChanged: (text) {
                              _hideControlsTimer?.cancel();
                              // Performance: Update search result without full setState rebuild
                              _searchResultNotifier.value?.removeListener(_onSearchResultChanged);
                              
                              if (text.isNotEmpty) {
                                final result = _pdfViewerController.searchText(text);
                                result.addListener(_onSearchResultChanged);
                                _searchResultNotifier.value = result;
                              } else {
                                _searchResultNotifier.value?.clear();
                                _searchResultNotifier.value = null;
                              }
                            },
                            onSubmitted: (_) {
                              // Keyboard 'Done' action triggers EXIT search
                              setState(() {
                                _isSearching = false;
                                _searchResultNotifier.value?.clear();
                                _searchResultNotifier.value = null;
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    widget.title ?? "Reading...",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
          ),
          
          // Navigation & Page Counter
          if (!_isSearching) ...[
            ValueListenableBuilder2<int, int>(
              first: _currentPageNotifier,
              second: _totalPagesNotifier,
              builder: (context, currentPage, totalPages, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${currentPage + 1} / $totalPages",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder2<int, int>(
              first: _currentPageNotifier,
              second: _totalPagesNotifier,
              builder: (context, currentPage, totalPages, _) {
                return Row(
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.chevron_left_rounded,
                      onPressed: currentPage > 0 ? () => _pdfViewerController.previousPage() : null,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildGlassIconButton(
                      icon: Icons.chevron_right_rounded,
                      onPressed: currentPage < (totalPages - 1) ? () => _pdfViewerController.nextPage() : null,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
          ]
          else ...[
            // Wrap in Builder to reactive to search result instance changes
            ValueListenableBuilder<PdfTextSearchResult?>(
              valueListenable: _searchResultNotifier,
              builder: (context, result, _) {
                return Row(
                  children: [
                    _buildGlassIconButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onPressed: result != null && result.hasResult ? () {
                        result.previousInstance();
                        _hideControlsTimer?.cancel();
                      } : null,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildGlassIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onPressed: result != null && result.hasResult ? () {
                        result.nextInstance();
                        _hideControlsTimer?.cancel();
                      } : null,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            ),
          ],
          
          const SizedBox(width: 6),
          
          _buildGlassIconButton(
            icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
            onPressed: () {
              if (_isSearching) {
                _closeSearch();
              } else {
                setState(() => _isSearching = true);
              }
            },
            isDark: isDark,
          ),
        ],
      ),
    ),
  );
}

  void _closeSearch() {
    setState(() {
      _searchController.clear();
      _searchResultNotifier.value?.removeListener(_onSearchResultChanged);
      _searchResultNotifier.value?.clear();
      _searchResultNotifier.value = null;
      _isSearching = false;
      FocusScope.of(context).unfocus();
    });
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback? onPressed, required bool isDark}) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // Solid Black Card look
          color: isDark 
              ? (onPressed == null ? Colors.white.withOpacity(0.05) : const Color(0xFF1A1A1A)) 
              : Colors.black.withOpacity(onPressed == null ? 0.02 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(isDark ? 0.1 : 0.08),
            width: 1.2,
          ),
          boxShadow: [
            if (isDark && onPressed != null)
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Icon(
          icon, 
          size: 20, 
          color: (isDark ? Colors.white : Colors.black87).withOpacity(onPressed == null ? 0.3 : 1.0)
        ),
      ),
    );
  }

  Widget _buildPageCard(bool isDark) {
    return ValueListenableBuilder2<int, int>(
      first: _currentPageNotifier,
      second: _totalPagesNotifier,
      builder: (context, currentPage, totalPages, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.8),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.import_contacts_rounded,
                    size: 14,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${currentPage + 1}",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900, 
                      color: isDark ? Colors.white : Colors.black87, 
                      fontSize: 18,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      "/",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.withOpacity(0.5),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  Text(
                    "$totalPages",
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: AppTheme.primaryColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController();
    final total = _totalPagesNotifier.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Jump to Page", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "1 - $total",
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page > 0 && page <= total) {
                _pdfViewerController.jumpToPage(page);
                Navigator.pop(context);
              }
            },
            child: const Text("Go", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// A helper class to listen to two ValueListenables simultaneously.
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
    this.child,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget? child;
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
        valueListenable: first,
        builder: (_, a, __) => ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, __) => builder(context, a, b, child),
        ),
      );
}
