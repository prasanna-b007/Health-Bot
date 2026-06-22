import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/assessment_tag_card.dart';
import '../widgets/emergency_banner.dart';
import '../widgets/hospital_list_item.dart';
import '../widgets/risk_bar.dart';

class EmergencyScreen extends StatefulWidget {
  final String reason;

  const EmergencyScreen({
    super.key,
    required this.reason,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<HospitalData> _hospitals = [];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  void _loadHospitals() async {
    try {
      final hospitals = await _apiService.getNearbyHospitals();
      if (mounted) {
        setState(() {
          _hospitals = hospitals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onGetDirections() {
    // In a real app, this would open Maps.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false, // Hard cut, usually no way back, but we could add a close button if needed.
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.ink),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: AssessmentTagCard(
            statusWord: 'override',
            children: [
              const RiskBar(riskLevel: RiskLevel.emergency),
              EmergencyBanner(reason: widget.reason),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('nearest hospitals', style: AppText.dataLabel),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
                    )
                  else if (_hospitals.isEmpty)
                    HospitalListItem(
                      name: 'Please contact local emergency services',
                      distance: '',
                      onCallPressed: () {},
                    )
                  else
                    ..._hospitals.map((h) => HospitalListItem(
                          name: h.name,
                          distance: h.distance,
                          onCallPressed: () {},
                        )),
                ],
              ),
              OutlinedButton(
                onPressed: _onGetDirections,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.riskHigh,
                  side: const BorderSide(color: AppColors.riskHigh, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Get directions', style: AppText.body.copyWith(color: AppColors.riskHigh)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
