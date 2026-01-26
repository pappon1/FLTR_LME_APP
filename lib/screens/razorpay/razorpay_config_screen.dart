import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import '../../services/razorpay_service.dart';

class RazorpayConfigScreen extends StatefulWidget {
  const RazorpayConfigScreen({super.key});

  @override
  State<RazorpayConfigScreen> createState() => _RazorpayConfigScreenState();
}

class _RazorpayConfigScreenState extends State<RazorpayConfigScreen> {
  final _keyIdController = TextEditingController();
  final _keySecretController = TextEditingController();
  final _service = RazorpayService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoading = true);
    final keys = await _service.getKeys();
    _keyIdController.text = keys['key_id'] ?? '';
    _keySecretController.text = keys['key_secret'] ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveKeys() async {
    if (_keyIdController.text.isEmpty || _keySecretController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill both fields")));
      return;
    }

    setState(() => _isLoading = true);
    await _service.saveKeys(_keyIdController.text, _keySecretController.text);
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keys Saved Successfully!")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text("Razorpay Configuration", style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "Enter your Razorpay API Keys to enable dashboard analytics. You can find these in your Razorpay Dashboard > Settings > API Keys.",
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _keyIdController,
              decoration: InputDecoration(
                labelText: "Key ID",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(3.0)),
                prefixIcon: const Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _keySecretController,
              decoration: InputDecoration(
                labelText: "Key Secret",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(3.0)),
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveKeys,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Save Configuration", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

