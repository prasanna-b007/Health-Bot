import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';
import '../motion/pressable.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../util/emergency_number.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';

/// Nearby medical facilities.
///
/// This screen is reached in two very different moods: browsing after a
/// moderate result, and needing an emergency room now. When [emergencyReason]
/// is set the whole screen changes register — the ambient light turns ember, a
/// call-emergency-services action sits above everything, and the list leads
/// with facilities that have an emergency department.
class HospitalFinderScreen extends StatefulWidget {
  const HospitalFinderScreen({
    super.key,
    this.emergencyReason,
    this.specialistName,
  });

  final String? emergencyReason;
  final String? specialistName;

  @override
  State<HospitalFinderScreen> createState() => _HospitalFinderScreenState();
}

class _HospitalFinderScreenState extends State<HospitalFinderScreen> {
  final LocationService _location = LocationService();
  final HospitalService _hospitalService = HospitalService();

  bool _isLoading = true;
  bool _permissionDenied = false;
  String? _errorMessage;
  List<HospitalData> _hospitals = [];

  bool get _isEmergency => widget.emergencyReason != null;
  Color get _accent => _isEmergency ? AppColors.ember : AppColors.signal;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _permissionDenied = false;
    });

    try {
      final position = await _location.getCurrentLocation();
      final hospitals = await _hospitalService.getNearbyHospitals(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        // In an emergency, a slightly further hospital with an emergency
        // department beats a nearer clinic that cannot admit you.
        _hospitals = _isEmergency ? _emergencyFirst(hospitals) : hospitals;
        _isLoading = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      // A denied permission needs a different prompt from a failed lookup, so
      // it drives the dedicated permission view rather than a raw message.
      setState(() {
        _permissionDenied =
            e.kind == LocationErrorKind.denied ||
            e.kind == LocationErrorKind.deniedForever;
        _errorMessage = _permissionDenied ? null : e.message;
        _isLoading = false;
      });
    } on HospitalServiceException catch (e) {
      if (!mounted) return;
      debugPrint('$e');
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      // Unexpected: log the detail, show the user something actionable
      // instead of a raw exception string.
      debugPrint('Hospital finder failed: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Something went wrong finding hospitals. Please try again.';
        _isLoading = false;
      });
    }
  }

  static List<HospitalData> _emergencyFirst(List<HospitalData> all) {
    final sorted = [...all];
    sorted.sort((a, b) {
      if (a.hasEmergency != b.hasEmergency) return a.hasEmergency ? -1 : 1;
      return a.rawDistance.compareTo(b.rawDistance);
    });
    return sorted;
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  /// The number this device should dial. Resolved once, so the button label
  /// and the actual dial can never disagree.
  late final EmergencyNumber _emergency = EmergencyNumber.resolve();

  Future<void> _callEmergencyServices() async {
    // Kept as a direct dial rather than an in-app confirmation step: the
    // system dialler is itself the confirmation, and adding one more tap here
    // costs seconds in the only situation where seconds matter.
    final launched = await launchUrl(Uri.parse('tel:${_emergency.number}'));
    if (!launched && mounted) {
      _showError(
        'Could not start the call. Please dial your local '
        'emergency number.',
      );
    }
  }

  Future<void> _launch(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) {
      _showError('Could not open that link.');
      return;
    }
    // A facility with no usable coordinates would otherwise send the user to
    // the middle of the Atlantic.
    if (urlString.contains('destination=0.0,0.0') ||
        urlString.contains('destination=0,0')) {
      _showError('Location data for this hospital is unavailable.');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showError('Could not open that link.');
    } catch (e) {
      debugPrint('launchUrl failed: $e');
      _showError('Could not open that link.');
    }
  }

  void _directions(HospitalData h) => _launch(
    'https://www.google.com/maps/dir/?api=1&destination=${h.latitude},${h.longitude}',
  );

  void _call(HospitalData h) => _launch('tel:${h.phone}');

  void _website(HospitalData h) {
    var url = h.website ?? '';
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    _launch(url);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  void _showAll() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
          boxShadow: AppTheme.floatShadow,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppTheme.space12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.strokeStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            Text(
              'All ${_hospitals.length} nearby facilities',
              style: AppText.h3,
            ),
            const SizedBox(height: AppTheme.space16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  0,
                  AppTheme.gutter,
                  AppTheme.space32,
                ),
                itemCount: _hospitals.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.space12),
                itemBuilder: (context, i) => _HospitalCard(
                  hospital: _hospitals[i],
                  accent: _accent,
                  onDirections: () => _directions(_hospitals[i]),
                  onCall: () => _call(_hospitals[i]),
                  onWebsite: () => _website(_hospitals[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: AppTopBar(
              title: _isEmergency ? 'Emergency care' : 'Nearby care',
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).pop(),
              ),
              actions: [
                if (!_isLoading)
                  AppIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Search again',
                    onTap: _fetch,
                  ),
              ],
            ),
          ),
          if (_isEmergency)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space16,
                AppTheme.gutter,
                0,
              ),
              child: _EmergencyHeader(
                reason: widget.emergencyReason!,
                emergency: _emergency,
                onCall: _callEmergencyServices,
              ),
            )
          else if (!_isLoading && _hospitals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                AppTheme.space16,
                AppTheme.gutter,
                0,
              ),
              child: _ResultsHeader(
                count: _hospitals.length,
                specialistName: widget.specialistName,
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return _Searching(accent: _accent);
    if (_permissionDenied) {
      return _StateMessage(
        icon: Icons.location_disabled_rounded,
        color: AppColors.riskModerate,
        title: 'Location access is off',
        body:
            'Health-Bot needs your location to find hospitals near you. '
            'It is used for this search only and is not stored.',
        actionLabel: 'Open settings',
        onAction: () async {
          await _location.openSettings();
          await _fetch();
        },
      );
    }
    if (_errorMessage != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        color: AppColors.ember,
        title: 'Could not complete the search',
        body: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _fetch,
      );
    }
    if (_hospitals.isEmpty) {
      return _StateMessage(
        icon: Icons.travel_explore_rounded,
        color: AppColors.textFaint,
        title: 'Nothing found within 5 km',
        body:
            'No facilities were returned for your area. If this is an '
            'emergency, call your local emergency number directly.',
        actionLabel: 'Search again',
        onAction: _fetch,
      );
    }

    final shown = _hospitals.take(4).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        AppTheme.space20,
        AppTheme.gutter,
        AppTheme.space40,
      ),
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTheme.space12),
          _HospitalCard(
            hospital: shown[i],
            accent: _accent,
            onDirections: () => _directions(shown[i]),
            onCall: () => _call(shown[i]),
            onWebsite: () => _website(shown[i]),
          ),
        ],
        if (_hospitals.length > shown.length) ...[
          const SizedBox(height: AppTheme.space16),
          AppButton(
            label: 'View all ${_hospitals.length} facilities',
            variant: AppButtonVariant.secondary,
            onPressed: _showAll,
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _EmergencyHeader extends StatelessWidget {
  const _EmergencyHeader({
    required this.reason,
    required this.emergency,
    required this.onCall,
  });

  final String reason;
  final EmergencyNumber emergency;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accent: AppColors.ember,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Dot(color: AppColors.ember, size: 8),
              const SizedBox(width: AppTheme.space8),
              Text(
                'Seek care now',
                style: AppText.label.copyWith(color: AppColors.ember),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Text(reason, style: AppText.body),
          const SizedBox(height: AppTheme.space16),
          AppButton(
            // The number is on the button, not hidden behind the words
            // "emergency services". Someone who knows their local number can
            // then see immediately if the app has guessed wrong.
            label: 'Call ${emergency.number}',
            icon: Icons.call_rounded,
            variant: AppButtonVariant.danger,
            haptic: PressHaptic.medium,
            onPressed: onCall,
          ),
          if (!emergency.isKnownCountry) ...[
            const SizedBox(height: AppTheme.space8),
            Text(
              'If that is not the emergency number where you are, dial your '
              'local one.',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.specialistName});

  final int count;
  final String? specialistName;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count == 1 ? '1 facility nearby' : '$count facilities nearby',
                style: AppText.h2,
              ),
              const SizedBox(height: 2),
              Text(
                specialistName != null
                    ? 'Ask for a ${specialistName!}.'
                    : 'Sorted by distance from you.',
                style: AppText.bodySm,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.hospital,
    required this.accent,
    required this.onDirections,
    required this.onCall,
    required this.onWebsite,
  });

  final HospitalData hospital;
  final Color accent;
  final VoidCallback onDirections;
  final VoidCallback onCall;
  final VoidCallback onWebsite;

  @override
  Widget build(BuildContext context) {
    final h = hospital;
    // Only a facility with an emergency department gets the ember treatment,
    // so the colour keeps meaning one thing.
    final cardAccent = h.hasEmergency ? AppColors.ember : null;

    return AppCard(
      accent: cardAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(h.name, style: AppText.h2)),
              if (h.hasEmergency) ...[
                const SizedBox(width: AppTheme.space8),
                const StatusPill('24h ER', color: AppColors.ember),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Text(h.type, style: AppText.caption),
          const SizedBox(height: AppTheme.space16),

          // Distance and drive time as instrument readouts rather than
          // sentences — they are the two numbers people compare between
          // cards, so they are set to line up down the list.
          Row(
            children: [
              _Metric(
                label: 'Distance',
                value: '${h.distanceKm.toStringAsFixed(1)} km',
              ),
              const SizedBox(width: AppTheme.space32),
              _Metric(label: 'Drive', value: '≈ ${h.estimatedTimeMins} min'),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppTheme.space16),

          Row(
            children: [
              if (h.hasPhone)
                _IconAction(
                  icon: Icons.call_rounded,
                  tooltip: 'Call ${h.name}',
                  onTap: onCall,
                ),
              if (h.hasWebsite) ...[
                if (h.hasPhone) const SizedBox(width: AppTheme.space8),
                _IconAction(
                  icon: Icons.language_rounded,
                  tooltip: 'Website',
                  onTap: onWebsite,
                ),
              ],
              const Spacer(),
              AppButton(
                label: 'Directions',
                trailingIcon: Icons.arrow_outward_rounded,
                fullWidth: false,
                compact: true,
                accent: h.hasEmergency ? AppColors.ember : accent,
                onPressed: onDirections,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        Text(value, style: AppText.value),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.9,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppColors.strokeStrong, width: 1),
          ),
          child: Icon(icon, size: 17, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

/// The searching state.
///
/// An indeterminate spinner, because the wait is a location fix plus a network
/// call and neither reports how far along it is. A bar that filled would be
/// inventing a duration.
class _Searching extends StatelessWidget {
  const _Searching({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
            ),
            const SizedBox(height: AppTheme.space20),
            Text('Looking for care near you', style: AppText.h3),
            const SizedBox(height: AppTheme.space4),
            Text(
              'This can take a few seconds.',
              style: AppText.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.wash(color, 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: AppTheme.space20),
            Text(title, style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.space8),
            Text(body, style: AppText.bodySm, textAlign: TextAlign.center),
            const SizedBox(height: AppTheme.space24),
            AppButton(
              label: actionLabel,
              fullWidth: false,
              variant: AppButtonVariant.secondary,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
