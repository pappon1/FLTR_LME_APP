import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactLinksScreen extends StatefulWidget {
  const ContactLinksScreen({super.key});

  @override
  State<ContactLinksScreen> createState() => _ContactLinksScreenState();
}

class _ContactLinksScreenState extends State<ContactLinksScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLinks();
  }

  Future<void> _fetchLinks() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('contact_links').get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _whatsappController.text = (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) 
            ? data['whatsapp'] 
            : '+92 9365523684';
        _instagramController.text = data['instagram'] ?? '';
        _facebookController.text = data['facebook'] ?? '';
        _youtubeController.text = data['youtube'] ?? '';
      } else {
        // Default for new setup
        _whatsappController.text = '+92 9365523684';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching links: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLinks() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('contact_links').set({
        'whatsapp': _whatsappController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Links updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving links: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;


    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Manage Contact Links', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                   _buildLinkCard(
                     context, 
                     'WhatsApp', 
                     FontAwesomeIcons.whatsapp, 
                     Colors.green, 
                     _whatsappController,
                     'e.g. https://wa.me/919999999999'
                   ),
                   const SizedBox(height: 16),
                   _buildLinkCard(
                     context, 
                     'Instagram', 
                     FontAwesomeIcons.instagram, 
                     Colors.pink, 
                     _instagramController,
                     'e.g. https://instagram.com/your_handle'
                   ),
                   const SizedBox(height: 16),
                   _buildLinkCard(
                     context, 
                     'Facebook', 
                     FontAwesomeIcons.facebook, 
                     Colors.blue, 
                     _facebookController,
                     'e.g. https://facebook.com/your_page'
                   ),
                   const SizedBox(height: 16),
                   _buildLinkCard(
                     context, 
                     'YouTube', 
                     FontAwesomeIcons.youtube, 
                     Colors.red, 
                     _youtubeController,
                     'e.g. https://youtube.com/@your_channel'
                   ),
                   const SizedBox(height: 32),
                   
                   SizedBox(
                     width: double.infinity,
                     height: 50,
                     child: ElevatedButton(
                       onPressed: _isSaving ? null : _saveLinks,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: theme.primaryColor,
                         elevation: 2,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
                       ),
                       child: _isSaving 
                         ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                         : Text(
                             'Save Changes',
                             style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                           ),
                     ),
                   ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildLinkCard(BuildContext context, String title, IconData icon, Color iconColor, TextEditingController controller, String hint) {
    final theme = Theme.of(context);
    final cardColor = theme.cardTheme.color ?? Colors.white;
    final borderColor = theme.dividerColor.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(3.0), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.link, size: 18, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }
}

