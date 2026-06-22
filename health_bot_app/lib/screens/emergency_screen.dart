import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/hospital_list_item.dart';

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


  
  void _onCallEmergency() {
    // In a real app, this would dial 911 or local emergency
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.riskHigh,
        elevation: 0,
        title: Text('🚨 MEDICAL EMERGENCY', style: AppText.h3.copyWith(color: AppColors.card)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.card),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              color: AppColors.riskHigh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Symptoms Detected', style: AppText.h3.copyWith(color: AppColors.card)),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    widget.reason,
                    style: AppText.body.copyWith(color: AppColors.card),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    'Please seek immediate medical attention.',
                    style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  ElevatedButton(
                    onPressed: _onCallEmergency,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.card,
                      foregroundColor: AppColors.riskHigh,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text('Call Emergency', style: AppText.body.copyWith(color: AppColors.riskHigh, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  OutlinedButton(
                    onPressed: () {}, // Handled below in UI
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.card,
                      side: const BorderSide(color: AppColors.card, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text('Find Nearby Hospitals', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                color: AppColors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing24),
                      child: Text('Nearby Hospitals', style: AppText.h3),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : _hospitals.isEmpty
                              ? const Center(
                                  child: Text('Please contact local emergency services.'),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                                  itemCount: _hospitals.length,
                                  separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: AppTheme.spacing32),
                                  itemBuilder: (context, index) {
                                    final h = _hospitals[index];
                                    return HospitalListItem(
                                      name: h.name,
                                      distance: h.distance,
                                      onCallPressed: () {},
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
