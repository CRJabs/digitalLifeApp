import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../core/user_profile_service.dart';
import 'login_screen.dart';

/// Settings / User Profile screen (tab 3).
/// Shows the user's profile info with an "Edit Information" toggle that
/// reveals editable form fields in-place.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isEditing = false;

  static const _validDepartments = {
    'CAHS',
    'CASE',
    'CBA',
    'CCJ',
    'CETAFA',
    'CHMTN',
    'COL',
    'COM',
    'COP',
    'CPTOT',
    'GSPS',
    'UBGS',
    'UBJHS',
    'VDTJHS',
    'VDTSHS',
  };

  static const _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _programCtrl;
  String? _selectedDept;
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    final profile = UserProfileService();
    _nameCtrl = TextEditingController(text: profile.name);
    _emailCtrl = TextEditingController(text: profile.email);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _programCtrl = TextEditingController(text: profile.program);

    final profileDept = profile.department.trim().toUpperCase();
    _selectedDept = _validDepartments.contains(profileDept)
        ? profileDept
        : _validDepartments.first;

    // Match stored year level to dropdown values (case-insensitive)
    final storedYear = profile.yearLevel.trim();
    _selectedYear = _yearLevels.contains(storedYear) ? storedYear : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _programCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  Future<void> _saveChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a year level.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    try {
      await UserProfileService().updateProfile(
        uid: uid,
        newName: _nameCtrl.text.trim(),
        newEmail: _emailCtrl.text.trim(),
        newPhone: _phoneCtrl.text.trim(),
        newDept: _selectedDept ?? 'CAHS',
        newProgram: _programCtrl.text.trim(),
        newYearLevel: _selectedYear!,
      );
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Changes saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      UserProfileService().clearProfile();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFeedbackModal() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to send feedback.'),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedCategory = 'General';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Send Feedback',
                              style: TextStyle(
                                fontFamily: 'Figtree',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.oceanicNoir,
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: AppColors.nocturnalExpedition.withAlpha(
                                120,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          'Category',
                          selectedCategory,
                          const [
                            'General',
                            'Events',
                            'SSG Administration',
                            'Application',
                          ],
                          (val) {
                            setModalState(() {
                              selectedCategory = val;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildLabeledField(
                          'Title',
                          titleCtrl,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _buildLabeledField(
                          'Feedback',
                          bodyCtrl,
                          maxLines: 4,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter the feedback body';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate())
                                      return;
                                    setModalState(() {
                                      isSubmitting = true;
                                    });

                                    try {
                                      await Supabase.instance.client
                                          .from('feedback')
                                          .insert({
                                            'user_id': uid,
                                            'category': selectedCategory,
                                            'title': titleCtrl.text.trim(),
                                            'body': bodyCtrl.text.trim(),
                                          });

                                      if (!context.mounted) return;
                                      Navigator.pop(context); // close dialog

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Feedback submitted successfully! Thank you.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setModalState(() {
                                        isSubmitting = false;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to submit feedback: $e',
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Submit Feedback'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ListenableBuilder(
      listenable: UserProfileService(),
      builder: (context, _) {
        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(20, mq.padding.top + 20, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Settings',
                            style: AppTextStyles.welcomeLabel,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'User Profile',
                            style: AppTextStyles.welcomeName,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/lifeColored.png',
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Profile card ──────────────────────────────────────
                      _buildProfileCard(),
                      const SizedBox(height: 20),

                      // ── Edit form (visible only when editing) ─────────────
                      if (_isEditing)
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLabeledField(
                                'Full Name',
                                _nameCtrl,
                                validator: (v) {
                                  if (v == null || v.trim().length < 2) {
                                    return 'Enter your name (at least 2 characters)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildLabeledField(
                                'Email',
                                _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                readOnly: true,
                              ),
                              const SizedBox(height: 14),
                              _buildLabeledField(
                                'Phone Number',
                                _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter your phone number';
                                  }
                                  final digits = v.replaceAll(
                                    RegExp(r'[\s\-+]'),
                                    '',
                                  );
                                  if (!RegExp(r'^\d+$').hasMatch(digits)) {
                                    return 'Digits and standard symbols only';
                                  }
                                  if (digits.length < 7) {
                                    return 'Must be at least 7 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdownField(
                                'Department',
                                _selectedDept,
                                null, // uses _validDepartments by default
                                (val) => setState(() => _selectedDept = val),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildLabeledField(
                                      'Program',
                                      _programCtrl,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Enter program';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildDropdownField(
                                      'Year Level',
                                      _selectedYear,
                                      const [
                                        '1st Year',
                                        '2nd Year',
                                        '3rd Year',
                                        '4th Year',
                                        '5th Year',
                                      ],
                                      (val) =>
                                          setState(() => _selectedYear = val),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Save Changes button
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _saveChanges,
                                  child: const Text('Save Changes'),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ),
                        )
                      else ...[
                        // ── Edit Information button ────────────────────────
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _toggleEdit,
                            child: const Text('Edit Information'),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Send Feedback button ────────────────────────────
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _showFeedbackModal,
                          child: const Text('Send Feedback'),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Sign Out button (always visible) ──────────────────
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontFamily: 'Figtree',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              if (!_isEditing) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 155),
                  child: Image.asset(
                    'assets/credits.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final profile = UserProfileService();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.mysticMint, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar — UB circular logo
          ClipOval(child: _buildAvatar(profile.department)),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: AppTextStyles.activityTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: AppTextStyles.activitySubtitle.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      profile.phone,
                      style: AppTextStyles.activitySubtitle.copyWith(
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${profile.department}  |  ${profile.program}-${profile.yearLevel}',
                      style: AppTextStyles.activitySubtitle.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Labeled text field ────────────────────────────────────────────────────
  Widget _buildLabeledField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    FormFieldValidator<String>? validator,
    bool readOnly = false,
    int? maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.inputHint.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: maxLines != null && maxLines > 1
              ? TextInputType.multiline
              : keyboardType,
          readOnly: readOnly,
          validator: validator,
          maxLines: maxLines,
          style: AppTextStyles.inputHint.copyWith(
            color: readOnly
                ? AppColors.nocturnalExpedition.withAlpha(160)
                : AppColors.oceanicNoir,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.mysticMint),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.mysticMint),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: readOnly
                    ? AppColors.mysticMint
                    : AppColors.nocturnalExpedition,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: readOnly ? AppColors.arcticPowder : Colors.white,
            suffixIcon: readOnly
                ? Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.nocturnalExpedition.withAlpha(120),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? currentValue,
    List<String>? items,
    ValueChanged<String?> onChanged,
  ) {
    final options = items ?? _validDepartments.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.inputHint.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: currentValue,
          isExpanded: true,
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(
                opt,
                style: AppTextStyles.inputHint.copyWith(
                  color: AppColors.oceanicNoir,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
          style: AppTextStyles.inputHint.copyWith(color: AppColors.oceanicNoir),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.mysticMint),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.mysticMint),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.nocturnalExpedition,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String dept) {
    final cleanDept = dept.trim().toUpperCase();
    if (_validDepartments.contains(cleanDept)) {
      final url =
          'https://fsczvbsfhuenrzwxtgyq.supabase.co/storage/v1/object/public/department-logos/${cleanDept.toLowerCase()}.png';
      return Image.network(
        url,
        width: 62,
        height: 62,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/ubcso.png',
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 62,
            height: 62,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.oceanicNoir,
                ),
              ),
            ),
          );
        },
      );
    }
    return Image.asset(
      'assets/ubcso.png',
      width: 62,
      height: 62,
      fit: BoxFit.cover,
    );
  }
}
