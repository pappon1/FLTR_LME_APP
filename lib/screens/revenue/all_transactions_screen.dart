import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_theme.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  // Professional Color Palette


  bool _isLoading = true;
  List<DocumentSnapshot> _transactions = [];
  Map<String, double> _coursePrices = {}; // Cache

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      // Fetch Prices
      final courseSnaps = await FirebaseFirestore.instance.collection('courses').get();
      _coursePrices = {
        for (var doc in courseSnaps.docs) 
          doc.id: (doc.data()['price'] ?? 0).toDouble()
      };

      // Fetch All Enrollments
      final snapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .orderBy('enrolledAt', descending: true)
          .limit(100) // Limit for performance
          .get();

      setState(() {
        _transactions = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      // debugPrint("Error fetching transactions: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = Theme.of(context).primaryColor;
    const successColor = AppTheme.accentColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final cardColor = theme.cardTheme.color ?? Colors.white;
    final subTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('All Transactions', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : RefreshIndicator(
            onRefresh: _fetchTransactions,
            color: primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final data = _transactions[index].data() as Map<String, dynamic>;
                final price = _coursePrices[data['courseId']] ?? 0.0;
                final date = (data['enrolledAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(3.0),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1), 
                          shape: BoxShape.circle,
                        ),
                        child: Icon(FontAwesomeIcons.arrowDown, color: primaryColor, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['studentName'] ?? 'Unknown User',
                              style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, y • h:mm a').format(date),
                              style: GoogleFonts.inter(color: subTextColor, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                             const SizedBox(height: 2),
                            Text(
                              'Valid: ${data['validityType'] ?? 'Lifetime'}',
                              style: GoogleFonts.inter(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '+ ₹${price.toInt()}',
                              style: GoogleFonts.inter(color: successColor, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3.0)
                            ),
                            child: Text("SUCCESS", style: GoogleFonts.inter(color: successColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: (20 * index).ms).slideX(begin: 0.05, end: 0);
              },
            ),
          ),
    );
  }
}

