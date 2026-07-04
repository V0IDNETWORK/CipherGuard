import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../data/models/vault_entry.dart';
import '../../../widgets/common_widgets.dart';
import 'add_edit_vault_sheet.dart';

class VaultDetailSheet extends StatefulWidget {
  final VaultEntry entry;
  final AppState appState;
  const VaultDetailSheet(
      {super.key, required this.entry, required this.appState});

  @override
  State<VaultDetailSheet> createState() => _VaultDetailSheetState();
}

class _VaultDetailSheetState extends State<VaultDetailSheet> {
  bool _revealed = false;
  String _revealedSecret = '';
  bool _copying = false;
  bool _revealing = false;

  Future<void> _reveal() async {
    if (_revealed) {
      setState(() {
        _revealed = false;
        _revealedSecret = '';
      });
      return;
    }
    setState(() => _revealing = true);
    try {
      final secret =
          await widget.appState.revealSecret(widget.entry);
      if (mounted) {
        setState(() {
          _revealed = true;
          _revealedSecret = secret;
          _revealing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _revealing = false);
    }
  }

  Future<void> _copy() async {
    setState(() => _copying = true);
    try {
      final secret = _revealed
          ? _revealedSecret
          : await widget.appState.revealSecret(widget.entry);
      await Clipboard.setData(ClipboardData(text: secret));
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _copying = false);
      Future.delayed(const Duration(seconds: 30),
          () => Clipboard.setData(const ClipboardData(text: '')));
    } catch (_) {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final grad = e.category.gradient;
    final maxH = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            28,
            28,
            28,
            MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: kGlassBorder)),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: grad),
                boxShadow: [
                  BoxShadow(
                      color: grad.first.withValues(alpha: 0.5),
                      blurRadius: 20)
                ],
              ),
              child:
                  Icon(e.category.icon, color: kText, size: 30),
            ),
            const SizedBox(height: 16),
            Text(e.title,
                style: const TextStyle(
                    color: kText,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
            Text(e.category.label,
                style: TextStyle(
                    color: grad.first,
                    fontSize: 12,
                    letterSpacing: 2)),
            const SizedBox(height: 24),
            if (e.username.isNotEmpty)
              _infoRow('Username / Email', e.username,
                  Icons.person_rounded),
            if (e.website != null)
              _infoRow('Website', e.website!, Icons.link_rounded),
            _secretRow(e),
            if (e.notes != null)
              _infoRow('Notes', e.notes!, Icons.note_rounded),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    label: _copying ? 'COPIED!' : 'COPY SECRET',
                    icon: _copying
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    onPressed: _copy,
                    gradient: _copying
                        ? AppColors.gradientSuccess
                        : AppColors.gradientPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                _iconActionButton(
                  icon: e.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: kWarning,
                  active: e.isFavorite,
                  onTap: () => setState(() {
                    widget.appState.toggleFavorite(e.id);
                  }),
                ),
                const SizedBox(width: 10),
                _iconActionButton(
                  icon: Icons.edit_rounded,
                  color: kNeon,
                  active: false,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => AddEditVaultSheet(
                          appState: widget.appState, entry: e),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _iconActionButton(
                  icon: Icons.delete_rounded,
                  color: kError,
                  active: false,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: active ? 0.15 : 0.08),
          border: Border.all(
              color: color.withValues(alpha: active ? 0.5 : 0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: kNeon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 10,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(value,
                      style:
                          const TextStyle(color: kText, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secretRow(VaultEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: kNeon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Password / Secret',
                      style: TextStyle(
                          color: kTextMuted,
                          fontSize: 10,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(
                    _revealing
                        ? 'Decrypting...'
                        : _revealed
                            ? _revealedSecret
                            : '••••••••••••••',
                    style: TextStyle(
                        color: _revealing ? kTextMuted : kText,
                        fontSize: 13,
                        fontFamily: _revealed ? null : 'monospace'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                  _revealing
                      ? Icons.hourglass_top_rounded
                      : _revealed
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                  color: kNeon,
                  size: 20),
              onPressed: _revealing ? null : _reveal,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kGlassBorder)),
        title: const Text('Delete Item',
            style: TextStyle(color: kText)),
        content: Text(
            'Permanently delete "${widget.entry.title}"? This cannot be undone.',
            style: const TextStyle(color: kTextDim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL',
                  style: TextStyle(color: kTextDim))),
          TextButton(
            onPressed: () {
              widget.appState
                  .deleteVaultEntry(widget.entry.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DELETE',
                style: TextStyle(color: kError)),
          ),
        ],
      ),
    );
  }
}
