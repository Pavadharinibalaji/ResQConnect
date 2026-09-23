import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:resqconnect/core/map/resq_map_controller.dart';
import 'package:resqconnect/core/providers/location_provider.dart';
import 'package:resqconnect/core/theme/app_colors.dart';
import 'package:resqconnect/core/theme/app_theme.dart';
import 'package:resqconnect/features/feed/presentation/providers/incident_provider.dart';
import 'package:resqconnect/features/map/presentation/widgets/incident_map_marker.dart';
import 'package:resqconnect/features/map/presentation/widgets/resq_map_view.dart';
import 'package:resqconnect/features/feed/domain/evidence_upload.dart';

class LocalEvidenceItem {
  final String path;
  final String type; // photo, video

  LocalEvidenceItem({required this.path, required this.type});
}

class CreateIncidentPage extends ConsumerStatefulWidget {
  const CreateIncidentPage({super.key});

  @override
  ConsumerState<CreateIncidentPage> createState() => _CreateIncidentPageState();
}

class _CreateIncidentPageState extends ConsumerState<CreateIncidentPage> {
  int _currentStep = 0;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController(text: 'Sector 4, Metro Highway Crossing');

  String _selectedCategory = 'fire';
  String _selectedSeverity = 'critical';

  final ImagePicker _picker = ImagePicker();
  final List<LocalEvidenceItem> _attachedEvidence = [];

  final ResQMapController _pickerMapController = ResQMapController();

  /// Manually adjusted incident position.
  ///
  /// Null means "use the device GPS fix" — the reporter is often not standing
  /// exactly where the emergency is, so the pin can be corrected without
  /// discarding the GPS default.
  double? _pickedLat;
  double? _pickedLng;

  bool get _isLocationOverridden => _pickedLat != null && _pickedLng != null;

