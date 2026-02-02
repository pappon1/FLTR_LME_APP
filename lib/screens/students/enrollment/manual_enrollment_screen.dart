import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this for FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../models/course_model.dart';
import '../../../services/security/security_service.dart';
import '../../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../../widgets/tech_text_field.dart';
import '../../../providers/dashboard_provider.dart';

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
  bool _isSearching = false;
  bool _isLoadingCourses = true;
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
  
  Color get _primaryColor => const Color(0xFF6366F1);
  Color _surfaceColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
      ? const Color(0xFF0F1218) 
      : Colors.white;
  Color _borderColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.08);
  Color get _neonGreen => const Color(0xFF10B981);
  Color get _neonBlue => const Color(0xFF6366F1);



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('courses').get();
      setState(() {
        _courses = snapshot.docs.map((doc) => CourseModel.fromFirestore(doc)).toList();
        _isLoadingCourses = false;
      });
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      setState(() => _isLoadingCourses = false);
    }
  }

  // --- Logic: Search User (REAL) ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchUser(query);
    });
  }

  Future<void> _searchUser(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    
    setState(() => _isSearching = true);
    
    // Perform parallel queries for Name, Email, Phone
    // Note: Firestore text search is limited. This is a basic prefix match.
    final usersRef = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').limit(10);
    
    try {
      final results = await Future.wait([
        usersRef.where('name', isGreaterThanOrEqualTo: query).where('name', isLessThan: '$query\uf8ff').get(),
        usersRef.where('name', isGreaterThanOrEqualTo: query.toLowerCase()).where('name', isLessThan: '${query.toLowerCase()}\uf8ff').get(),
        usersRef.where('email', isGreaterThanOrEqualTo: query).where('email', isLessThan: '$query\uf8ff').get(),
        usersRef.where('email', isGreaterThanOrEqualTo: query.toLowerCase()).where('email', isLessThan: '${query.toLowerCase()}\uf8ff').get(),
        usersRef.where('phone', isGreaterThanOrEqualTo: query).where('phone', isLessThan: '$query\uf8ff').get(),
      ]);

      final allDocs = <DocumentSnapshot>[];
      final seenIds = <String>{};

      for (var snap in results) {
        for (var doc in snap.docs) {
          if (!seenIds.contains(doc.id)) {
            allDocs.add(doc);
            seenIds.add(doc.id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchResults = allDocs;
        });
      }
    } catch (e) {
      debugPrint("Error searching user: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // --- Logic: Create User (REAL) ---
  Future<String> _createNewUser(String email) async {
    // Check if user already exists with this email
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw 'A user with this email already exists. Please use "Existing User" tab.';
    }

    // Create a new user specific for manual enrollment
    // Note: This user will need to claim this account or have a separate auth flow
    final docRef = await FirebaseFirestore.instance.collection('users').add({
      'name': _nameController.text.trim(),
      'email': email,
      'phone': _phoneController.text.trim(),
      'role': 'user',
      'enrolledCourses': 0, // Initialize count for new user
      'isActive': true,     // Default active status
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': 'admin_manual_enrollment',
    });
    return docRef.id;
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

    // Verify Admin PIN (REAL)
    final isAuthenticated = await SecurityService.verifyPin(context);
    
    if (isAuthenticated) {
      unawaited(_processEnrollment());
    }
  }

  Future<void> _processEnrollment() async {
    setState(() => _isLoading = true);
    String? studentName;
    String? studentId;

    try {
      if (_tabController.index == 0) {
        // Existing User
        studentName = (_selectedUser!.data() as Map)['name'];
        studentId = _selectedUser!.id;
      } else {
        // New User
        final emailInput = _emailController.text.trim();
        final fullEmail = emailInput.contains('@') ? emailInput : '$emailInput@gmail.com';
        studentName = _nameController.text.trim();
        studentId = await _createNewUser(fullEmail);
      }

      if (_selectedCourseId != null) {
        // --- ⚡ IMPROVED: Check for duplicate enrollment (Only for Existing Users) ---
        if (_tabController.index == 0) {
          final existingEnrollments = await FirestoreService().getStudentEnrollments(studentId);
          if (existingEnrollments.contains(_selectedCourseId)) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User is already enrolled in this course!'), backgroundColor: Colors.orange)
            );
            return;
          }
        }
        DateTime? expiry;
        final selectedCourse = _courses.firstWhere((c) => c.id == _selectedCourseId);
        
        if (_validityType == 'Lifetime') {
          expiry = null;
        } else if (_validityType == '1 Year') {
          expiry = DateTime.now().add(const Duration(days: 365));
        } else if (_validityType == 'Custom') {
          expiry = _selectedExpiryDate;
        } else {
          // Default: Use Course Validity Days
          if (selectedCourse.courseValidityDays > 0) {
            expiry = DateTime.now().add(Duration(days: selectedCourse.courseValidityDays));
          } else {
            expiry = null; // 0 days means lifetime
          }
        }

        // Call Firestore Service
        await FirestoreService().enrollStudent(
          studentId, 
          _selectedCourseId!,
          expiryDate: expiry
        );
        
        // Also update the local user document with enrollment flag/count if needed
        // For now, enrolling via FirestoreService is sufficient
      }

      if (!mounted) return;
      
      // Show Success Dialog
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3.0),
              side: BorderSide(color: _neonGreen.withValues(alpha: 0.5), width: 1),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: _neonGreen, size: 60),
                const SizedBox(height: 20),
                Text('Activation Successful', 
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 16
                  )),
                const SizedBox(height: 10),
                Text('$studentName has been enrolled successfully.', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () { 
                  // Refresh data to reflect new enrollment
                  Provider.of<DashboardProvider>(context, listen: false).refreshData();
                  Navigator.pop(ctx); 
                  Navigator.pop(context); 
                }, 
                child: Text('Done', style: TextStyle(color: _neonGreen, fontWeight: FontWeight.bold))
              )
            ],
          );
        },
      ));

    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : Colors.black87;

    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width > 600;
    final double contentWidth = isTablet ? 600 : size.width;

    final double maxTabWidth = (contentWidth - 48) / 2;
    final double tab1PillWidth = maxTabWidth * 0.65;
    final double tab2PillWidth = maxTabWidth * 0.85;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Manual Enrollment',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 20 : 18,
                letterSpacing: 0.5,
                color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = isTablet ? 30 : 20;
          
          return Container(
            color: backgroundColor,
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    children: [
                      // Custom Tab Bar
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _surfaceColor(context),
                          borderRadius: BorderRadius.circular(50.0),
                          border: Border.all(color: _borderColor(context)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: PillIndicator(
                            color: _primaryColor,
                            height: 32.0,
                            widthTab1: tab1PillWidth,
                            widthTab2: tab2PillWidth,
                            controller: _tabController,
                          ),
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                          labelStyle: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: isTablet ? 14 : 12),
                          tabs: const [
                            Tab(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown, child: Text('Existing User'))),
                            Tab(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('New User (Create)'))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Tab Content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildExistingUserTab(horizontalPadding),
                            _buildNewUserTab(horizontalPadding),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExistingUserTab(double padding) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 10),
            child: TechTextField(
              controller: _searchController, 
              label: 'Search User (Name, Email, or Phone)',
              icon: Icons.search,
              onChanged: _onSearchChanged,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              suffix: _searchController.text.isNotEmpty 
                ? IconButton(icon: Icon(Icons.clear, color: subTextColor), onPressed: () { 
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
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _neonGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(color: _neonGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: _neonGreen, child: const Icon(Icons.check, color: Colors.white)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                _selectedUser != null 
                                  ? (_selectedUser!.data() as Map)['name'] ?? 'User' 
                                  : 'Unknown', 
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)
                              ),
                              Text(
                                _selectedUser != null 
                                  ? (_selectedUser!.data() as Map)['email'] ?? '' 
                                  : 'No Email', 
                                style: GoogleFonts.poppins(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: subTextColor), 
                          onPressed: () => setState(() {
                            _selectedUser = null;
                          })
                        )
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Enrollment Details"),
                  const SizedBox(height: 16),
                  _buildCourseSelector(),
                  
                  const SizedBox(height: 40),
                  _buildActionBtn('Activate Course Access', _verifyAndSubmit),
                ],
              ),
            )
          
          // 2. ELSE IF SEARCHING -> SHOW LIST OR SHIMMER
          else if (_searchController.text.isNotEmpty || _isSearching)
            _isSearching 
              ? Column(
                  children: List.generate(3, (index) => _buildShimmerTile()),
                )
              : (_searchResults.isEmpty)
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: Text("No users found.", style: GoogleFonts.poppins(color: subTextColor))
                )
              : Column(
                  children: [
                    // Firestore Results
                    for (var doc in _searchResults) _buildUserListTile(doc.data() as Map, () => setState(() => _selectedUser = doc)),
                  ],
                )
          else
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                children: [
                   // Placeholder for User
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      borderRadius: BorderRadius.circular(3.0),
                      border: Border.all(color: _borderColor(context)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_search, color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black12, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          "Search and select a user above", 
                          style: GoogleFonts.poppins(
                            color: isDark ? Colors.white38 : Colors.black38, 
                            fontSize: 13.0, 
                            fontWeight: FontWeight.w600
                          )
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Enrollment Details"),
                  const SizedBox(height: 16),
                  _buildCourseSelector(),
                  
                  const SizedBox(height: 40),
                  _buildActionBtn('Activate Course Access', _verifyAndSubmit),
                ],
              ),
            ), 
        ],
      ),
    );
  }

  Widget _buildNewUserTab(double padding) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(padding),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildSectionHeader("Personal Details"),
            const SizedBox(height: 16),
            TechTextField(
              controller: _nameController, 
              label: 'Full Name', 
              icon: Icons.person,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
              validator: (val) => val!.isEmpty ? 'Enter full name' : null,
            ),
            const SizedBox(height: 12),
            TechTextField(
              controller: _emailController, 
              label: 'Email Address / Username', 
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              suffixText: _emailSuffix,
              onChanged: (val) => setState(() => _emailSuffix = val.contains('@') ? null : '@gmail.com'),
              inputFormatters: [_NoSpaceFormatter(context, 'Email')],
              validator: (val) => val!.isEmpty ? 'Enter email' : null,
            ),
            const SizedBox(height: 12),
            TechTextField(
              controller: _phoneController, 
              label: 'WhatsApp No (10-Digit)', 
              icon: FontAwesomeIcons.whatsapp,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
                _NoSpaceFormatter(context, 'WhatsApp No'),
              ],
            ),
            
            const SizedBox(height: 30),
            _buildSectionHeader("Course Activation"),
            const SizedBox(height: 16),
            _buildCourseSelector(),
            
            const SizedBox(height: 40),
            _buildActionBtn('Create & Activate User', _verifyAndSubmit),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSelector() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Course", style: GoogleFonts.rubik(
            color: subTextColor, 
            fontSize: 10.6, 
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600
          )),
          const SizedBox(height: 8),
           _isLoadingCourses 
             ? _buildShimmerBox(height: 50)
             : DropdownButtonFormField<String>(
            dropdownColor: _surfaceColor(context),
            isExpanded: true,
            style: TextStyle(color: textColor),
            decoration: TechTextField.decoration(context),
            initialValue: _selectedCourseId,
            items: _courses.isEmpty 
              ? [const DropdownMenuItem(value: null, child: Text("No Courses Available"))]
              : _courses.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selectedCourseId = v),
            hint: Text(
              "Choose Course", 
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38, 
                fontSize: 13.0, 
                fontWeight: FontWeight.w600
              ), 
              overflow: TextOverflow.ellipsis
            ),
          ),
          
          const SizedBox(height: 20),
          Text("Validity / Expiry", style: GoogleFonts.rubik(
            color: subTextColor, 
            fontSize: 10.6, 
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600
          )),
          const SizedBox(height: 8),
          Row(
            children: [
               Expanded(
                  child: DropdownButtonFormField<String>(
                    dropdownColor: _surfaceColor(context),
                    isExpanded: true,
                    style: TextStyle(color: textColor),
                    decoration: TechTextField.decoration(context),
                    initialValue: _validityType,
                    items: ['Course Validity', 'Lifetime', '1 Year', 'Custom'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis))).toList(),
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
                          return Theme(data: isDark ? ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(primary: _primaryColor, onPrimary: Colors.white, surface: _surfaceColor(context), onSurface: Colors.white),
                              ) : ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
                              ), child: child!);
                        }
                      );
                      if (date != null) setState(() => _selectedExpiryDate = date);
                    },
                    child: InputDecorator(
                      decoration: TechTextField.decoration(context, icon: Icons.calendar_today),
                      child: Text(
                        _selectedExpiryDate == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(_selectedExpiryDate!),
                        style: TextStyle(color: textColor),
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

  Widget _buildUserListTile(Map data, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(3.0),
        border: Border.all(color: _borderColor(context)),
      ),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            child: Icon(Icons.person, color: isDark ? Colors.white70 : Colors.black54)),
        title: Text(data['name'] ?? 'Unknown',
            style: TextStyle(color: textColor)),
        subtitle: Text('${data['email']}\n${data['phone'] ?? ''}',
            style: TextStyle(color: subTextColor, fontSize: 11)),
        isThreeLine: true,
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _neonBlue, foregroundColor: Colors.white),
          onPressed: onTap,
          child: const Text('Select'),
        ),
      ),
    ).animate().slideX(duration: 200.ms, begin: 0.1);
  }

  Widget _buildSectionHeader(String title) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(3.0),
          ),
          margin: const EdgeInsets.only(right: 12),
        ),
        Text(title, style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildActionBtn(String label, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.0),
        gradient: LinearGradient(
          colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.0)),
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
  Widget _buildShimmerTile() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      highlightColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 20, right: 20),
        height: 70,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(3.0),
        ),
      ),
    );
  }

  Widget _buildShimmerBox({required double height}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      highlightColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(3.0),
        ),
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

