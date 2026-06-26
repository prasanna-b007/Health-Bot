import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/dashed_divider.dart';
import '../services/hospital_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalFinderScreen extends StatefulWidget {
  final ApiService apiService;
  final String? emergencyReason;

  const HospitalFinderScreen({super.key, required this.apiService, this.emergencyReason});

  @override
  State<HospitalFinderScreen> createState() => _HospitalFinderScreenState();
}

class _HospitalFinderScreenState extends State<HospitalFinderScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  String? _errorMessage;
  List<HospitalData> _hospitals = [];
  bool _showAllHospitals = false;

  @override
  void initState() {
    super.initState();
    _checkLocationAndFetchHospitals();
  }

  Future<void> _checkLocationAndFetchHospitals() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Please enable Location Services.';
          _isLoading = false;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _permissionDenied = true;
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _permissionDenied = true;
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      
      double latitude = position.latitude;
      double longitude = position.longitude;

      print('\nCurrent Location:');
      print('$latitude, $longitude\n');

      final fetchedHospitals = await HospitalService()
          .getNearbyHospitals(latitude, longitude);
      
      List<HospitalData> liveHospitals = [];
      for (var element in fetchedHospitals) {
        final tags = element['tags'];
        if (tags == null) continue;

        final name = tags['name'] ?? 'Medical Center';
        final phone = tags['contact:phone'] ?? tags['phone'] ?? 'N/A';
        final website = tags['website'] ?? tags['contact:website'] ?? '';
        final hasEmergency = tags['emergency'] == 'yes';
        
        final double hLat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
        final double hLon = element['lon'] ?? element['center']?['lon'] ?? 0.0;
        
        if (hLat == 0.0 || hLon == 0.0) continue;
        
        double distanceMeters = Geolocator.distanceBetween(latitude, longitude, hLat, hLon);
        final distanceKm = distanceMeters / 1000;
        String distanceStr = '${distanceKm.toStringAsFixed(1)} km away';

        final amenity = tags['amenity'];
        final healthcare = tags['healthcare'];
        String type = 'Medical Facility';
        if (amenity == 'hospital' || healthcare == 'hospital') type = 'General Hospital';
        else if (amenity == 'clinic' || healthcare == 'clinic') type = 'Clinic';

        final estimatedTimeMins = ((distanceKm / 30) * 60).round();

        liveHospitals.add(HospitalData(
          name: name,
          distance: distanceStr,
          rawDistance: distanceMeters,
          phone: phone,
          hasEmergency: hasEmergency,
          website: website,
          latitude: hLat,
          longitude: hLon,
          type: type,
          estimatedTimeMins: estimatedTimeMins,
        ));
      }

      liveHospitals.sort((a, b) => a.rawDistance.compareTo(b.rawDistance));

      print('Hospitals Found:');
      print('${liveHospitals.length}\n');
      for (int i = 0; i < liveHospitals.length; i++) {
        print('${i + 1}. ${liveHospitals[i].name}');
      }

      setState(() {
        _hospitals = liveHospitals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load nearby hospitals.\n\nPlease check your internet connection and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Text('Nearby Emergency Care', style: AppText.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.emergencyReason != null)
              Container(
                width: double.infinity,
                color: AppColors.riskHigh,
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Column(
                  children: [
                    Text('🚨 Based on your assessment,', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppTheme.spacing8),
                    Text('we recommend seeking immediate medical attention.\nHere are the nearest hospitals.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.card)),
                  ],
                ),
              )
            else if (_hospitals.isNotEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, AppTheme.spacing24, AppTheme.spacing24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nearest medical facilities based on your current location.', style: AppText.bodyMuted),
                    const SizedBox(height: AppTheme.spacing8),
                    Text('${_hospitals.length} hospitals found', style: AppText.body.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing24),
                child: _isLoading
                    ? _buildLoadingState()
                    : _permissionDenied
                        ? _buildPermissionState()
                        : _errorMessage != null
                            ? _buildErrorState()
                            : _hospitals.isEmpty
                                ? _buildEmptyState()
                                : _buildHospitalList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, color: AppColors.riskHigh, size: 48),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'Location permission is required to find nearby hospitals.',
            textAlign: TextAlign.center,
            style: AppText.h3,
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              // After returning from settings, the user can manually tap a retry button or we could auto-retry.
              // For simplicity, we just change the state to loading and re-check.
              setState(() {
                _isLoading = true;
                _permissionDenied = false;
              });
              _checkLocationAndFetchHospitals();
            },
            child: const Text('Grant Permission'),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'Finding nearby hospitals...\nThis may take a few seconds.',
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.riskHigh, size: 48),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.riskHigh),
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _checkLocationAndFetchHospitals();
            },
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_hospital_outlined, color: AppColors.subtext, size: 48),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            'No hospitals found within 5 km.',
            style: AppText.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'Try increasing the search radius or check your location settings.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrlString(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  void _showAllHospitalsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: AppTheme.spacing16),
            Text('All Nearby Facilities', style: AppText.h3),
            const SizedBox(height: AppTheme.spacing16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24, vertical: AppTheme.spacing16),
                itemCount: _hospitals.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing16),
                itemBuilder: (context, index) => _AnimatedHospitalCard(
                  hospital: _hospitals[index],
                  index: index,
                  onDirections: () => _launchUrlString('https://www.google.com/maps/search/?api=1&query=${_hospitals[index].latitude},${_hospitals[index].longitude}'),
                  onCall: () => _launchUrlString('tel:${_hospitals[index].phone}'),
                  onWebsite: () {
                    String url = _hospitals[index].website;
                    if (!url.startsWith('http')) url = 'https://$url';
                    _launchUrlString(url);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalList() {
    final displayList = _hospitals.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: displayList.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing16),
            itemBuilder: (context, index) {
              final h = displayList[index];
              return _AnimatedHospitalCard(
                hospital: h,
                index: index,
                onDirections: () => _launchUrlString('https://www.google.com/maps/search/?api=1&query=${h.latitude},${h.longitude}'),
                onCall: () => _launchUrlString('tel:${h.phone}'),
                onWebsite: () {
                  String url = h.website;
                  if (!url.startsWith('http')) url = 'https://$url';
                  _launchUrlString(url);
                },
              );
            },
          ),
        ),
        if (_hospitals.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing16),
            child: OutlinedButton(
              onPressed: _showAllHospitalsSheet,
              child: const Text('View All Hospitals'),
            ),
          ),
      ],
    );
  }
}

