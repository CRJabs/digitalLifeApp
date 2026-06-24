import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    'CAHS', 'CASE', 'CBA', 'CCJ', 'CETAFA',
    'CHMTN', 'COL', 'COM', 'COP', 'CPTOT',
    'GSPS', 'UBGS', 'UBJHS', 'VDTJHS', 'VDTSHS',
  };

  static const _yearLevels = [
    '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year',
  ];

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
    _nameCtrl    = TextEditingController(text: profile.name);
    _emailCtrl   = TextEditingController(text: profile.email);
    _phoneCtrl   = TextEditingController(text: profile.phone);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved.')),
    );
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
                          Text('Account Settings', style: AppTextStyles.welcomeLabel),
                          const SizedBox(height: 2),
                          Text('User Profile', style: AppTextStyles.welcomeName),
                        ],
                      ),
                    ),
                    Image.asset('assets/lifeColored.png', height: 38, fit: BoxFit.contain),
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
                      if (_isEditing) ...[
                        _buildLabeledField('Full Name', _nameCtrl),
                        const SizedBox(height: 14),
                        _buildLabeledField('Email', _emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 14),
                        _buildLabeledField('Phone Number', _phoneCtrl,
                            keyboardType: TextInputType.phone),
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
                              child: _buildLabeledField('Program', _programCtrl),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildDropdownField(
                                'Year Level',
                                _selectedYear,
                                const ['1st Year','2nd Year','3rd Year','4th Year','5th Year'],
                                (val) => setState(() => _selectedYear = val),
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
                      ] else ...[
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

                      // ── Sign Out button (always visible) ──────────────────
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _signOut,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
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
          ClipOval(
            child: _buildAvatar(profile.department),
          ),
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
                      style:
                          AppTextStyles.activitySubtitle.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${profile.department}  |  ${profile.program}-${profile.yearLevel}',
                      style:
                          AppTextStyles.activitySubtitle.copyWith(fontSize: 11),
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
          keyboardType: keyboardType,
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
                style: AppTextStyles.inputHint.copyWith(color: AppColors.oceanicNoir),
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
      final url = 'https://fsczvbsfhuenrzwxtgyq.supabase.co/storage/v1/object/public/department-logos/${cleanDept.toLowerCase()}.png';
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