// --- CUSTOM PILL INDICATOR SYSTEM ---
class PillIndicator extends Decoration {
  final double height;
  final double widthTab1;
  final double widthTab2;
  final Color color;
  final TabController controller;

  const PillIndicator({
    required this.height,
    required this.widthTab1,
    required this.widthTab2,
    required this.color,
    required this.controller,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PillPainter(this, onChanged);
  }
}

class _PillPainter extends BoxPainter {
  final PillIndicator decoration;

  _PillPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final double tabWidth = configuration.size!.width;
    final double tabHeight = configuration.size!.height;
    
    // Interpolate width based on animation value
    final double animValue = decoration.controller.animation!.value;
    final double currentWidth = decoration.widthTab1 + (decoration.widthTab2 - decoration.widthTab1) * animValue;

    // Calculate centered position
    final double xPos = offset.dx + (tabWidth - currentWidth) / 2;
    final double yPos = offset.dy + (tabHeight - decoration.height) / 2;

    final Paint paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..addRRect(RRect.fromLTRBR(
        xPos,
        yPos,
        xPos + currentWidth,
        yPos + decoration.height,
        Radius.circular(decoration.height / 2),
      ));
    
    canvas.drawShadow(path, decoration.color.withValues(alpha: 0.5), 10, true);
    canvas.drawPath(path, paint);
  }
}

