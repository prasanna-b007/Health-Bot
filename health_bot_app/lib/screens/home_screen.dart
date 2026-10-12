import 'package:flutter/material.dart';

import '../models/assessment_record.dart';
import '../models/health_profile.dart';
import '../motion/pressable.dart';
import '../services/health_store.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../util/moment.dart';
import '../widgets/risk_bar.dart';
import '../widgets/ui.dart';
import 'assessment_form_screen.dart';
import 'history_screen.dart';
import 'hospital_finder_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

/// The home screen.
///
/// It answers one question — "what do I do right now?" — and everything else
/// on it is memory: who you are, what you last reported, and whether that was
/// recent enough to be worth following up.
///
/// The screen re-reads the clock on every build rather than caching a
/// timestamp, so an app left open past midnight greets correctly when it
/// comes back to the foreground.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _store = HealthStore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background may mean hours have passed; the
    // greeting and the "days ago" stamps are stale until we rebuild.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final profile = _store.profile;
            final latest = _store.latest;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space8,
                AppTheme.gutter,
                AppTheme.space40,
              ),
              children: [
                _Header(onProfile: () => _open(const ProfileScreen())),
                const SizedBox(height: AppTheme.space32),

                _Greeting(now: now, profile: profile),
                const SizedBox(height: AppTheme.space24),

                _PrimaryAction(
                  onTap: () {
                    if (!_store.onboarded) {
                      _open(const ProfileScreen(isFirstRun: true));
                    } else {
                      _open(const AssessmentFormScreen());
                    }
                  },
                ),
                const SizedBox(height: AppTheme.space12),

                _EmergencyAction(
                  onTap: () => _open(
                    HospitalFinderScreen(
                      emergencyReason:
                          'You opened emergency help from the home screen.',
                    ),
                  ),
                ),

                // Only offered while the last check is recent enough that
                // "are you still feeling that?" is a real question.
                if (latest != null &&
                    now.difference(latest.takenAt).inDays < 4) ...[
                  const SizedBox(height: AppTheme.space12),
                  _FollowUp(record: latest, now: now),
                ],

                const SizedBox(height: AppTheme.space32),
                _HistorySection(
                  records: _store.history,
                  onViewAll: () => _open(const HistoryScreen()),
                  onOpen: (r) => _open(ResultsScreen.archived(record: r)),
                ),

                const SizedBox(height: AppTheme.space32),
                _ProfileSection(
                  profile: profile,
                  onEdit: () => _open(const ProfileScreen()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

/// Wordmark on the left, the way into the profile on the right.
class _Header extends StatelessWidget {
  const _Header({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.monitor_heart_rounded, size: 19, color: AppColors.signal),
        const SizedBox(width: AppTheme.space8),
        Text(
          'Health-Bot',
          style: AppText.h3.copyWith(color: AppColors.textMuted),
        ),
        const Spacer(),
        AppIconButton(
          icon: Icons.person_outline_rounded,
          tooltip: 'Your profile',
          color: AppColors.textMuted,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.now, required this.profile});

  final DateTime now;
  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final greeting = Moment.greetingFor(now);
    // Without a name the greeting stands alone rather than trailing an
    // awkward comma into nothing.
    final line = profile.hasName ? '$greeting, ${profile.name}' : greeting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line, style: AppText.display),
        const SizedBox(height: AppTheme.space8),
        Text(Moment.noteFor(now), style: AppText.bodyMuted),
      ],
    );
  }
}

/// The one thing this app is for.
///
/// It is the only filled card in the app. Hierarchy here is carried by fill,
/// not by size or decoration — everything else on the page is white, so this
/// is found first without being large.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      fill: AppColors.signal,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space20,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check my symptoms',
                  style: AppText.h1.copyWith(color: AppColors.textInverse),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Guided questions · about 3 minutes',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textInverse.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 22,
            color: AppColors.textInverse,
          ),
        ],
      ),
    );
  }
}

/// Emergency. Always one tap from home, always the same colour, never
/// competing with the primary action for the same visual weight.
class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      child: Row(
        children: [
          const Dot(color: AppColors.ember, size: 8),
          const SizedBox(width: AppTheme.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency help', style: AppText.h2),
                const SizedBox(height: 2),
                Text(
                  'Nearest emergency care, right now',
                  style: AppText.bodySm,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppColors.ember,
          ),
        ],
      ),
    );
  }
}

/// "You reported this two days ago — how is it now?"
class _FollowUp extends StatelessWidget {
  const _FollowUp({required this.record, required this.now});

  final AssessmentRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = now.difference(record.takenAt).inDays;
    final when = days == 0
        ? 'earlier today'
        : days == 1
        ? 'yesterday'
        : '$days days ago';

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_rounded, size: 17, color: AppColors.pulse),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.bodySm,
                children: [
                  const TextSpan(text: 'You checked '),
                  TextSpan(
                    text: record.headline.toLowerCase(),
                    style: AppText.bodySm.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' $when. Has it changed?'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.records,
    required this.onViewAll,
    required this.onOpen,
  });

  final List<AssessmentRecord> records;
  final VoidCallback onViewAll;
  final ValueChanged<AssessmentRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final recent = records.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          'Recent checks',
          trailing: records.length > 3
              ? TextAction(label: 'View all', onTap: onViewAll)
              : null,
        ),
        const SizedBox(height: AppTheme.space12),
        if (recent.isEmpty)
          AppCard(
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.textFaint,
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Text(
                    'Checks you complete are saved here, on this device only.',
                    style: AppText.bodySm,
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      color: AppColors.divider,
                      height: 1,
                      indent: AppTheme.space20,
                      endIndent: AppTheme.space20,
                    ),
                  HistoryRow(record: recent[i], onTap: () => onOpen(recent[i])),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One entry in the timeline. Shared with the full history screen so a row
/// looks identical wherever it appears.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.record, required this.onTap});

  final AssessmentRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final risk = RiskLevel.fromString(record.riskLevel);

    return Pressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space20,
          vertical: AppTheme.space16,
        ),
        child: Row(
          children: [
            // A colour-coded tick standing in for the risk level, so the
            // timeline can be scanned for "when was I worst?" at a glance.
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: risk.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.headline,
                    style: AppText.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(Moment.relative(record.takenAt), style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            StatusPill(risk.label, color: risk.color),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.profile, required this.onEdit});

  final HealthProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final filled = profile.filledCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Your profile'),
        const SizedBox(height: AppTheme.space12),
        AppCard(
          onTap: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.isConfigured
                          ? 'Saved on this device'
                          : 'Skip the repeat questions',
                      style: AppText.h3,
                    ),
                  ),
                  Text(
                    '$filled of ${HealthProfile.fieldCount}',
                    style: AppText.bodySm,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textFaint,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space12),
              ProgressTrack(value: filled / HealthProfile.fieldCount),
              const SizedBox(height: AppTheme.space12),
              Text(
                profile.isConfigured
                    ? 'Prefills your next check and sharpens your risk score.'
                    : 'Add your age and history once — the next check starts '
                          'prefilled.',
                style: AppText.bodySm,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
