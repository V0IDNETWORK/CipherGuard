import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../widgets/common_widgets.dart';

class MasterPasswordSetupSheet extends StatefulWidget {
  final AppState appState;
  const MasterPasswordSetupSheet({super.key, required this.appState});

  @override
  State<MasterPasswordSetupSheet> createState() =>
      _MasterPasswordSetupSheetState();
}

class _MasterPasswordSetupSheetState extends State<MasterPasswordSetupSheet> {
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  int _strength = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _pwCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Enter a password.');
      return;
    }
    if (pw.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.appState.setupMasterPassword(pw);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 28,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: kGlassBorder)),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: AppColors.gradientPrimary),
                boxShadow: [
                  BoxShadow(
                      color: kPrimary.withValues(alpha: 0.5), blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: kText, size: 28),
            ),
            const SizedBox(height: 16),
            const NeonText('MASTER PASSWORD',
                fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3),
            const SizedBox(height: 4),
            const Text('Set a strong password to protect your vault',
                style: TextStyle(color: kTextDim, fontSize: 12)),
            const SizedBox(height: 24),
            _buildPasswordField(),
            const SizedBox(height: 12),
            if (_pwCtrl.text.isNotEmpty) ...[
              _buildStrengthBar(),
              const SizedBox(height: 12),
            ],
            _buildConfirmField(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kError.withValues(alpha: 0.08),
                  border: Border.all(color: kError.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: kError, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: kError, fontSize: 12))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildRequirements(),
            const SizedBox(height: 24),
            CyberButton(
              label: _saving ? 'SAVING...' : 'SET MASTER PASSWORD',
              icon: Icons.lock_rounded,
              onPressed: _saving ? null : _save,
              width: double.infinity,
              height: 54,
            ),
            const SizedBox(height: 12),
            CyberButton(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(context),
              outlined: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGlassBorder),
        gradient:
            const LinearGradient(colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: _pwCtrl,
        obscureText: _obscure1,
        onChanged: (v) =>
            setState(() => _strength = CryptoEngine.analyzePasswordStrength(v)),
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'New Password',
          labelStyle:
              const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: kNeon, size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                    _obscure1
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: kTextDim,
                    size: 20),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
              IconButton(
                icon: const Icon(Icons.auto_fix_high_rounded,
                    color: kNeon, size: 20),
                onPressed: () {
                  final pwd = CryptoEngine.generateStrongPassword();
                  _pwCtrl.text = pwd;
                  _confirmCtrl.text = pwd;
                  setState(() {
                    _strength = CryptoEngine.analyzePasswordStrength(pwd);
                    _obscure1 = false;
                    _obscure2 = false;
                  });
                },
                tooltip: 'Generate strong password',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthBar() {
    final color = CryptoEngine.strengthColor(_strength);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(CryptoEngine.strengthLabel(_strength),
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            Text('$_strength / 100',
                style:
                    const TextStyle(color: kTextMuted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _strength / 100,
            backgroundColor: kSurface2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGlassBorder),
        gradient:
            const LinearGradient(colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: _confirmCtrl,
        obscureText: _obscure2,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _save(),
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          labelStyle:
              const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: const Icon(Icons.lock_reset_rounded,
              color: kNeon, size: 20),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                    _obscure2
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: kTextDim,
                    size: 20),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
              if (_confirmCtrl.text.isNotEmpty)
                Icon(
                  _confirmCtrl.text == _pwCtrl.text
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: _confirmCtrl.text == _pwCtrl.text
                      ? kSuccess
                      : kError,
                  size: 20,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirements() {
    final pw = _pwCtrl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REQUIREMENTS',
            style:
                TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 3)),
        const SizedBox(height: 10),
        _req('At least 8 characters', pw.length >= 8),
        _req('Uppercase letter', pw.contains(RegExp(r'[A-Z]'))),
        _req('Lowercase letter', pw.contains(RegExp(r'[a-z]'))),
        _req('Number', pw.contains(RegExp(r'[0-9]'))),
        _req('Special character',
            pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
      ],
    );
  }

  Widget _req(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: met ? kSuccess : kTextMuted, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: met ? kSuccess : kTextMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
