import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ads.dart';
import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

final _calendarMonthOffsetProvider = StateProvider<int>((ref) => 0);

const _monthsTr = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthLabel(DateTime d, L10n l) =>
    '${(l.isTr ? _monthsTr : _monthsEn)[d.month - 1]} ${d.year}';

String _dayLabel(String iso, L10n l) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${(l.isTr ? _monthsTr : _monthsEn)[d.month - 1]} ${d.year}';
}

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final offset = ref.watch(_calendarMonthOffsetProvider);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month + offset, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final range = (_iso(month), _iso(lastDay));
    final data = ref.watch(releaseCalendarProvider(range));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.calendar),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () =>
                      ref.read(_calendarMonthOffsetProvider.notifier).state = offset - 1,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: l.from,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel(month, l),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(_calendarMonthOffsetProvider.notifier).state = offset + 1,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: l.to,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: data.when(
            loading: () => const _CalendarShimmer(),
            error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(releaseCalendarProvider(range)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyView(
                  icon: Icons.event_busy_rounded,
                  title: l.emptyTitle,
                  subtitle: l.noResultsSub,
                );
              }
              final byDay = <String, List<MediaSummary>>{};
              for (final m in items) {
                final day = m.releaseDate;
                if (day == null || day.length < 10) continue;
                byDay.putIfAbsent(day.substring(0, 10), () => []).add(m);
              }
              final days = byDay.keys.toList()..sort();
              if (days.isEmpty) {
                return MediaCarousel(title: _monthLabel(month, l), items: items);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: days.length,
                itemBuilder: (_, i) => MediaCarousel(
                  title: _dayLabel(days[i], l),
                  items: byDay[days[i]]!,
                ),
              );
            },
          )),
          if (ref.watch(adsEnabledProvider))
            const SafeArea(top: false, child: AnchoredBanner()),
        ],
      ),
    );
  }
}

class _CalendarShimmer extends StatelessWidget {
  const _CalendarShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ShimmerBox(width: 140, height: 18),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ShimmerBox(width: 118, height: 200, radius: BorderRadius.all(Radius.circular(14))),
                SizedBox(width: 11),
                ShimmerBox(width: 118, height: 200, radius: BorderRadius.all(Radius.circular(14))),
                SizedBox(width: 11),
                ShimmerBox(width: 118, height: 200, radius: BorderRadius.all(Radius.circular(14))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
