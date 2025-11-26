import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/user_model.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/hashing_utils.dart';
import '../../core/services/logger_service.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/numeric_pad.dart';

import '../../main.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  State<TimeClockScreen> createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> with WidgetsBindingObserver {
  // ──────────────── STATE ────────────────
  String _pinCode = "";
  bool _isLoading = false;
  
  // Selection State
  UserModel? _selectedUser; 
  UserModel? _activeUser;   
  AttendanceLogModel? _todayLog;

  Timer? _inactivityTimer;

  CameraController? _cameraController;
  bool _isCameraInitialized = false; // ✅ Added flag for safer UI rendering

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ Observe Lifecycle
    // ✅ Delay init to prevent navigation race conditions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ Handle App Backgrounding (Release Camera)
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    
    try {
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium, // ✅ CHANGED: 'low' causes crashes on some Android CameraX implementations
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      LoggerService.error("Camera Init Error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ──────────────── LOGIC: SELECTION ────────────────

  void _selectUser(UserModel user) {
    if (_activeUser != null) return; 
    setState(() {
      _selectedUser = user;
      _pinCode = ""; 
    });
    _resetInactivityTimer();
  }

  void _cancelSelection() {
    _inactivityTimer?.cancel();
    setState(() {
      _selectedUser = null;
      _activeUser = null;
      _pinCode = "";
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 30), _cancelSelection);
  }

  // ──────────────── LOGIC: PIN & AUTH ────────────────
  
  void _onKeypadInput(String value) {
    if (_selectedUser == null) {
      DialogUtils.showToast(context, "Please select your profile on the right first.", icon: Icons.touch_app, accentColor: Colors.orange);
      return;
    }
    if (_activeUser != null) return; 
    
    if (_pinCode.length >= 4) return;

    setState(() => _pinCode += value);
    _resetInactivityTimer();

    if (_pinCode.length >= 4) {
      _attemptUnlock();
    }
  }

  void _onClear() => setState(() => _pinCode = "");

  void _onBackspace() {
    if (_pinCode.isNotEmpty) {
      setState(() => _pinCode = _pinCode.substring(0, _pinCode.length - 1));
    }
  }

  Future<void> _attemptUnlock() async {
    if (_selectedUser == null) return;
    
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300)); 

    final isValid = HashingUtils.verifyPin(_pinCode, _selectedUser!.pinHash);

    if (isValid) {
      _fetchTodayLog(_selectedUser!);
      setState(() {
        _activeUser = _selectedUser;
        _selectedUser = null; 
        _pinCode = "";
      });
      _resetInactivityTimer();
    } else {
      if (mounted) {
        DialogUtils.showToast(context, "Invalid PIN", accentColor: Colors.red);
        setState(() => _pinCode = "");
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  void _fetchTodayLog(UserModel user) {
    final box = HiveService.attendanceBox;
    final today = DateTime.now();
    
    _todayLog = box.values.firstWhereOrNull((log) => 
      log.userId == user.id &&
      log.date.year == today.year &&
      log.date.month == today.month &&
      log.date.day == today.day
    );
  }

  // ──────────────── LOGIC: ACTIONS ────────────────

  Future<void> _performAction(String actionType) async {
    _inactivityTimer?.cancel();
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    
    String? proofImagePath;

    // ✅ CHECK: Only take picture if initialized
    if (actionType == 'Time In' && _cameraController != null && _isCameraInitialized) {
      try {
        final image = await _cameraController!.takePicture();
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = "proof_${_activeUser!.username}_${now.millisecondsSinceEpoch}.jpg";
        final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
        proofImagePath = savedImage.path;
        LoggerService.info("📸 Photo Captured: $proofImagePath");
      } catch (e) {
        LoggerService.error("Camera Capture Failed: $e");
      }
    }

    if (actionType == 'Time In') {
      final newLog = AttendanceLogModel(
        id: "${_activeUser!.id}_${todayDate.millisecondsSinceEpoch}",
        userId: _activeUser!.id,
        date: todayDate,
        timeIn: now,
        status: AttendanceStatus.onTime,
        hourlyRateSnapshot: _activeUser!.hourlyRate,
        proofImage: proofImagePath,
      );
      await HiveService.attendanceBox.put(newLog.id, newLog);
      _todayLog = newLog;
      _syncLog(newLog);
      _showSuccess("Timed In at ${DateFormat('hh:mm a').format(now)}");
    } 
    else if (_todayLog != null) {
      switch (actionType) {
        case 'Break Out': _todayLog!.breakStart = now; break;
        case 'Break In': _todayLog!.breakEnd = now; break;
        case 'Time Out': 
          _todayLog!.timeOut = now; 
          _todayLog!.status = AttendanceStatus.onTime; 
          break;
      }
      await _todayLog!.save();
      _syncLog(_todayLog!);
      _showSuccess("$actionType recorded at ${DateFormat('hh:mm a').format(now)}");
    }

    setState(() => _isLoading = false);
    await Future.delayed(const Duration(seconds: 2));
    if(mounted) _cancelSelection(); 
  }

  void _syncLog(AttendanceLogModel log) {
    SupabaseSyncService.addToQueue(
      table: 'attendance_logs',
      action: 'UPSERT',
      data: {
        'id': log.id,
        'user_id': log.userId,
        'date': log.date.toIso8601String(),
        'time_in': log.timeIn.toIso8601String(),
        'time_out': log.timeOut?.toIso8601String(),
        'break_start': log.breakStart?.toIso8601String(),
        'break_end': log.breakEnd?.toIso8601String(),
        'status': log.status.name,
        'hourly_rate_snapshot': log.hourlyRateSnapshot,
        'proof_image': log.proofImage,
      }
    );
  }

  void _showSuccess(String message) {
    DialogUtils.showToast(context, message, icon: Icons.check_circle);
  }

  // ──────────────── UI BUILDERS ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT: CLOCK & PIN ───
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: Column(
                  children: [
                    _buildClock(),
                    const Divider(height: 40),
                    
                    Expanded(
                      child: _activeUser != null 
                        ? _buildLoggedInProfile() 
                        : _buildPinEntry()
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            // ─── RIGHT: USER GRID OR ACTION GRID ───
            Expanded(
              flex: 6,
              child: _activeUser != null
                  ? _buildActionGrid(context) 
                  : _buildUserGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClock() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          crossAxisAlignment: CrossAxisAlignment.baseline, 
          textBaseline: TextBaseline.alphabetic, 
          children: [
            Text(
              DateFormat('hh:mm').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 64, 
                fontWeight: FontWeight.w200, 
                color: ThemeConfig.primaryGreen, 
                height: 1
              ),
            ),
            const SizedBox(width: 8), 
            Text(
              DateFormat('a').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                color: ThemeConfig.secondaryGreen
              ),
            ),
            const SizedBox(width: 24), 
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // TOP SECTION
        Expanded(
          child: Center(
            child: _selectedUser == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app, size: 40, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text("Select your profile\non the right ➜", style: FontConfig.body(context).copyWith(color: Colors.grey, height: 1.2, fontWeight: FontWeight.bold)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lock Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline, size: 28, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),

                      // Name & Dots
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hello, ${_selectedUser!.fullName.split(' ').first}", 
                            style: FontConfig.h2(context).copyWith(fontSize: 20)
                          ),
                          const SizedBox(height: 6),
                          
                          // PIN Dots
                          SizedBox(
                            height: 12,
                            child: Row(
                              children: List.generate(4, (index) {
                                final filled = index < _pinCode.length;
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: filled ? ThemeConfig.primaryGreen : Colors.grey[300],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),

        // KEYPAD
        SizedBox(
          width: 400,
          height: 320,
          child: NumericPad(
            onInput: _onKeypadInput,
            onClear: _onClear,
            onBackspace: _onBackspace,
          ),
        ),

        const SizedBox(height: 20),
        
        SizedBox(
          height: 40,
          child: _selectedUser != null 
            ? TextButton(onPressed: _cancelSelection, child: const Text("Cancel Selection", style: TextStyle(color: Colors.redAccent)))
            : null,
        ),
      ],
    );
  }

  Widget _buildLoggedInProfile() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Live Camera Feed (Safe Check)
        if (_cameraController != null && _isCameraInitialized)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ThemeConfig.primaryGreen, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))
                ],
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          const Expanded(
            child: Center(child: Icon(Icons.no_photography, size: 50, color: Colors.grey)),
          ),

        // Profile Info
        Row(
          mainAxisAlignment: MainAxisAlignment.center,   
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            const Icon(Icons.verified_user, size: 60, color: ThemeConfig.primaryGreen),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Text(_activeUser!.fullName, style: FontConfig.h2(context)),
                Text(_activeUser!.role.name.toUpperCase(), style: FontConfig.caption(context)),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Logout Button
        BasicButton(
          label: "Logout",
          type: AppButtonType.secondary,
          onPressed: _cancelSelection,
        )
      ],
    );
  }

  // ─── RIGHT PANEL WIDGETS ───

  Widget _buildUserGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Who is logging in?", style: FontConfig.h2(context)),
        const SizedBox(height: 20),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: HiveService.userBox.listenable(),
            builder: (context, Box<UserModel> box, _) {
              final users = box.values.where((u) => u.isActive).toList();
              
              if (users.isEmpty) return const Center(child: Text("No active users found."));

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSelected = _selectedUser?.id == user.id;

                  return Material(
                    color: isSelected ? ThemeConfig.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    elevation: isSelected ? 8 : 2,
                    child: InkWell(
                      onTap: () => _selectUser(user),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: isSelected ? Colors.white : ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                            child: Text(
                              user.fullName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 26, 
                                fontWeight: FontWeight.bold, 
                                color: isSelected ? ThemeConfig.primaryGreen : ThemeConfig.primaryGreen
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.fullName, 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: isSelected ? Colors.white : Colors.black87
                            ),
                            textAlign: TextAlign.center, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.role.name.toUpperCase(), 
                            style: TextStyle(
                              fontSize: 12, 
                              color: isSelected ? Colors.white70 : Colors.grey
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    final bool hasTimeIn = _todayLog != null;
    final bool hasTimeOut = _todayLog?.timeOut != null;
    final bool isOnBreak = _todayLog?.breakStart != null && _todayLog?.breakEnd == null;
    final bool finishedBreak = _todayLog?.breakEnd != null;

    final bool canTimeIn = !hasTimeIn;
    final bool canBreakOut = hasTimeIn && !hasTimeOut && !isOnBreak && !finishedBreak;
    final bool canBreakIn = isOnBreak;
    final bool canTimeOut = hasTimeIn && !hasTimeOut && !isOnBreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Header
        ContainerCard(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Current Status", style: FontConfig.caption(context)),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(hasTimeIn, hasTimeOut, isOnBreak),
                      style: FontConfig.h2(context).copyWith(fontSize: 28),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isOnBreak ? Colors.orange : (hasTimeIn && !hasTimeOut ? Colors.green : Colors.grey),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOnBreak ? "ON BREAK" : (hasTimeIn && !hasTimeOut ? "WORKING" : "OFF DUTY"),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
        
        const SizedBox(height: 30),

        // Buttons Grid
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 20, crossAxisSpacing: 20,
            childAspectRatio: 1.5,
            children: [
              _buildActionButton("TIME IN", Icons.login, Colors.green, canTimeIn, () => _performAction('Time In')),
              _buildActionButton("TIME OUT", Icons.logout, Colors.redAccent, canTimeOut, () => _performAction('Time Out')),
              _buildActionButton("BREAK OUT", Icons.coffee, Colors.orange, canBreakOut, () => _performAction('Break Out')),
              _buildActionButton("BREAK IN", Icons.work_history, Colors.blue, canBreakIn, () => _performAction('Break In')),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(bool hasIn, bool hasOut, bool onBreak) {
    if (!hasIn) return "Not clocked in yet.";
    if (hasOut) return "Shift completed.";
    if (onBreak) return "Currently on break.";
    return "Clocked In at ${DateFormat('hh:mm a').format(_todayLog!.timeIn)}";
  }

  Widget _buildActionButton(String label, IconData icon, Color color, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? color : Colors.grey[300],
      borderRadius: BorderRadius.circular(20),
      elevation: enabled ? 4 : 0,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: enabled ? Colors.white : Colors.grey[500]),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: enabled ? Colors.white : Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}