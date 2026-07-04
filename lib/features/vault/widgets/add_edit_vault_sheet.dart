import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../data/models/vault_entry.dart';
import '../../../widgets/common_widgets.dart';

class AddEditVaultSheet extends StatefulWidget {
  final AppState appState;
  final VaultEntry? entry;
  const AddEditVaultSheet({super.key, required this.appState, this.entry});

  @override
  State<AddEditVaultSheet> createState() => _AddEditVaultSheetState();
}

class _AddEditVaultSheetState extends State<AddEditVaultSheet> {
  final _titleCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  VaultItemCategory _category = VaultItemCategory.login;
  bool _obscure = true;
  int _strength = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _titleCtrl.text = e.title;
      _userCtrl.text = e.username;
      _websiteCtrl.text = e.website ?? '';
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _userCtrl.dispose();
    _secretCtrl.dispose();
    _websiteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_secretCtrl.text.isEmpty && widget.entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secret / password is required.'),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.entry == null) {
        await widget.appState.addVaultEntry(VaultEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleCtrl.text.trim(),
          username: _userCtrl.text.trim(),
          rawSecret: _secretCtrl.text,
          category: _category,
          website: _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
        ));
      } else {
        final updated = widget.entry!
          ..title = _titleCtrl.text.trim()
          ..username = _userCtrl.text.trim()
          ..rawSecret = _secretCtrl.text
          ..category = _category
          ..website = _websiteCtrl.text.trim().isEmpty
              ? null
              : _websiteCtrl.text.trim()
          ..notes = _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim();
        await widget.appState.updateVaultEntry(updated);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _generatePassword() {
    final pwd = CryptoEngine.generateStrongPassword();
    _secretCtrl.text = pwd;
    setState(() {
      _strength = CryptoEngine.analyzePasswordStrength(pwd);
      _obscure = false;
    });
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: kGlassBorder)),
            ),
            const SizedBox(height: 20),
            Center(
              child: NeonText(
                widget.entry == null ? 'ADD VAULT ITEM' : 'EDIT ITEM',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            const Text('CATEGORY',
                style: TextStyle(
                    color: kTextMuted, fontSize: 9, letterSpacing: 2)),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: VaultItemCategory.values.map((c) {
                  final isSelected = _category == c;
                  final grad = c.gradient;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: isSelected
                            ? LinearGradient(colors: grad)
                            : null,
                        border: Border.all(
                            color: isSelected
                                ? grad.first
                                : kGlassBorder2),
                        color: isSelected ? null : kSurface2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon,
                              color:
                                  isSelected ? kText : kTextDim,
                              size: 14),
                          const SizedBox(width: 6),
                          Text(c.label,
                              style: TextStyle(
                                  color: isSelected
                                      ? kText
                                      : kTextDim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            CyberTextField(
                controller: _titleCtrl,
                label: 'Title *',
                prefixIcon: Icons.label_rounded,
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 10),
            CyberTextField(
                controller: _userCtrl,
                label: 'Username / Email',
                prefixIcon: Icons.person_rounded),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGlassBorder),
                gradient: const LinearGradient(
                    colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
              ),
              child: TextField(
                controller: _secretCtrl,
                obscureText: _obscure,
                onChanged: (v) => setState(() =>
                    _strength =
                        CryptoEngine.analyzePasswordStrength(v)),
                style: const TextStyle(color: kText, fontSize: 15),
                decoration: InputDecoration(
                  labelText:
                      _category == VaultItemCategory.secureNote
                          ? 'Secure Note *'
                          : 'Password / Secret *',
                  labelStyle: const TextStyle(
                      color: kTextDim,
                      fontSize: 12,
                      letterSpacing: 1),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: kNeon,
                      size: 20),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kTextDim,
                            size: 20),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                      if (_category ==
                          VaultItemCategory.login)
                        IconButton(
                          icon: const Icon(
                              Icons.auto_fix_high_rounded,
                              color: kNeon,
                              size: 20),
                          onPressed: _generatePassword,
                          tooltip: 'Generate password',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_category == VaultItemCategory.login &&
                _secretCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(CryptoEngine.strengthLabel(_strength),
                      style: TextStyle(
                          color: CryptoEngine.strengthColor(_strength),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  Text('$_strength / 100',
                      style: const TextStyle(
                          color: kTextMuted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _strength / 100,
                  backgroundColor: kSurface2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      CryptoEngine.strengthColor(_strength)),
                  minHeight: 4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            CyberTextField(
                controller: _websiteCtrl,
                label: 'Website / URL',
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url),
            const SizedBox(height: 10),
            CyberTextField(
                controller: _notesCtrl,
                label: 'Notes',
                prefixIcon: Icons.note_outlined,
                maxLines: 3),
            const SizedBox(height: 24),
            CyberButton(
              label: _saving
                  ? 'SAVING...'
                  : widget.entry == null
                      ? 'ADD TO VAULT'
                      : 'SAVE CHANGES',
              icon: Icons.save_rounded,
              onPressed: _saving ? null : _save,
              width: double.infinity,
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
}
