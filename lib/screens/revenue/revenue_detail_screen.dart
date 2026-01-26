import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../utils/app_theme.dart';
import 'all_transactions_screen.dart';

class RevenueDetailScreen extends StatefulWidget {
  const RevenueDetailScreen({super.key});

  @override
  State<RevenueDetailScreen> createState() => _RevenueDetailScreenState();
}

class _RevenueDetailScreenState extends State<RevenueDetailScreen> {
  String _selectedFilter = '7 Days';
  bool _isLoading = true;
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _chartData = [];
  List<DocumentSnapshot> _recentTransactions = [];
  Map<String, double> _coursePrices = {};

  // Professional Color Palette


  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch Course Prices for calculation
      final courseSnaps = await FirebaseFirestore.instance.collection('courses').get();
      _coursePrices = {
        for (var doc in courseSnaps.docs) 
          doc.id: (doc.data()['price'] ?? 0).toDouble()
      };

      // 2. Determine Date Range
      final DateTime now = DateTime.now();
      DateTime? startDate;
      
      if (_selectedFilter == '7 Days') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (_selectedFilter == '1 Month') {
        startDate = now.subtract(const Duration(days: 30));
      } else if (_selectedFilter == '1 Year') {
        startDate = now.subtract(const Duration(days: 365));
      }
      // Lifetime = null

      // 3. Query Enrollments
      Query query = FirebaseFirestore.instance.collection('enrollments').orderBy('enrolledAt', descending: true);
      
