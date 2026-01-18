import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/course_model.dart';
import '../../../services/security/security_service.dart'; // Add this import

class ManualEnrollmentScreen extends StatefulWidget {
  const ManualEnrollmentScreen({super.key});

  @override
  State<ManualEnrollmentScreen> createState() => _ManualEnrollmentScreenState();
}

class _ManualEnrollmentScreenState extends State<ManualEnrollmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // State
  bool _isLoading = false;
  Timer? _debounce; // Debounce timer
  String? _selectedCourseId;
  DateTime? _selectedExpiryDate;
  String _validityType = 'Course Validity'; // Default to Course Validity
  
  // Existing User Search
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];
  DocumentSnapshot? _selectedUser;
  
  // New User Form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // Data
  List<CourseModel> _courses = [];
  String? _emailSuffix = '@gmail.com';

  final Color _techDark = const Color(0xFF1A1A2E);
  final Color _techBlue = const Color(0xFF16213E);
  final Color _neonGreen = const Color(0xFF4ECCA3);
  final Color _neonBlue = const Color(0xFF00C9FF);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').get();
    setState(() {
      _courses = snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
    });
  }

  // --- Logic: Search User (Multi-field, Real-time) ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUser(query);
    });
  }

  Future<void> _searchUser(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    
    try {
      // 1. Search by Email (Prefix)
      final emailQuery = FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: lowerQuery)
          .where('email', isLessThan: '$lowerQuery\uf8ff')
          .limit(10)
          .get();

       // 2. Search by Phone (Prefix)
      final phoneQuery = FirebaseFirestore.instance
          .collection('users')
          .where('phone', isGreaterThanOrEqualTo: query)
          .where('phone', isLessThan: '$query\uf8ff')
          .limit(10)
          .get();

      // 3. Search by Name (Case-sensitive prefix usually in Firestore)
      // We try exact case or capitalized since Firestore lacks case-insensitive index without effort
      final nameQuery = FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(10)
          .get();
          
      final results = await Future.wait([emailQuery, phoneQuery, nameQuery]);
      
      final Set<String> addedIds = {};
      final List<DocumentSnapshot> mergedList = [];
      
      for (var snap in results) {
        for (var doc in snap.docs) {
          if (addedIds.add(doc.id)) {
            mergedList.add(doc);
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = mergedList;
        });
      }
    } catch (e) {
      // debugPrint("Search error: $e");
    }
  }

  // --- Logic: Create User (Secondary App) ---
  Future<UserCredential?> _createNewUser(String email) async {
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'tempAuthApp',
        options: Firebase.app().options,
      );
      
      // Generate a random specific password
      final randomPass = 'User@${Random().nextInt(9000) + 1000}';
      
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final credential = await tempAuth.createUserWithEmailAndPassword(
        email: email, 
        password: randomPass
      );
      
      return credential;
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth Error: ${e.message}'), backgroundColor: Colors.red));
      }
      return null;
    } finally {
      await tempApp?.delete(); // Clean up
    }
  }

  // --- Logic: Secure Submission ---
  Future<void> _verifyAndSubmit() async {
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a course')));
      return;
    }

    if (_tabController.index == 0 && _selectedUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a user first')));
       return;
    }

    if (_tabController.index == 1 && !_formKey.currentState!.validate()) {
      return;
    }

    // Verify Admin PIN using existing SecurityService
    final isAuthenticated = await SecurityService.verifyPin(context);
    
    if (isAuthenticated) {
      unawaited(_processEnrollment());
    }
  }

  Future<void> _processEnrollment() async {
    setState(() => _isLoading = true);
    String? studentId;
    String? studentName;
    String? studentEmail;

    try {
      if (_tabController.index == 0) {
        // Tab 1: Existing User
        studentId = _selectedUser!.id;
        final data = _selectedUser!.data() as Map<String, dynamic>;
        studentName = data['name'] ?? 'Unknown';
        studentEmail = data['email'];
      } else {
        // Tab 2: New User
        // 1. Create Auth User
        final emailInput = _emailController.text.trim();
        final fullEmail = emailInput.contains('@') ? emailInput : '$emailInput@gmail.com';
        
        final credential = await _createNewUser(fullEmail);
        if (credential == null) {
          setState(() => _isLoading = false);
          return;
        }
        
        studentId = credential.user!.uid;
        studentName = _nameController.text.trim();
        studentEmail = fullEmail;
        
        // 2. Create Firestore User Doc
        await FirebaseFirestore.instance.collection('users').doc(studentId).set({
          'name': studentName,
          'email': studentEmail,
          'phone': _phoneController.text.trim(),
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'enrolledCourses': 0,
          'isActive': true,
          'avatarUrl': 'https://ui-avatars.com/api/?name=$studentName&background=random',
        });
      }

      // Calculate Expiry
      DateTime? expiry;
      if (_validityType == '1 Year') {
        expiry = DateTime.now().add(const Duration(days: 365));
      } else if (_validityType == 'Custom' && _selectedExpiryDate != null) {
        expiry = _selectedExpiryDate;
      } 
      // 'Course Validity' and 'Lifetime' default to null (Lifetime access) 
      // until CourseModel has a specific validity field.

      // 3. Enroll Student
      await FirebaseFirestore.instance.collection('enrollments').add({
        'studentId': studentId,
        'courseId': _selectedCourseId,
        'enrolledAt': FieldValue.serverTimestamp(),
        'expiryDate': expiry != null ? Timestamp.fromDate(expiry) : null,
        'progress': 0,
        'completedVideos': [],
        'isActive': true,
        'enrolledBy': 'admin',
      });
      
      // 4. Update Student Course Count
      await FirebaseFirestore.instance.collection('users').doc(studentId).update({
        'enrolledCourses': FieldValue.increment(1),
      });

      if (!mounted) return;
      
      // Show Success Dialog
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: _techDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _neonGreen)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: _neonGreen, size: 60),
              const SizedBox(height: 20),
              Text('ACTIVATION SUCCESSFUL', style: GoogleFonts.orbitron(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('$studentName has been enrolled successfully.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { 
                Navigator.pop(ctx); 
                Navigator.pop(context); 
              }, 
              child: Text('DONE', style: TextStyle(color: _neonGreen, fontWeight: FontWeight.bold))
            )
          ],
        ),
      ));

    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('MANUAL ENROLLMENT', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_techDark, _techBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
               const SizedBox(height: 10),
               // Custom Tab Bar
               Container(
                 margin: const EdgeInsets.symmetric(horizontal: 20),
                 padding: const EdgeInsets.all(4),
                 decoration: BoxDecoration(
                   color: Colors.white.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(30),
                   border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                 ),
                 child: TabBar(
                   controller: _tabController,
                   indicator: BoxDecoration(
                     color: _neonBlue,
                     borderRadius: BorderRadius.circular(25),
                     boxShadow: [BoxShadow(color: _neonBlue.withValues(alpha: 0.4), blurRadius: 10)],
                   ),
                   dividerColor: Colors.transparent, // REMOVED WHITE DIVIDER LINE
                   labelColor: Colors.white,
                   unselectedLabelColor: Colors.white70,
                   labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                   tabs: const [
                     Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('EXISTING USER'))),
                     Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('NEW USER (CREATE)'))),
                   ],
                 ),
               ),
               
               const SizedBox(height: 20),

               // Tab Content
               Expanded(
                 child: TabBarView(
                   controller: _tabController,
                   children: [
                     _buildExistingUserTab(),
                     _buildNewUserTab(),
                   ],
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingUserTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: _buildTechTextField(
            controller: _searchController, 
            label: 'SEARCH USER (NAME, EMAIL, OR PHONE)',
            icon: Icons.search,
            onChanged: _onSearchChanged,
            keyboardType: TextInputType.text, 
            suffix: _searchController.text.isNotEmpty 
              ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54), onPressed: () { 
                  setState(() {
                    _searchController.clear(); 
                    _searchResults = [];
                    _selectedUser = null;
                  });
                })
              : null
          ),
        ),

        // 1. IF USER IS SELECTED -> SHOW FORM
        if (_selectedUser != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _neonGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _neonGreen.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: _neonGreen, child: const Icon(Icons.check, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((_selectedUser!.data() as Map)['name'] ?? 'User', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                              Text((_selectedUser!.data() as Map)['email'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70), 
                          onPressed: () => setState(() => _selectedUser = null)
                        )
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 30),
                  _buildSectionHeader("ENROLLMENT DETAILS"),
                  const SizedBox(height: 16),
                  _buildCourseSelector(),
                  
                  const SizedBox(height: 40),
                  _buildActionBtn('ACTIVATE COURSE', _verifyAndSubmit),
                ],
              ),
            ),
          )
        
        // 2. ELSE IF SEARCHING -> SHOW EXPANDED LIST
        else if (_searchController.text.isNotEmpty)
          Expanded(
            child: _searchResults.isEmpty
              ? Center(child: Text("No users found.", style: GoogleFonts.poppins(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final data = _searchResults[index].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(data['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${data['email']}\n${data['phone'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        isThreeLine: true,
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _neonBlue, foregroundColor: Colors.white),
                          onPressed: () => setState(() {
                            _selectedUser = _searchResults[index];
                            // Don't clear search text, just show selection
                            // _searchController.clear(); 
                          }),
                          child: const Text('SELECT'),
                        ),
                      ),
                    ).animate().slideX(duration: 200.ms, begin: 0.1);
                  },
                ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                   // Placeholder for User
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_search, color: Colors.white.withValues(alpha: 0.3), size: 40),
                        const SizedBox(height: 10),
                        Text("Search and Select a User above", style: GoogleFonts.poppins(color: Colors.white38)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionHeader("ENROLLMENT DETAILS"),
                  const SizedBox(height: 16),
                  _buildCourseSelector(),
                  
                  const SizedBox(height: 40),
                  _buildActionBtn('ACTIVATE COURSE', _verifyAndSubmit),
                ],
              ),
            ),
          ), 
      ],
    );
  }

  Widget _buildNewUserTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildSectionHeader("PERSONAL DETAILS"),
            const SizedBox(height: 16),
            _buildTechTextField(controller: _nameController, label: 'FULL NAME', icon: Icons.person),
            const SizedBox(height: 12),
            _buildTechTextField(
              controller: _emailController, 
              label: 'EMAIL ADDRESS', 
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              suffixText: _emailSuffix,
              onChanged: (val) => setState(() => _emailSuffix = val.contains('@') ? null : '@gmail.com'),
              inputFormatters: [_NoSpaceFormatter(context, 'Email')],
            ),
            const SizedBox(height: 12),
            _buildTechTextField(
              controller: _phoneController, 
              label: 'WHATSAPP NO', 
              icon: FontAwesomeIcons.whatsapp,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, // Allow only digits
                _NoSpaceFormatter(context, 'WhatsApp No'),
              ],
            ),
            
            const SizedBox(height: 30),
            _buildSectionHeader("COURSE ACTIVATION"),
            const SizedBox(height: 16),
            _buildCourseSelector(),
            
            const SizedBox(height: 40),
            _buildActionBtn('CREATE & ENROLL', _verifyAndSubmit),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("SELECT COURSE", style: GoogleFonts.rubik(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
           DropdownButtonFormField<String>(
            dropdownColor: _techDark,
            isExpanded: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(null),
            initialValue: _selectedCourseId,
            items: _courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedCourseId = v),
            hint: const Text("Choose Course", style: TextStyle(color: Colors.white38), overflow: TextOverflow.ellipsis),
          ),
          
          const SizedBox(height: 20),
          Text("VALIDITY / EXPIRY", style: GoogleFonts.rubik(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
               Expanded(
                child: DropdownButtonFormField<String>(
                  dropdownColor: _techDark,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(null),
                  initialValue: _validityType,
                  items: ['Course Validity', 'Lifetime', '1 Year', 'Custom'].map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _validityType = v!),
                ),
              ),
              if (_validityType == 'Custom') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context, 
                        firstDate: DateTime.now(), 
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(primary: _neonBlue, onPrimary: Colors.white, surface: _techBlue, onSurface: Colors.white),
                            ), child: child!);
                        }
                      );
                      if (date != null) setState(() => _selectedExpiryDate = date);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration(Icons.calendar_today),
                      child: Text(
                        _selectedExpiryDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon,
    bool isObscure = false,
    Function(String)? onSubmitted,
    Function(String)? onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffix,
    String? suffixText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(icon, suffixText: suffixText).copyWith(
        labelText: label,
        suffixIcon: suffix,
      ),
      validator: (v) => v!.isEmpty ? 'Required' : null,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration(IconData? icon, {String? suffixText}) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon, color: _neonBlue.withValues(alpha: 0.7), size: 18) : null,
      suffixText: suffixText,
      suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      filled: true,
      fillColor: Colors.black12,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _neonBlue, width: 1.5)),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: _neonBlue, margin: const EdgeInsets.only(right: 8)),
        Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildActionBtn(String label, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [_neonBlue, const Color(0xFF0072FF)]),
        boxShadow: [BoxShadow(color: _neonBlue.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}

// Custom Formatter to Disallow Spaces and Warn User
class _NoSpaceFormatter extends TextInputFormatter {
  final BuildContext context;
  final String fieldName;

  _NoSpaceFormatter(this.context, this.fieldName);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.contains(' ')) {
      // Show warning only if it's a new space insertion (not just existing)
      if (!oldValue.text.contains(' ')) {
         ScaffoldMessenger.of(context).removeCurrentSnackBar();
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Spaces are not allowed in $fieldName!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed, // Use fixed behavior to avoid floating too high
          ),
        );
      }
      return oldValue; // Revert content
    }
    return newValue;
  }
}
