import 'package:flutter/material.dart';

import '../models/assessment_record.dart';
import '../services/health_store.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../util/moment.dart';
import '../widgets/ui.dart';
import '../widgets/risk_bar.dart';
import 'home_screen.dart' show HistoryRow;
import 'results_screen.dart';

/// The full assessment timeline.
///
/// Its value is comparison over time — "is this the third week I have logged
/// this?" — so entries are grouped by month and topped with a short summary
/// rather than presented as a flat list of receipts.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text('Erase history?', style: AppText.h2),
        content: Text(
          'All saved assessments will be deleted from this device. This cannot '
          'be undone.',
          style: AppText.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppText.body.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Erase all',
              style: AppText.body.copyWith(
                color: AppColors.ember,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await HealthStore.instance.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final store = HealthStore.instance;

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => AppTopBar(
                title: 'History',
                leading: AppIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).pop(),
                ),
                actions: [
                  if (store.history.isNotEmpty)
                    AppIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Erase history',
                      color: AppColors.textFaint,
                      onTap: () => _confirmClear(context),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final records = store.history;
                if (records.isEmpty) return const _EmptyHistory();
                return _Timeline(records: records);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.records});

  final List<AssessmentRecord> records;

  /// Groups into month buckets while preserving the newest-first order the
  /// store guarantees.
  Map<String, List<AssessmentRecord>> get _byMonth {
    final grouped = <String, List<AssessmentRecord>>{};
    for (final r in records) {
      final key = Moment.date(
        DateTime(r.takenAt.year, r.takenAt.month),
      ).split(' ').sublist(1).join(' '); // "Sep 2026"
      grouped.putIfAbsent(key, () => []).add(r);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _byMonth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        AppTheme.space16,
        AppTheme.gutter,
        AppTheme.space40,
      ),
      children: [
        _Summary(records: records),
        const SizedBox(height: AppTheme.space32),
        for (final entry in groups.entries) ...[
          SectionHeading(
            entry.key,
            trailing: Text('${entry.value.length}', style: AppText.bodySm),
          ),
          const SizedBox(height: AppTheme.space12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      color: AppColors.divider,
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                  _DismissibleRow(record: entry.value[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space24),
        ],
        Text(
          'Assessments are kept on this device and never uploaded. '
          'The most recent ${HealthStore.maxHistory} are stored.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Swipe to delete a single entry.
///
/// A swipe is the right gesture here: history is personal, deleting one item
/// should be quick, and a confirmation dialog per row would make tidying up
/// feel like an interrogation.
class _DismissibleRow extends StatelessWidget {
  const _DismissibleRow({required this.record});

  final AssessmentRecord record;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.space24),
        color: AppColors.wash(AppColors.ember, 0.12),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.ember,
          size: 20,
        ),
      ),
      onDismissed: (_) {
        HealthStore.instance.deleteRecord(record.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Removed "${record.headline}"')));
      },
      child: HistoryRow(
        record: record,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen.archived(record: record),
          ),
        ),
      ),
    );
  }
}

/// Counts by risk band across everything stored — the one summary that says
/// something a single entry cannot.
class _Summary extends StatelessWidget {
  const _Summary({required this.records});

  final List<AssessmentRecord> records;

  @override
  Widget build(BuildContext context) {
    final counts = <RiskLevel, int>{};
    for (final r in records) {
      final level = RiskLevel.fromString(r.riskLevel);
      counts[level] = (counts[level] ?? 0) + 1;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${records.length}', style: AppText.readout),
              const SizedBox(width: AppTheme.space8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  records.length == 1 ? 'check' : 'checks',
                  style: AppText.bodySm,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Last ${Moment.relative(records.first.takenAt)}',
                  style: AppText.bodySm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          // A proportional bar of the risk mix. It reads at a glance as
          // "mostly green" or "mostly amber", which is the only trend a
          // handful of self-reported checks can honestly support.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (final level in RiskLevel.values)
                    if ((counts[level] ?? 0) > 0)
                      Expanded(
                        flex: counts[level]!,
                        child: Container(color: level.color),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space8,
            children: [
              for (final level in RiskLevel.values)
                if ((counts[level] ?? 0) > 0)
                  StatusPill(
                    '${level.label} ${counts[level]}',
                    color: level.color,
                    filled: false,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 34,
              color: AppColors.textFaint,
            ),
            const SizedBox(height: AppTheme.space20),
            Text('Nothing recorded yet', style: AppText.h2),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Complete an assessment and it will be saved here so you can '
              'look back at what you reported and when.',
              style: AppText.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