      if (startDate != null) {
        query = query.where('enrolledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      final enrollments = await query.get();
      
      // 4. Process Data
      double totalRev = 0;
      final Map<int, double> dateBuckets = {}; // Timestamp ms -> Value
      final List<DocumentSnapshot> transactions = [];
      
      for (var doc in enrollments.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final courseId = data['courseId'];
        final price = _coursePrices[courseId] ?? 0.0; // Assume stored price or fetch
        
        // Accumulate Revenue
        totalRev += price;
        
        // Recent Transactions (First 5)
        if (transactions.length < 5) transactions.add(doc);
        
        // Group for Chart
        final DateTime date = (data['enrolledAt'] as Timestamp).toDate();
        DateTime bucketDate;
        if (_selectedFilter == '1 Year' || _selectedFilter == 'Lifetime') {
           bucketDate = DateTime(date.year, date.month);
        } else {
           bucketDate = DateTime(date.year, date.month, date.day);
        }
        
        final int ms = bucketDate.millisecondsSinceEpoch;
        dateBuckets[ms] = (dateBuckets[ms] ?? 0) + price;
      }
      
      final sortedMs = dateBuckets.keys.toList()..sort();
      _chartData = sortedMs.map((ms) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        return {
          'label': (_selectedFilter == '1 Year' || _selectedFilter == 'Lifetime') ? DateFormat('MMM').format(dt) : DateFormat('dd').format(dt),
          'value': dateBuckets[ms],
          'fullDate': dt
        };
      }).toList();

      setState(() {
        _totalRevenue = totalRev;
        _recentTransactions = transactions;
        _isLoading = false;
      });
      
    } catch (e) {
      // debugPrint("Error fetching revenue: $e");
      setState(() {
        _isLoading = false;
        _totalRevenue = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    const successColor = AppTheme.accentColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final cardColor = theme.cardTheme.color ?? Colors.white;
    final subTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Revenue Analytics', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : RefreshIndicator(
            onRefresh: _fetchData,
            color: primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Theme-Aware Filters
                  Container(
                    height: 45,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['7 Days', '1 Month', '1 Year', 'Lifetime'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return GestureDetector(
                          onTap: () {
                             setState(() => _selectedFilter = filter);
                             _fetchData();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            margin: const EdgeInsets.only(right: 0),
                            decoration: BoxDecoration(
                              color: isSelected ? cardColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(3.0),
                              boxShadow: isSelected 
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                : [],
                            ),
                            child: Center(
                              child: Text(
                                filter,
                                style: GoogleFonts.inter(
                                  color: isSelected ? textColor : subTextColor,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. Main Revenue Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(3.0),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Revenue',
                          style: GoogleFonts.inter(color: subTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₹${NumberFormat('#,##,###').format(_totalRevenue)}',
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: successColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_upward, color: successColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '$_selectedFilter Period',
                                style: GoogleFonts.inter(color: successColor, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 3. Chart Section
                  Text("Revenue Trend", style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(3.0),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: _chartData.isEmpty 
                      ? Center(child: Text("No Data available", style: GoogleFonts.inter(color: subTextColor)))
                      : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: _chartData.map((e) => e['value'] as double).reduce(max) / 5 == 0 ? 1 : _chartData.map((e) => e['value'] as double).reduce(max) / 5,
                            getDrawingHorizontalLine: (value) => FlLine(color: theme.dividerColor.withValues(alpha: 0.5), strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < _chartData.length) {
                                     final int step = (_chartData.length / 6).ceil();
                                     if (value.toInt() % step == 0) {
                                       return Padding(
                                         padding: const EdgeInsets.only(top: 8.0),
                                         child: Text(_chartData[value.toInt()]['label'], style: GoogleFonts.inter(color: subTextColor, fontSize: 11)),
                                       );
                                     }
                                  }
                                  return const SizedBox.shrink();
                                },
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(NumberFormat.compact().format(value), style: GoogleFonts.inter(color: subTextColor, fontSize: 11));
                                }
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _chartData.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), (e.value['value'] as double));
                              }).toList(),
                              isCurved: true,
                              color: primaryColor,
                              barWidth: 5,
                              isStrokeCapRound: true,
                              shadow: Shadow(color: primaryColor.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 2,
                                  color: Colors.white,
                                  strokeWidth: 3,
                                  strokeColor: primaryColor,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [primaryColor.withValues(alpha: 0.2), primaryColor.withValues(alpha: 0.0)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => isDark ? Colors.white : Colors.blueGrey.shade800,
                              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              tooltipMargin: 10,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((LineBarSpot touchedSpot) {
                                  final val = touchedSpot.y;
                                  return LineTooltipItem(
                                    '₹${NumberFormat('#,##,###').format(val)}',
                                     TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                  ),

                  const SizedBox(height: 32),

                  // 4. Recent Transactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Recent Transactions", style: GoogleFonts.outfit(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const AllTransactionsScreen()));
                        },
                        child: Text("View All", style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _recentTransactions.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text("No transactions yet.", style: GoogleFonts.inter(color: subTextColor)),
                      ))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentTransactions.length,
                        itemBuilder: (context, index) {
                           final data = _recentTransactions[index].data() as Map<String, dynamic>;
                           final price = _coursePrices[data['courseId']] ?? 0.0;
                           final date = (data['enrolledAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                           return Container(
                             margin: const EdgeInsets.only(bottom: 12),
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: cardColor,
                               borderRadius: BorderRadius.circular(3.0),
                               border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                             ),
                             child: Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.all(12),
                                   decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                   child: Icon(FontAwesomeIcons.arrowDown, color: primaryColor, size: 16),
                                 ),
                                 const SizedBox(width: 16),
                                 Expanded(
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(
                                         data['studentName'] ?? 'Unknown User',
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
                                       ),
                                       Text(
                                         '${DateFormat('MMM d, h:mm a').format(date)} • ${data['courseId'] ?? ''}',
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                         style: GoogleFonts.inter(color: subTextColor, fontSize: 12),
                                       ),
                                     ],
                                   ),
                                 ),
                                 FittedBox(
                                   fit: BoxFit.scaleDown,
                                   alignment: Alignment.centerRight,
                                   child: Text(
                                     '+₹${price.toInt()}',
                                     style: GoogleFonts.inter(color: successColor, fontWeight: FontWeight.bold, fontSize: 16),
                                   ),
                                 ),
                               ],
                             ),
                           );
                        },
                      ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }
}