class _AnimatedHospitalCard extends StatefulWidget {
  final HospitalData hospital;
  final int index;
  final VoidCallback onDirections;
  final VoidCallback onCall;
  final VoidCallback onWebsite;

  const _AnimatedHospitalCard({
    required this.hospital,
    required this.index,
    required this.onDirections,
    required this.onCall,
    required this.onWebsite,
  });

  @override
  State<_AnimatedHospitalCard> createState() => _AnimatedHospitalCardState();
}

class _AnimatedHospitalCardState extends State<_AnimatedHospitalCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hospital;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusBorder),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_hospital, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppTheme.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.name, style: AppText.h3),
                        const SizedBox(height: 2),
                        Text(h.hasEmergency ? '🚨 Emergency' : '🏥 ${h.type}', style: AppText.caption.copyWith(
                          color: h.hasEmergency ? AppColors.riskHigh : AppColors.subtext,
                          fontWeight: FontWeight.bold,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(h.distance, style: AppText.bodyMuted),
                  const SizedBox(width: AppTheme.spacing16),
                  const Text('🚗', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('≈ ${h.estimatedTimeMins} min', style: AppText.bodyMuted),
                ],
              ),
              const SizedBox(height: AppTheme.spacing16),
              Row(
                children: [
                  if (h.phone != 'N/A' && h.phone.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.phone_outlined, size: 20),
                      color: AppColors.primary,
                      onPressed: widget.onCall,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                  ],
                  if (h.website.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.language_outlined, size: 20),
                      color: AppColors.primary,
                      onPressed: widget.onWebsite,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                  ],
                  const Spacer(),
                  ElevatedButton(
                    onPressed: widget.onDirections,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.card,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('Directions', style: AppText.body.copyWith(color: AppColors.card, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
