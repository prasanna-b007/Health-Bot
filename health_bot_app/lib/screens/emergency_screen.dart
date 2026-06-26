import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/hospital_list_item.dart';
import 'hospital_finder_screen.dart';

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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HospitalFinderScreen(apiService: _apiService),
                        ),
                      );
                    },
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
