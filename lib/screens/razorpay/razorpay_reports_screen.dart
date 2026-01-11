import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/razorpay_service.dart';

class RazorpayReportsScreen extends StatefulWidget {
  const RazorpayReportsScreen({super.key});

  @override
  State<RazorpayReportsScreen> createState() => _RazorpayReportsScreenState();
}

class _RazorpayReportsScreenState extends State<RazorpayReportsScreen> {
  final _service = RazorpayService();
  bool _isLoading = true;
  List<dynamic> _payments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _service.fetchPayments();
      setState(() {
        _payments = data['items'] ?? [];
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
        title: Text("Recent Payments (Reports)", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Error: $_error\n\nPlease check your API Keys in Config.", textAlign: TextAlign.center)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final item = _payments[index];
                    final amount = (item['amount'] ?? 0) / 100;
                    final date = DateTime.fromMillisecondsSinceEpoch((item['created_at'] ?? 0) * 1000);
                    final status = item['status'] ?? 'unknown';
                    final email = item['email'] ?? 'No Email';
                    final contact = item['contact'] ?? 'No Contact';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: status == 'captured' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(status == 'captured' ? Icons.check : Icons.error, color: status == 'captured' ? Colors.green : Colors.red, size: 20),
                        ),
                        title: Text("₹$amount", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("$email • $contact", style: const TextStyle(fontSize: 12)),
                            Text(DateFormat('MMM d, y • h:mm a').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'captured' ? Colors.green : Colors.redAccent,
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