  double _effectiveLat(LocationState loc) => _pickedLat ?? loc.latitude;
  double _effectiveLng(LocationState loc) => _pickedLng ?? loc.longitude;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'fire', 'name': 'Fire', 'icon': Icons.local_fire_department_rounded, 'color': AppColors.primaryEmergencyRed},
    {'id': 'medical', 'name': 'Medical', 'icon': Icons.medical_services_rounded, 'color': AppColors.warmSignalAmber},
    {'id': 'accident', 'name': 'Accident', 'icon': Icons.car_crash_rounded, 'color': Colors.orange},
    {'id': 'crime', 'name': 'Crime', 'icon': Icons.local_police_rounded, 'color': Colors.indigo},
    {'id': 'flood', 'name': 'Flood', 'icon': Icons.tsunami_rounded, 'color': Colors.blue},
    {'id': 'missing', 'name': 'Missing Person', 'icon': Icons.person_search_rounded, 'color': Colors.purple},
    {'id': 'disaster', 'name': 'Disaster', 'icon': Icons.thunderstorm_rounded, 'color': Colors.deepOrange},
    {'id': 'other', 'name': 'Other', 'icon': Icons.warning_amber_rounded, 'color': Colors.grey},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission(Permission permission, String name) async {
    final status = await permission.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('$name Permission Required'),
            content: Text('$name access is required to capture emergency evidence.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  openAppSettings();
                },
                child: const Text('OPEN SETTINGS'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return false;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final granted = await _requestPermission(Permission.camera, 'Camera');
      if (!granted) return;
    }
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file != null) {
        setState(() {
          _attachedEvidence.add(LocalEvidenceItem(path: file.path, type: 'photo'));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (source == ImageSource.camera) {
      final granted = await _requestPermission(Permission.camera, 'Camera');
      if (!granted) return;
    }
    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file != null) {
        setState(() {
          _attachedEvidence.add(LocalEvidenceItem(path: file.path, type: 'video'));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to pick video: $e')),
        );
      }
    }
  }

  void _syncDraftToProvider() {
    final locationState = ref.read(locationProvider);
    final lat = _effectiveLat(locationState);
    final lng = _effectiveLng(locationState);

    ref.read(incidentProvider.notifier).updateDraft(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
          severity: _selectedSeverity,
          address: _addressController.text.trim(),
          latitude: lat,
          longitude: lng,
        );
  }

  Future<void> _submitIncident() async {
    _syncDraftToProvider();

    final created = await ref.read(incidentProvider.notifier).createIncident();

    if (!mounted) return;

    if (created != null) {
      // Upload evidence files; failures are reported below, never swallowed.
      final uploadResult = await uploadEvidenceFiles(
        ref.read(incidentRepositoryProvider),
        created.id,
        [for (final item in _attachedEvidence) (path: item.path, type: item.type)],
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusL)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.safeEmerald, size: 28),
                SizedBox(width: 8),
                Text('Incident Reported!'),
              ],
            ),
            content: Text(
              uploadResult.allSucceeded
                  ? 'Emergency "${created.title}" has been broadcasted to local responders with attached evidence.'
                  : 'Emergency reported successfully, but ${uploadResult.failureSummary}',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryEmergencyRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.go('/incident/${created.id}');
                },
                child: const Text('VIEW INCIDENT DETAILS'),
              ),
            ],
          );
        },
      );
    } else {
      final errorMsg = ref.read(incidentProvider).errorMessage ?? 'Unable to report emergency. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.primaryEmergencyRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentState = ref.watch(incidentProvider);
    final isCreating = incidentState.status == IncidentStatus.creating;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Emergency Incident'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Progress
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primaryEmergencyRed : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceL),
                child: _buildCurrentStepView(theme, isDark),
              ),
            ),

            // Bottom Buttons
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceL),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isCreating ? null : () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('BACK'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: AppTheme.spaceM),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: isCreating
                          ? null
                          : () {
                              _syncDraftToProvider();
                              if (_currentStep < 3) {
                                setState(() => _currentStep++);
                              } else {
                                _submitIncident();
                              }
                            },
                      child: isCreating
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                SizedBox(width: 8),
                                Text('REPORTING...'),
                              ],
                            )
                          : Text(_currentStep == 3 ? 'SUBMIT INCIDENT' : 'NEXT STEP'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(ThemeData theme, bool isDark) {
    final locationState = ref.watch(locationProvider);

    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1: Select Category', style: AppTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('What type of emergency is occurring?', style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppTheme.spaceL),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['id'];
                final catColor = cat['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat['id'] as String);
                    _syncDraftToProvider();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? catColor.withValues(alpha: 0.15) : (isDark ? AppColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(color: isSelected ? catColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'] as IconData, color: catColor, size: 36),
                        const SizedBox(height: 8),
                        Text(cat['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? catColor : null)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 2: Add Incident Details & Evidence', style: AppTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Provide clear details and attached media evidence.', style: AppTheme.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppTheme.spaceL),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title / Summary *', hintText: 'Heavy smoke in building'),
              onChanged: (_) => _syncDraftToProvider(),
            ),
            const SizedBox(height: AppTheme.spaceM),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description *', hintText: 'Trapped on 2nd floor, emergency rescue needed...'),
              onChanged: (_) => _syncDraftToProvider(),
            ),
            const SizedBox(height: AppTheme.spaceXL),

            // EVIDENCE CONTROLS SECTION
            Text('ATTACH EMERGENCY EVIDENCE', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spaceS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryEmergencyRed),
                  label: const Text('TAKE PHOTO'),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.videocam_rounded, color: AppColors.primaryEmergencyRed),
                  label: const Text('RECORD VIDEO'),
                  onPressed: () => _pickVideo(ImageSource.camera),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('CHOOSE PHOTO'),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.video_library_rounded),
                  label: const Text('CHOOSE VIDEO'),
                  onPressed: () => _pickVideo(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceM),

            // EVIDENCE PREVIEW CARDS
            if (_attachedEvidence.isNotEmpty) ...[
              Text('Attached Media (${_attachedEvidence.length})', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedEvidence.length,
                  itemBuilder: (context, idx) {
                    final item = _attachedEvidence[idx];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                      ),
                      child: Stack(
                        children: [
                          if (item.type == 'photo')
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                              child: Image.file(
                                File(item.path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_circle_fill_rounded, color: AppColors.warmSignalAmber, size: 36),
                                  Text('VIDEO', style: AppTheme.bodySmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black.withValues(alpha: 0.7),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                onPressed: () {
                                  setState(() => _attachedEvidence.removeAt(idx));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 3: Location & Severity', style: AppTheme.headlineMedium),
            const SizedBox(height: AppTheme.spaceL),

            // Live Location Status Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(color: AppColors.primaryEmergencyRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.primaryEmergencyRed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLocationOverridden
                              ? 'Location Set Manually'
                              : locationState.status == LocationStatus.located
                                  ? 'GPS Coordinates Locked'
                                  : 'Detecting Location...',
                          style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Lat: ${_effectiveLat(locationState).toStringAsFixed(4)}, Lng: ${_effectiveLng(locationState).toStringAsFixed(4)}',
                          style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryEmergencyRed),
                    tooltip: 'Use my GPS location',
                    onPressed: () async {
                      setState(() {
                        _pickedLat = null;
                        _pickedLng = null;
                      });
                      await ref.read(locationProvider.notifier).fetchCurrentLocation();
                      if (!mounted) return;
                      final fresh = ref.read(locationProvider);
                      _pickerMapController.moveTo(
                        LatLng(fresh.latitude, fresh.longitude),
                        zoomLevel: 16.0,
                      );
                      _syncDraftToProvider();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceM),

            // Tap-to-adjust incident position.
            Text(
              'Pin the exact incident location',
              style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the map if the emergency is not where you are standing.',
              style: AppTheme.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceS),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    ResQMapView(
                      controller: _pickerMapController,
                      initialCenter: LatLng(
                        _effectiveLat(locationState),
                        _effectiveLng(locationState),
                      ),
                      initialZoom: 16.0,
                      showAttribution: false,
                      // Embedded in the step's SingleChildScrollView: leave
                      // one-finger drag to the form so the page still scrolls.
                      interactionFlags: ResQMapView.embeddedGestures,
                      onTap: (point) {
                        setState(() {
                          _pickedLat = point.latitude;
                          _pickedLng = point.longitude;
                        });
                        _syncDraftToProvider();
                      },
                      markers: [
                        Marker(
                          point: LatLng(
                            _effectiveLat(locationState),
                            _effectiveLng(locationState),
                          ),
                          width: 38,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: IncidentMapMarker(
                            severity: _selectedSeverity,
                            isSelected: true,
                            semanticLabel: 'Selected incident location',
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                    const Positioned(
                      left: 0,
                      bottom: 0,
                      child: MapAttributionBar(),
                    ),
                    if (_isLocationOverridden)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                            onTap: () {
                              final loc = ref.read(locationProvider);
                              setState(() {
                                _pickedLat = null;
                                _pickedLng = null;
                              });
                              _pickerMapController.moveTo(
                                LatLng(loc.latitude, loc.longitude),
                                zoomLevel: 16.0,
                              );
                              _syncDraftToProvider();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Text(
                                'RESET TO GPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryEmergencyRed,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceM),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Incident Location Address',
                prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primaryEmergencyRed),
              ),
              onChanged: (_) => _syncDraftToProvider(),
            ),
            const SizedBox(height: AppTheme.spaceXL),
            Text('Select Severity Level', style: AppTheme.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppTheme.spaceS),
            ...['low', 'moderate', 'high', 'critical'].map((sev) {
              final isSelectedSev = _selectedSeverity == sev;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelectedSev ? AppColors.primaryEmergencyRed.withValues(alpha: 0.1) : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: isSelectedSev ? AppColors.primaryEmergencyRed : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: isSelectedSev ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    setState(() => _selectedSeverity = sev);
                    _syncDraftToProvider();
                  },
                  title: Text(sev.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: isSelectedSev ? AppColors.primaryEmergencyRed : null)),
                  subtitle: Text('Level of immediate life or property risk: $sev'),
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelectedSev ? AppColors.primaryEmergencyRed : Colors.transparent,
                      border: Border.all(color: isSelectedSev ? AppColors.primaryEmergencyRed : Colors.grey, width: 2),
                    ),
                    child: isSelectedSev ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                  ),
                ),
              );
            }),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 4: Review Report', style: AppTheme.headlineMedium),
            const SizedBox(height: AppTheme.spaceL),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceM),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: AppColors.primaryEmergencyRed),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedCategory.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryEmergencyRed)),
                      Chip(label: Text(_selectedSeverity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: AppColors.primaryEmergencyRed),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_titleController.text.isEmpty ? 'Structure Fire Reported' : _titleController.text, style: AppTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(_addressController.text, style: AppTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    'Coordinates: (${_effectiveLat(locationState).toStringAsFixed(4)}, ${_effectiveLng(locationState).toStringAsFixed(4)})',
                    style: AppTheme.bodySmall.copyWith(color: AppColors.primaryEmergencyRed, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_descController.text.isEmpty ? 'Immediate assistance requested at scene.' : _descController.text, style: AppTheme.bodyMedium),
                  const SizedBox(height: 12),
                  if (_attachedEvidence.isNotEmpty)
                    Text('Attached Media Files: ${_attachedEvidence.length}', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.safeEmerald)),
                ],
              ),
            ),
          ],
        );
    }
  }
}
