import 'package:flutter/material.dart';
import '../../../core/config/constants.dart';
import '../../../core/services/app_state.dart';
import '../../../core/crypto/crypto_engine.dart';
import '../../../data/models/vault_entry.dart';
import '../../../widgets/common_widgets.dart';
import '../widgets/add_edit_vault_sheet.dart';
import '../widgets/vault_detail_sheet.dart';

class VaultPage extends StatefulWidget {
  final AppState appState;
  const VaultPage({super.key, required this.appState});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: as,
        builder: (_, __) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(as)),
            SliverToBoxAdapter(child: _buildSearch(as)),
            SliverToBoxAdapter(child: _buildCategoryFilter(as)),
            as.filteredVault.isEmpty
                ? SliverToBoxAdapter(child: _buildEmpty())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) =>
                          _buildVaultItem(as.filteredVault[i], as),
                      childCount: as.filteredVault.length,
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _openAddEntry(context, as),
          backgroundColor: kPrimary,
          foregroundColor: kText,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ADD ITEM',
              style: TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _buildHeader(AppState as) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${as.vault.length} ITEMS',
              style: const TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 4),
          const NeonText('Vault',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              gradient: true),
        ],
      ),
    );
  }

  Widget _buildSearch(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGlassBorder),
          color: kSurface2,
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) {
            as.setSearch(v);
            setState(() {});
          },
          style: const TextStyle(color: kText),
          decoration: InputDecoration(
            hintText: 'Search vault...',
            hintStyle: const TextStyle(color: kTextMuted),
            prefixIcon:
                const Icon(Icons.search_rounded, color: kNeon),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: kTextDim),
                    onPressed: () {
                      _searchCtrl.clear();
                      as.setSearch('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(AppState as) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _filterChip('ALL', null, as),
          ...VaultItemCategory.values
              .map((c) => _filterChip(c.label, c, as)),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label, VaultItemCategory? cat, AppState as) {
    final isActive = as.filterCategory == cat;
    return GestureDetector(
      onTap: () => as.setFilterCategory(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:
            const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isActive
              ? const LinearGradient(
                  colors: AppColors.gradientPrimary)
              : null,
          border: Border.all(
              color: isActive ? kPrimary : kGlassBorder2),
          color: isActive ? null : kSurface2,
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isActive ? kText : kTextDim,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.key_off_rounded,
              size: 64,
              color: kTextMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('Your vault is empty',
              style: TextStyle(color: kTextDim, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap + to add your first secure item',
              style: TextStyle(color: kTextMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVaultItem(VaultEntry entry, AppState as) {
    final grad = entry.category.gradient;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: grad.first.withValues(alpha: 0.2),
        onTap: () => _openDetail(context, entry, as),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(colors: grad),
                boxShadow: [
                  BoxShadow(
                      color: grad.first.withValues(alpha: 0.4),
                      blurRadius: 12)
                ],
              ),
              child:
                  Icon(entry.category.icon, color: kText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isFavorite)
                        const Icon(Icons.star_rounded,
                            color: kWarning, size: 14),
                    ],
                  ),
                  if (entry.username.isNotEmpty)
                    Text(entry.username,
                        style: const TextStyle(
                            color: kTextDim, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  if (entry.category ==
                      VaultItemCategory.login) ...[
                    const SizedBox(height: 4),
                    _strengthPill(entry.strengthScore),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(entry.category.label,
                  style: TextStyle(
                      color: grad.first,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strengthPill(int score) {
    final color = CryptoEngine.strengthColor(score);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        CryptoEngine.strengthLabel(score),
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1),
      ),
    );
  }

  void _openAddEntry(BuildContext context, AppState as) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddEditVaultSheet(appState: as),
    );
  }

  void _openDetail(
      BuildContext context, VaultEntry entry, AppState as) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          VaultDetailSheet(entry: entry, appState: as),
    );
  }
}
