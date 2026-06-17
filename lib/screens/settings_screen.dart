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

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _programCtrl;
  late final TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    final profile = UserProfileService();
    _nameCtrl = TextEditingController(text: profile.name);
    _emailCtrl = TextEditingController(text: profile.email);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _deptCtrl = TextEditingController(text: profile.department);
    _programCtrl = TextEditingController(text: profile.program);
    _yearCtrl = TextEditingController(text: profile.yearLevel);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _deptCtrl.dispose();
    _programCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() => setState(() => _isEditing = !_isEditing);

  Future<void> _saveChanges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await UserProfileService().updateProfile(
      uid: uid,
      newName: _nameCtrl.text.trim(),
      newEmail: _emailCtrl.text.trim(),
      newPhone: _phoneCtrl.text.trim(),
      newDept: _deptCtrl.text.trim(),
      newProgram: _programCtrl.text.trim(),
      newYearLevel: _yearCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Changes saved.')),
    );
  }

  void _signOut() async {
    UserProfileService().clearProfile();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
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
            children: [
              SizedBox(height: mq.padding.top),

              // ── Page title ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'User Profile',
                  style: AppTextStyles.welcomeName.copyWith(fontSize: 18),
                ),
              ),

              // ── Scrollable body ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                        _buildLabeledField('Department', _deptCtrl),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildLabeledField('Program', _programCtrl),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildLabeledField('Year Level', _yearCtrl,
                                  keyboardType: TextInputType.number),
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
                              fontFamily: 'HostGrotesk',
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
            child: Image.asset(
              'assets/ubcso.png',
              width: 62,
              height: 62,
              fit: BoxFit.cover,
            ),
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
}
