import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl.dart';
import '../../services/razorpay_service.dart';
import '../../widgets/shimmer_loading.dart';

class RazorpaySettlementsScreen extends StatefulWidget {
  const RazorpaySettlementsScreen({super.key});

  @override
  State<RazorpaySettlementsScreen> createState() => _RazorpaySettlementsScreenState();
}

class _RazorpaySettlementsScreenState extends State<RazorpaySettlementsScreen> {
  final _service = RazorpayService();
  bool _isLoading = true;
  List<dynamic> _settlements = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _service.fetchSettlements();
      setState(() {
        _settlements = data['items'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settlements", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? SimpleShimmerList(itemHeight: 80.0)
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $_error\n\nPlease check your API Keys in Config.", textAlign: TextAlign.center)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _settlements.length,
                  itemBuilder: (context, index) {
                    final item = _settlements[index];
                    final amount = (item['amount'] ?? 0) / 100; // Razorpay is in paise
                    final date = DateTime.fromMillisecondsSinceEpoch((item['created_at'] ?? 0) * 1000);
                    final status = item['status'] ?? 'unknown';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: status == 'processed' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                          child: Icon(Icons.account_balance, color: status == 'processed' ? Colors.green : Colors.orange, size: 20),
                        ),
                        title: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text("₹$amount", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                        subtitle: Text(DateFormat('MMM d, y • h:mm a').format(date)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'processed' ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
