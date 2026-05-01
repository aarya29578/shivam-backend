import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/api/api_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/offline_image_service.dart';
import '../../../core/services/upload_queue_service.dart';
import '../../../core/services/class_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

// ── School data model for selector ──────────────────────────────────
class _SchoolInfo {
  final String id;
  final String name;
  final String code;
  final bool isPrincipal;
  const _SchoolInfo(
      {required this.id,
      required this.name,
      required this.code,
      this.isPrincipal = false});
}

// ═══════════════════════════════════════════════════════════════════
// QUICK CAPTURE SETUP SCREEN
// Route: Navigator.push — reached from UploadPhotosScreen
// ═══════════════════════════════════════════════════════════════════

class QuickCaptureSetupScreen extends StatefulWidget {
  const QuickCaptureSetupScreen({super.key});

  @override
  State<QuickCaptureSetupScreen> createState() =>
      _QuickCaptureSetupScreenState();
}

class _QuickCaptureSetupScreenState extends State<QuickCaptureSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameCtrl = TextEditingController();
  _SchoolInfo? _selectedSchool;
  bool _requesting = false;

  // Dynamic classes fetched from backend for the selected school
  List<String> _classes = [];
  bool _loadingClasses = false;
  String? _classesError;

  // Students for the selected class
  List<Map<String, dynamic>> _students = [];
  bool _loadingStudents = false;

  void _openSchoolSelector() async {
    final school = await showModalBottomSheet<_SchoolInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SchoolSearchSheet(),
    );
    if (school != null && mounted) {
      setState(() {
        _selectedSchool = school;
        _classes = [];
        _classNameCtrl.clear();
        _classesError = null;
        _students = [];
      });
      debugPrint(
          '[QuickCapture] Selected schoolId=${school.id} name=${school.name}');
      // Class dropdowns removed: rely on manual class input and check-or-create API.
    }
  }

  void _onClassSelected(String cls) {
    setState(() {
      _classNameCtrl.text = cls;
      _students = [];
    });
    if (_selectedSchool != null) _fetchStudents(_selectedSchool!, cls);
  }

  Future<void> _fetchStudents(_SchoolInfo school, String className) async {
    if (className.isEmpty) return;
    setState(() => _loadingStudents = true);
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw Exception('No internet connection');
      }
      final token = await AuthService.instance.getStoredToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      // For principal-based schools use schoolCode; for client-based use schoolId
      Response resp;
      if (school.isPrincipal) {
        resp = await dio.get(
          '/api/students',
          queryParameters: {
            'schoolCode': school.code,
            // include both keys to be compatible with backends expecting either
            'class': className.trim(),
            'className': className.trim(),
          },
          options: Options(
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          ),
        );
        if (resp.data is List && (resp.data as List).isEmpty) {
          throw Exception('No students found');
        }
      } else {
        final url = ApiConfig.studentList(school.id, className: className);
        resp = await dio.get(
          url,
          options: Options(
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          ),
        );
        if (resp.data is List && (resp.data as List).isEmpty) {
          throw Exception('No students found');
        }
      }
      debugPrint('[QuickCapture] fetchStudents → ${resp.statusCode}');
      final raw = resp.data;
      if (raw is List) {
        if (!mounted) return;
        setState(() {
          _students = raw.whereType<Map<String, dynamic>>().toList();
          _loadingStudents = false;
        });
        debugPrint('[QuickCapture] loaded ${_students.length} students');
      } else if (raw is Map && raw['students'] is List) {
        if (!mounted) return;
        setState(() {
          _students = (raw['students'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          _loadingStudents = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _students = [];
          _loadingStudents = false;
        });
      }
    } catch (e) {
      print('ERROR: $e');
      debugPrint('[QuickCapture] fetchStudents error: $e');
      if (!mounted) return;
      setState(() {
        _students = [];
        _loadingStudents = false;
      });
    }
  }

  Future<void> _fetchClasses(String schoolId) async {
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final token = await AuthService.instance.getStoredToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      // Use principalId endpoint for principal-based schools, client endpoint otherwise
      final url = (_selectedSchool?.isPrincipal == true)
          ? '${ApiConfig.baseUrl}/api/vendor/schools/classes?principalId=${_selectedSchool!.id}'
          : ApiConfig.vendorSchoolClasses(schoolId);
      final resp = await dio.get(
        url,
        options: Options(
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      final raw = resp.data;
      if (raw is Map && raw['classes'] is List) {
        final fetched = (raw['classes'] as List)
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
        debugPrint('[QuickCapture] Fetched classes=$fetched');
        if (!mounted) return;
        setState(() {
          _classes = fetched;
          _loadingClasses = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _classes = [];
          _loadingClasses = false;
        });
      }
    } catch (e) {
      debugPrint('[QuickCapture] fetchClasses error: $e');
      if (!mounted) return;
      setState(() {
        _classesError = 'Failed to load classes';
        _loadingClasses = false;
      });
    }
  }

  @override
  void dispose() {
    _classNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCapture() async {
    if (_selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a school first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _requesting = true);

    final className = _classNameCtrl.text.trim();
    if (className.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter class name'), backgroundColor: Colors.red),
      );
      setState(() => _requesting = false);
      return;
    }

    try {
      // Debug: log selected school and class
      print('Selected School: ${_selectedSchool!.code}');
      print('Selected Class: $className');

      // Ensure class exists (or create) on the backend before proceeding
      final schoolId =
          _selectedSchool!.isPrincipal ? null : _selectedSchool!.id;
      final principalId =
          _selectedSchool!.isPrincipal ? _selectedSchool!.id : null;

      final checkResult = await ClassService.checkOrCreateClass(
        schoolId: schoolId,
        principalId: principalId,
        className: className,
      );
      final created = checkResult['created'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(created ? 'New class created' : 'Class exists'),
          backgroundColor: created ? Colors.green : Colors.blue,
        ),
      );

      // Fetch students for this class (fresh) before starting capture
      await _fetchStudents(_selectedSchool!, className);

      if (_loadingStudents) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please wait — loading students…'),
              backgroundColor: Colors.orange),
        );
        return;
      }

      if (_students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No students found, starting manual capture'),
            backgroundColor: Colors.orange,
          ),
        );
        // proceed with roll-based capture — QuickCameraScreen supports an empty
        // student list by falling back to roll counters and Hive offline storage.
      }

      // Camera permission: throw if denied so catch block shows exact error
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission denied');
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera found on this device.');
      }

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuickCameraScreen(
              schoolId: _selectedSchool!.id,
              schoolCode: _selectedSchool!.code,
              schoolName: _selectedSchool!.name,
              className: _classNameCtrl.text.trim(),
              cameras: cameras,
              students: List<Map<String, dynamic>>.from(_students),
            ),
          ),
        );
        if (mounted && _selectedSchool != null) {
          _fetchStudents(_selectedSchool!, _classNameCtrl.text.trim());
        }
      }
    } catch (e) {
      // Show exact error and log for debugging
      print('ERROR: $e');
      print('CAPTURE ERROR: $e');
      debugPrint('[QuickCapture] _startCapture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Capture Setup'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pending-upload banner ────────────────────────────
              ValueListenableBuilder<int>(
                valueListenable: UploadQueueService.instance.pendingCount,
                builder: (_, pending, __) {
                  if (pending == 0) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable:
                              UploadQueueService.instance.isUploading,
                          builder: (_, uploading, __) => uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.orange,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined,
                                  color: Colors.orange, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$pending photo${pending == 1 ? '' : 's'} pending upload',
                            style: AppTypography.bodySmall.copyWith(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => UploadQueueService.instance
                              .tryUploadPendingImages(),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange.shade800,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: AppTypography.caption
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // ── Header card ─────────────────────────────────────
              _InfoBanner(
                icon: Icons.camera_alt_rounded,
                color: AppColors.secondary,
                title: 'Quick Capture Mode',
                subtitle: 'Select a class to load its student list. Photos are '
                    'captured per student and saved to their profile automatically.',
              ),
              const SizedBox(height: 28),

              // ── School Selector ──────────────────────────────────
              Text('School', style: AppTypography.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openSchoolSelector,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedSchool == null
                          ? Theme.of(context).colorScheme.outline
                          : AppColors.secondary,
                      width: _selectedSchool == null ? 1 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        color: _selectedSchool == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : AppColors.secondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selectedSchool == null
                            ? Text(
                                'Tap to select school…',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedSchool!.name,
                                    style: AppTypography.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Code: ${_selectedSchool!.code}',
                                    style: AppTypography.caption.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ],
                              ),
                      ),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Class Name ──────────────────────────────────────
              Text('Class Name', style: AppTypography.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _classNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. 1st_A or 10th_B',
                  prefixIcon: const Icon(Icons.class_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Class name required'
                    : null,
              ),
              const SizedBox(height: 12),

              // ── Dynamic class buttons ────────────────────────────
              if (_loadingClasses)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading classes…'),
                    ],
                  ),
                )
              else if (_classesError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _classesError!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                )
              else if (_selectedSchool != null && _classes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No classes found for this school.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13),
                  ),
                )
              else if (_classes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _classes.map((cls) {
                    final isSelected = _classNameCtrl.text == cls;
                    return GestureDetector(
                      onTap: () => _onClassSelected(cls),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary
                              : Colors.transparent,
                          border: Border.all(
                            color: AppColors.secondary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          cls,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // ── Student list for selected class ──────────────────
              if (_loadingStudents)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Loading students…'),
                    ],
                  ),
                )
              else if (_students.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_students.length} Students in ${_classNameCtrl.text}',
                          style: AppTypography.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _students.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (ctx, i) {
                          final s = _students[i];
                          final name = (s['name'] as String? ?? '').trim();
                          final roll = (s['rollNumber'] as String? ??
                                  s['roll'] as String? ??
                                  '')
                              .trim();
                          final photo =
                              (s['profileImage'] as String? ?? '').trim();
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.secondary.withOpacity(0.15),
                              backgroundImage: photo.isNotEmpty
                                  ? NetworkImage(
                                      ApiConfig.resolveImageUrl(photo))
                                  : null,
                              child: photo.isEmpty
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    )
                                  : null,
                            ),
                            title: Text(name,
                                style: AppTypography.bodySmall
                                    .copyWith(fontWeight: FontWeight.w600)),
                            subtitle: roll.isNotEmpty
                                ? Text('Roll: $roll',
                                    style: AppTypography.caption)
                                : null,
                            trailing: photo.isNotEmpty
                                ? const Icon(Icons.check_circle_rounded,
                                    color: Colors.green, size: 18)
                                : const Icon(Icons.radio_button_unchecked,
                                    color: Colors.grey, size: 18),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '✓ = photo captured  ○ = no photo yet',
                      style: AppTypography.caption.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // ── How it works ────────────────────────────────────
              Text('How it works', style: AppTypography.labelLarge),
              const SizedBox(height: 10),
              ...[
                (
                  Icons.looks_one_rounded,
                  'Camera opens in full-screen capture mode'
                ),
                (
                  Icons.looks_two_rounded,
                  'Roll 001 shown — press 📸 to capture'
                ),
                (
                  Icons.looks_3_rounded,
                  'Roll auto-increments after each capture'
                ),
                (
                  Icons.looks_4_rounded,
                  'Press ⏭️ Skip to skip a roll without photo'
                ),
                (
                  Icons.looks_5_rounded,
                  'Photos saved offline first — auto-uploaded when connected'
                ),
              ].map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(step.$1, color: AppColors.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(step.$2, style: AppTypography.bodySmall),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Start button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _requesting ? null : _startCapture,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    _requesting ? 'Opening Camera…' : 'Start Capture',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.secondary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// QUICK CAMERA SCREEN  — full-screen camera capture loop
// ═══════════════════════════════════════════════════════════════════

class QuickCameraScreen extends StatefulWidget {
  final String schoolId;
  final String schoolCode;
  final String schoolName;
  final String className;
  final List<CameraDescription> cameras;
  final List<Map<String, dynamic>> students;

  const QuickCameraScreen({
    super.key,
    required this.schoolId,
    required this.schoolCode,
    required this.schoolName,
    required this.className,
    required this.cameras,
    this.students = const [],
  });

  @override
  State<QuickCameraScreen> createState() => _QuickCameraScreenState();
}

class _QuickCameraScreenState extends State<QuickCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _ctrl;
  bool _initialized = false;
  bool _capturing = false;
  bool _showFlash = false; // brief white flash on capture

  int _currentRoll = 1; // single source of truth for roll number
  int _currentIndex = 0; // student-driven mode: index into widget.students

  String? _lastImagePath; // thumbnail of last captured image
  String? _statusMsg; // toast-style status overlay
  // Manual roll input controller (kept in sync with `_currentRoll`)
  final TextEditingController _manualRollCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initCamera();
    // Ensure roll input reflects student list (if any)
    _syncCurrentRollWithStudent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    _manualRollCtrl.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;
    final cam = widget.cameras.first; // back camera
    final controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _ctrl = controller;
          _initialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        _showStatus('Camera init failed: $e', isError: true);
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────

  String get _paddedRoll => _currentRoll.toString().padLeft(3, '0');

  /// Sync `_currentRoll` with the current student (if student has a roll).
  void _syncCurrentRollWithStudent() {
    if (widget.students.isNotEmpty && _currentIndex < widget.students.length) {
      final s = widget.students[_currentIndex];
      final rollStr = (s['rollNumber'] ?? s['roll'] ?? '').toString().trim();
      final parsed = int.tryParse(rollStr);
      if (parsed != null && parsed >= 0) {
        _currentRoll = parsed;
        _manualRollCtrl.text = _currentRoll.toString();
        return;
      }
    }
    // Fallback: ensure text field shows currentRoll
    _manualRollCtrl.text = _currentRoll.toString();
  }

  void _showStatus(String msg, {bool isError = false}) {
    if (!mounted) return;
    setState(() => _statusMsg = msg);
    Future.delayed(Duration(seconds: isError ? 3 : 2), () {
      if (mounted) setState(() => _statusMsg = null);
    });
  }

  // ── Capture ─────────────────────────────────────────────────────

  // Returns true when student-driven mode AND all students done
  bool get _allDone =>
      widget.students.isNotEmpty && _currentIndex >= widget.students.length;

  void _onCaptureDone() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All ${widget.students.length} students captured!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _capture() async {
    if (_capturing || !_initialized || _ctrl == null) return;
    if (_allDone) {
      _showStatus('All students captured!');
      return;
    }
    setState(() {
      _capturing = true;
      _showFlash = true;
    });

    // Student-driven: get current student; fall back to roll for legacy mode
    final students = widget.students;
    final Map<String, dynamic>? currentStudent =
        students.isNotEmpty ? students[_currentIndex] : null;
    final String studentId =
        (currentStudent?['id'] ?? currentStudent?['_id'] ?? '').toString();
    // Always use the single source-of-truth `_currentRoll` for saves.
    final String thisRoll = _currentRoll.toString().padLeft(3, '0');
    final String studentName =
        (currentStudent?['name'] ?? '').toString().trim();

    try {
      final file = await _ctrl!.takePicture();
      if (!mounted) return;

      // ── Offline-first: save to disk + Hive for roll-based queue fallback
      await OfflineImageService.instance.saveCapture(
        imagePath: file.path,
        schoolId: widget.schoolId,
        schoolCode: widget.schoolCode,
        className: widget.className,
        rollNo: thisRoll,
        studentId: studentId,
        studentName: studentName,
      );

      // Check connectivity to show the right status message
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      // ── Direct profile photo upload (student-driven) ────────────
      if (studentId.isNotEmpty && isOnline) {
        _uploadProfilePhoto(studentId, file.path, _currentIndex)
            .catchError((e) {
          debugPrint('[QuickCapture] Upload error caught at call site: $e');
        });
      }

      setState(() {
        _lastImagePath = file.path;
        _showFlash = false;

        if (students.isNotEmpty) {
          // Move to next student and sync roll if next student provides one.
          _currentIndex++;
          if (_currentIndex < widget.students.length) {
            final next = widget.students[_currentIndex];
            final nextRollStr =
                (next['rollNumber'] ?? next['roll'] ?? '').toString().trim();
            final nextVal = int.tryParse(nextRollStr);
            if (nextVal != null && nextVal >= 0) {
              _currentRoll = nextVal;
            } else {
              _currentRoll = _currentRoll + 1;
            }
          } else {
            // No more students — advance roll counter
            _currentRoll = _currentRoll + 1;
          }
        } else {
          // Roll-mode: always advance to next roll
          _currentRoll = _currentRoll + 1;
        }

        // Keep the text field in sync with currentRoll
        _manualRollCtrl.text = _currentRoll.toString();
      });

      _showStatus(studentName.isNotEmpty
          ? (isOnline
              ? '✓  $studentName — uploading…'
              : '✓  $studentName — saved offline')
          : (isOnline
              ? '✓  Roll $thisRoll — uploading…'
              : '✓  Roll $thisRoll — saved offline'));

      // Show completion snackbar after last student
      if (_allDone) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All students captured!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
      }

      UploadQueueService.instance.tryUploadPendingImages();
    } catch (e) {
      if (mounted) _showStatus('Capture failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// POST profile photo directly by studentId.
  /// Updates widget.students[capturedIndex]['profileImage'] on success so the
  /// setup-screen avatar and the camera-screen student info refresh automatically.
  Future<void> _uploadProfilePhoto(
      String studentId, String imagePath, int capturedIndex) async {
    final uploadUrl = '${ApiConfig.baseUrl}/api/students/upload-profile-photo';
    // ignore: avoid_print
    print('UPLOAD URL: $uploadUrl');
    try {
      final token = await AuthService.instance.getStoredToken();
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath,
            filename: 'profile_$studentId.jpg'),
        'studentId': studentId,
      });
      final resp = await Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      )).post(
        uploadUrl,
        data: formData,
        options: Options(
            headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      );

      // Use server-returned URL only — never assign a locally-constructed filename.
      final serverUrl = (resp.data['url'] ??
                  resp.data['profileImage'] ??
                  resp.data['imageUrl'])
              ?.toString() ??
          '';
      debugPrint(
          '[QuickCapture] ✓ Upload OK for $studentId serverUrl=$serverUrl');

      if (serverUrl.isNotEmpty && mounted) {
        // Refresh student record from server so profile image is always authoritative.
        try {
          final refreshResp = await Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          )).get(
            '${ApiConfig.baseUrl}/api/students/$studentId',
            options: Options(
                headers: {if (token != null) 'Authorization': 'Bearer $token'}),
          );
          final updated = refreshResp.data as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              if (capturedIndex < widget.students.length) {
                widget.students[capturedIndex] = {
                  ...widget.students[capturedIndex],
                  ...updated,
                  'profileImage': updated['profileImage'] ?? serverUrl,
                };
              }
            });
          }
          debugPrint(
              '[QuickCapture] ✓ Student refreshed: profileImage=${updated['profileImage']}');
        } catch (_) {
          // Fallback: apply server URL directly if refresh fails.
          if (mounted) {
            setState(() {
              if (capturedIndex < widget.students.length) {
                widget.students[capturedIndex]['profileImage'] = serverUrl;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[QuickCapture] ✗ Profile photo upload FAILED for $studentId: $e');
      if (mounted) {
        _showStatus('Upload failed — will retry when reconnected',
            isError: true);
      }
      // Re-throw so the caller can handle / surface the error.
      rethrow;
    }
  }

  // ── Skip ────────────────────────────────────────────────────────

  void _skip() {
    if (widget.students.isNotEmpty) {
      if (_allDone) return;
      final name = (widget.students[_currentIndex]['name'] ?? 'student')
          .toString()
          .trim();
      setState(() {
        _currentIndex++;
        // Sync roll to next student if available
        if (_currentIndex < widget.students.length) {
          final next = widget.students[_currentIndex];
          final nextRollStr =
              (next['rollNumber'] ?? next['roll'] ?? '').toString().trim();
          final nextVal = int.tryParse(nextRollStr);
          if (nextVal != null && nextVal >= 0) {
            _currentRoll = nextVal;
          } else {
            _currentRoll = _currentRoll + 1;
          }
        } else {
          _currentRoll = _currentRoll + 1;
        }
        _manualRollCtrl.text = _currentRoll.toString();
      });
      _showStatus('Skipped ${name.isNotEmpty ? name : 'student'}');
    } else {
      final skipped = _paddedRoll;
      setState(() => _currentRoll++);
      _manualRollCtrl.text = _currentRoll.toString();
      _showStatus('Skipped roll $skipped');
    }
  }

  /// Apply manual roll entered by user. Validates input and stores it in
  /// `_currentRoll` (keeps the single source of truth in sync).
  void _applyManualRoll() {
    final text = _manualRollCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _currentRoll = 1);
      _manualRollCtrl.text = _currentRoll.toString();
      _showStatus('Manual roll cleared');
      return;
    }
    final val = int.tryParse(text);
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid positive roll number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (text.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Roll number too long (max 4 digits)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _currentRoll = val;
      _manualRollCtrl.text = _currentRoll.toString();
    });
    _showStatus('Manual roll set to ${val.toString().padLeft(3, '0')}');
  }

  // ── Exit confirmation ────────────────────────────────────────────

  Future<bool> _confirmExit() async {
    final capturedCount =
        widget.students.isNotEmpty ? _currentIndex : _currentRoll - 1;
    if (capturedCount == 0) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Capture?'),
        content: Text(
          '$capturedCount photo${capturedCount == 1 ? '' : 's'} captured.\n'
          'All photos are saved offline and will upload automatically when connected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera preview ──────────────────────────────────
            if (_initialized && _ctrl != null)
              Transform.scale(
                scale: 1.0,
                child: Center(child: CameraPreview(_ctrl!)),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Initializing camera…',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),

            // ── Capture flash overlay ───────────────────────────
            if (_showFlash) Container(color: Colors.white.withOpacity(0.65)),

            // ── Top overlay: school / class / roll ──────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _InfoChip(
                          icon: Icons.school_rounded,
                          label: 'School',
                          value: widget.schoolName.length > 14
                              ? '${widget.schoolName.substring(0, 14)}…'
                              : widget.schoolName),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.class_rounded,
                          label: 'Class',
                          value: widget.className.length > 12
                              ? '${widget.className.substring(0, 12)}…'
                              : widget.className),
                      const Spacer(),
                      // Student / roll badge — prominent
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _allDone ? Colors.green : AppColors.secondary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (_allDone
                                      ? Colors.green
                                      : AppColors.secondary)
                                  .withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: widget.students.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.person_rounded,
                                      color: Colors.white70, size: 14),
                                  const SizedBox(width: 5),
                                  Text(
                                    _allDone
                                        ? 'Done!'
                                        : (widget.students[_currentIndex]
                                                    ['name']
                                                ?.toString()
                                                .trim() ??
                                            '?'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_allDone ? widget.students.length : _currentIndex + 1}/${widget.students.length}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Roll ',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  Text(
                                    _paddedRoll,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Uploading indicator (top-right) ─────────────────
            ValueListenableBuilder<bool>(
              valueListenable: UploadQueueService.instance.isUploading,
              builder: (_, uploading, __) => uploading
                  ? const Positioned(
                      top: 80,
                      right: 16,
                      child: _UploadingBadge(),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── Pending count badge ─────────────────────────────
            ValueListenableBuilder<int>(
              valueListenable: UploadQueueService.instance.pendingCount,
              builder: (_, pending, __) {
                if (pending == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 80,
                  left: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pending pending',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),

            // ── Last captured thumbnail ─────────────────────────
            if (_lastImagePath != null)
              Positioned(
                bottom: 120,
                right: 16,
                child: GestureDetector(
                  onTap: () => _showFullPreview(_lastImagePath!),
                  child: Container(
                    width: 54,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(_lastImagePath!)),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.students.isNotEmpty
                              ? '$_currentIndex/${widget.students.length}'
                              : (_currentRoll - 1).toString().padLeft(3, '0'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Status toast ────────────────────────────────────
            if (_statusMsg != null)
              Positioned(
                bottom: 110,
                left: 24,
                right: 80, // leave room for thumbnail
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _statusMsg!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

            // ── Bottom controls ─────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Manual roll input row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualRollCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 4,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (v) {
                                final parsed = int.tryParse(v.trim());
                                if (parsed != null && parsed >= 0) {
                                  setState(() => _currentRoll = parsed);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Enter Roll Number (Optional)',
                                counterText: '',
                                prefixIcon: const Icon(
                                    Icons.confirmation_number,
                                    color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white12,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () => _applyManualRoll(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Use Roll'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Skip
                          _ControlButton(
                            icon: Icons.skip_next_rounded,
                            label: 'Skip',
                            color: Colors.orange,
                            onTap: _skip,
                          ),
                          // Capture — big shutter button
                          _ShutterButton(
                            onTap: _allDone
                                ? _onCaptureDone
                                : (_capturing ? null : _capture),
                            capturing: _capturing,
                            done: _allDone,
                          ),
                          // Exit
                          _ControlButton(
                            icon: Icons.close_rounded,
                            label: 'Exit',
                            color: Colors.redAccent,
                            onTap: () async {
                              if (await _confirmExit()) {
                                if (mounted) Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPreview(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 13),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ControlButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool capturing;
  final bool done;

  const _ShutterButton({
    required this.onTap,
    required this.capturing,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? Colors.green : Colors.white,
                width: 4,
              ),
              color: (done || capturing)
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.15),
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.green, size: 34)
                : capturing
                    ? const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
          ),
          const SizedBox(height: 6),
          Text(done ? 'Done' : 'Capture',
              style: TextStyle(
                  color: done ? Colors.green : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _UploadingBadge extends StatelessWidget {
  const _UploadingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child:
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text('Uploading',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Info banner used in setup screen ────────────────────────────────

// ═══════════════════════════════════════════════════════════════════
// SCHOOL SEARCH SHEET
// ═══════════════════════════════════════════════════════════════════

class _SchoolSearchSheet extends StatefulWidget {
  const _SchoolSearchSheet();

  @override
  State<_SchoolSearchSheet> createState() => _SchoolSearchSheetState();
}

class _SchoolSearchSheetState extends State<_SchoolSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<_SchoolInfo> _all = [];
  List<_SchoolInfo> _filtered = [];
  bool _loading = true;
  bool _isOffline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSchools('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Save a list of _SchoolInfo to Hive cache (only when query is empty = full list)
  Future<void> _saveToCache(List<_SchoolInfo> list) async {
    try {
      final box = Hive.box('schoolsBox');
      await box.clear();
      for (final s in list) {
        await box.add({
          'id': s.id,
          'name': s.name,
          'code': s.code,
          'isPrincipal': s.isPrincipal
        });
      }
    } catch (_) {}
  }

  /// Load schools from Hive cache (offline fallback)
  List<_SchoolInfo> _loadFromCache() {
    try {
      final box = Hive.box('schoolsBox');
      return box.values
          .whereType<Map>()
          .map((e) => _SchoolInfo(
                id: e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
                code: e['code']?.toString() ?? '',
                isPrincipal: e['isPrincipal'] == true,
              ))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchSchools(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      // Fetch ALL schools — no vendorId filter so principal-based schools are included
      final resp = await dio.get(
        '${ApiConfig.baseUrl}/api/schools',
        queryParameters: {
          if (query.trim().isNotEmpty) 'search': query.trim(),
        },
      );
      debugPrint('[QuickCapture] Schools API Response: ${resp.data}');
      if (resp.statusCode == 200 && resp.data is List) {
        final list = (resp.data as List)
            .map((e) => _SchoolInfo(
                  id: e['id'].toString(),
                  name: e['name'].toString(),
                  code: e['code'].toString(),
                  isPrincipal: e['type'] == 'principal',
                ))
            .toList();
        // Cache full list (no search query) for offline use
        if (query.trim().isEmpty) await _saveToCache(list);
        if (!mounted) return;
        setState(() {
          _all = list;
          _filtered = list;
          _isOffline = false;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Failed to load schools.';
          _loading = false;
        });
      }
    } catch (e) {
      // Network error — fall back to Hive cache
      debugPrint('[QuickCapture] Offline, loading schools from cache: $e');
      final cached = _loadFromCache();
      if (cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _all = cached;
          _filtered = cached;
          _isOffline = true;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isOffline = true;
          _error = 'No internet. Connect once to cache schools.';
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String query) {
    // Client-side filter for instant response; API search already did server-side
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((s) =>
                  s.name.toLowerCase().contains(q) ||
                  s.code.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.school_rounded,
                        color: AppColors.secondary, size: 22),
                    const SizedBox(width: 10),
                    Text('Select School',
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── Search field ─────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search school name or code…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: _onSearch,
                ),
              ),

              // ── Offline banner ───────────────────────────────────
              if (_isOffline)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline mode — showing saved schools',
                          style: TextStyle(
                              color: Colors.orange.shade800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Content ──────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Colors.red, size: 40),
                                  const SizedBox(height: 12),
                                  Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodyMedium),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry'),
                                    onPressed: () =>
                                        _fetchSchools(_searchCtrl.text),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off_rounded,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                          size: 40),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchCtrl.text.isEmpty
                                            ? 'No schools found.\nAdd schools via the Clients section.'
                                            : 'No match for "${_searchCtrl.text}"',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.only(
                                    left: 12, right: 12, bottom: 24),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final s = _filtered[i];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.secondary.withOpacity(0.12),
                                      child: Icon(Icons.school_rounded,
                                          color: AppColors.secondary, size: 20),
                                    ),
                                    title: Text(s.name,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600)),
                                    subtitle: s.code.isNotEmpty
                                        ? Text('Code: ${s.code}',
                                            style: AppTypography.caption)
                                        : null,
                                    onTap: () => Navigator.of(context).pop(s),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Info banner used in setup screen ────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelLarge
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
