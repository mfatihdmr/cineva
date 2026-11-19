import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class CreditsScreen extends ConsumerStatefulWidget {
  final MediaType type;
  final int mediaId;
  final String mediaTitle;
  final List<CastMember> cast;
  final List<CrewMember> crew;
  const CreditsScreen({
    super.key,
    required this.type,
    required this.mediaId,
    required this.mediaTitle,
    required this.cast,
    required this.crew,
  });

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(List<String> fields, String q) {
    if (q.isEmpty) return true;
    for (final f in fields) {
      if (f.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final q = _query.trim().toLowerCase();
    final cast = [...widget.cast]..sort((a, b) => a.order.compareTo(b.order));
    final filteredCast =
        cast
            .where((c) => _matches([c.name, c.character, c.originalName], q))
            .toList();
    final filteredCrew =
        widget.crew
            .where((c) => _matches([c.name, c.job, c.department], q))
            .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                l.credits,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: l.cancel,
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(104),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: l.t(
                            'İsim veya karakter ara',
                            'Search names or characters',
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    TabBar(
                      tabs: [
                        Tab(text: '${l.cast} (${filteredCast.length})'),
                        Tab(text: '${l.crew} (${filteredCrew.length})'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: TabBarView(
                children: [
                  _CastTab(items: filteredCast, l: l),
                  _CrewTab(items: filteredCrew, l: l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CastTab extends ConsumerWidget {
  final List<CastMember> items;
  final L10n l;
  const _CastTab({required this.items, required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.people_outline_rounded,
        title: l.emptyTitle,
        subtitle: l.emptySub,
      );
    }
    final repo = ref.watch(repoProvider);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.66,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final c = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Nav.person(context, c.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RemoteImage(
                      url: repo.profile(c.profilePath, large: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (c.character.isNotEmpty)
                Text(
                  c.character,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CrewTab extends ConsumerWidget {
  final List<CrewMember> items;
  final L10n l;
  const _CrewTab({required this.items, required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return EmptyView(
        icon: Icons.groups_outlined,
        title: l.emptyTitle,
        subtitle: l.emptySub,
      );
    }
    final repo = ref.watch(repoProvider);
    final byDept = <String, List<CrewMember>>{};
    for (final c in items) {
      final dep = c.department.isEmpty ? l.t('Diğer', 'Other') : c.department;
      byDept.putIfAbsent(dep, () => []).add(c);
    }
    final depts = byDept.keys.toList()..sort();
    final ads = ref.watch(adsEnabledProvider);
    final children = <Widget>[];
    for (var g = 0; g < depts.length; g++) {
      final dep = depts[g];
      children.add(
        ExpansionTile(
          key: PageStorageKey('dep_$dep'),
          initiallyExpanded: g == 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  dep,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${byDept[dep]!.length}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          children: [
            for (final m in byDept[dep]!)
              ListTile(
                leading:
                    m.profilePath == null
                        ? CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          child: Text(
                            m.name.isEmpty ? '?' : m.name.characters.first,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: RemoteImage(
                              url: repo.profile(m.profilePath),
                            ),
                          ),
                        ),
                title: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  m.job,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                  ),
                ),
                onTap: () => Nav.person(context, m.id),
              ),
          ],
        ),
      );
      if (ads && g != depts.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: InlineAdBanner(),
          ),
        );
      }
    }
    children.add(const SizedBox(height: 24));
    return ListView(padding: const EdgeInsets.only(top: 8), children: children);
  }
}
