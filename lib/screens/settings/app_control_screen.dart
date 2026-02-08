import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

class AppControlScreen extends StatefulWidget {
  const AppControlScreen({super.key});

  @override
  State<AppControlScreen> createState() => _AppControlScreenState();
}

class _AppControlScreenState extends State<AppControlScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  late TextEditingController _minVersionController;
  late TextEditingController _maintenanceMessageController;

  // State variables
  bool _isMaintenanceMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _minVersionController = TextEditingController();
    _maintenanceMessageController = TextEditingController();
    _fetchSettings();
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _maintenanceMessageController.dispose();
    super.dispose();
  }

  // Fetch current settings from Firestore
  Future<void> _fetchSettings() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('app_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _minVersionController.text = data['min_version'] ?? '1.0.0';
          _maintenanceMessageController.text =
              data['maintenance_message'] ??
              'Server is under maintenance. Please try again later.';
          _isMaintenanceMode = data['is_maintenance_mode'] ?? false;
        });
      } else {
        // Set defaults if document doesn't exist
        setState(() {
          _minVersionController.text = '1.0.0';
          _maintenanceMessageController.text =
              'Server is under maintenance. Please try again later.';
          _isMaintenanceMode = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save settings to Firestore
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('config').doc('app_settings').set({
        'min_version': _minVersionController.text.trim(),
        'maintenance_message': _maintenanceMessageController.text.trim(),
        'is_maintenance_mode': _isMaintenanceMode,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App configuration updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Control Center', style: AppTheme.heading2(context)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.deepOrange.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepOrange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Global Configuration',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Changes affect ALL users immediately.',
                                  style: GoogleFonts.inter(
                                    color: Colors.deepOrange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Version Control Section
                    Text(
                      'VERSION CONTROL',
                      style: AppTheme.bodySmall(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              controller: _minVersionController,
                              label: 'Minimum Supported Version',
                              icon: Icons.numbers,
                              helperText: 'e.g. 1.0.2',
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                if (!RegExp(
                                  r'^\d+\.\d+\.\d+$',
                                ).hasMatch(value)) {
                                  return 'Format: x.x.x';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Users on older versions will be forced to update their app.',
                              style: AppTheme.bodySmall(context),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Maintenance Section
                    Text(
                      'MAINTENANCE',
                      style: AppTheme.bodySmall(
                        context,
                      ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            value: _isMaintenanceMode,
                            onChanged: (val) {
                              setState(() {
                                _isMaintenanceMode = val;
                              });
                            },
                            title: const Text(
                              'Maintenance Mode',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              _isMaintenanceMode
                                  ? 'App is currently locked for users'
                                  : 'App is active',
                              style: TextStyle(
                                color: _isMaintenanceMode
                                    ? Colors.red
                                    : Colors.green,
                                fontSize: 13,
                              ),
                            ),
                            activeThumbColor: Colors.red,
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isMaintenanceMode
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.construction,
                                color: _isMaintenanceMode
                                    ? Colors.red
                                    : Colors.green,
                                size: 20,
                              ),
                            ),
                          ),

                          if (_isMaintenanceMode) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildTextField(
                                controller: _maintenanceMessageController,
                                label: 'Maintenance Message',
                                icon: Icons.message,
                                maxLines: 3,
                                helperText: 'Shown to users on lock screen',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: Theme.of(context).elevatedButtonTheme.style
                            ?.copyWith(
                              backgroundColor: WidgetStateProperty.all(
                                AppTheme.primaryColor,
                              ),
                              foregroundColor: WidgetStateProperty.all(
                                Colors.white,
                              ),
                              elevation: WidgetStateProperty.all(2),
                            ),
                        child: const Text(
                          'Save Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.manrope(
        fontSize: 16,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.grey),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
    );
  }
}
