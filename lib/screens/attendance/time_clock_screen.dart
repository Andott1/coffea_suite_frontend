import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/user_model.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/hashing_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/numeric_pad.dart';

class TimeClockScreen extends StatefulWidget {
  const TimeClockScreen({super.key});

  @override
  State<TimeClockScreen> createState() => _TimeClockScreenState();
}

class _TimeClockScreenState extends State<TimeClockScreen> {
  // ──────────────── STATE ────────────────
  String _pinCode = "";
  bool _isLoading = false;
  
  // If null, we are in "Locked/Idle" mode.
  // If set, we are in "Employee Action" mode.
  UserModel? _activeUser; 
  AttendanceLogModel? _todayLog;

  // For auto-logout timer
  Timer? _inactivityTimer;

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  // ──────────────── LOGIC: PIN ENTRY ────────────────
  
  void _onKeypadInput(String value) {
    if (_activeUser != null) return; // Keypad disabled when user is logged in
    if (_pinCode.length >= 6) return; // Max PIN length

    setState(() {
      _pinCode += value;
    });

    // Auto-submit if 4 digits (standard) or manual enter could be added
    // For now, let's check continuously if valid user matches
    _attemptUnlock();
  }

  void _onClear() {
    setState(() => _pinCode = "");
  }

  void _onBackspace() {
    if (_pinCode.isNotEmpty) {
      setState(() => _pinCode = _pinCode.substring(0, _pinCode.length - 1));
    }
  }

  Future<void> _attemptUnlock() async {
    if (_pinCode.length < 4) return; 

    setState(() => _isLoading = true);

    // Simulate brief delay for security/feel
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final users = HiveService.userBox.values;
      
      // Find user with matching PIN
      final user = users.firstWhereOrNull(
        (u) => HashingUtils.verifyPin(_pinCode, u.pinHash) && u.isActive
      );

      if (user != null) {
        // ✅ Success: Login and fetch today's log
        _fetchTodayLog(user);
        setState(() {
          _activeUser = user;
          _pinCode = ""; // Clear for security
        });
        _startInactivityTimer();
      } else {
        // Only shake/error if it's 4+ digits and wrong
        if (_pinCode.length >= 4) {
           if (mounted) DialogUtils.showToast(context, "Invalid PIN", accentColor: Colors.red);
           setState(() => _pinCode = "");
        }
      }
    } catch (e) {
      print("Auth Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fetchTodayLog(UserModel user) {
    final box = HiveService.attendanceBox;
    final today = DateTime.now();
    
    // Find log for this user & this day
    _todayLog = box.values.firstWhereOrNull((log) => 
      log.userId == user.id &&
      log.date.year == today.year &&
      log.date.month == today.month &&
      log.date.day == today.day
    );
  }

  void _logout() {
    _inactivityTimer?.cancel();
    setState(() {
      _activeUser = null;
      _todayLog = null;
      _pinCode = "";
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    // Auto-logout after 30 seconds of inactivity to protect privacy
    _inactivityTimer = Timer(const Duration(seconds: 30), _logout);
  }

  // ──────────────── LOGIC: ATTENDANCE ACTIONS ────────────────

  Future<void> _performAction(String actionType) async {
    _inactivityTimer?.cancel(); // Stop timer while processing
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day); // Midnight

    // 1. CREATE NEW LOG (TIME IN)
    if (actionType == 'Time In') {
      final newLog = AttendanceLogModel(
        id: "${_activeUser!.id}_${todayDate.millisecondsSinceEpoch}",
        userId: _activeUser!.id,
        date: todayDate,
        timeIn: now,
        status: AttendanceStatus.onTime, // Could verify 9:00 AM here logic
        hourlyRateSnapshot: _activeUser!.hourlyRate, // 💰 Snapshot rate
      );
      await HiveService.attendanceBox.put(newLog.id, newLog);
      _todayLog = newLog;

      final logToSync = _todayLog ?? newLog;

      SupabaseSyncService.addToQueue(
        table: 'attendance_logs',
        action: 'UPSERT',
        data: {
          'id': logToSync.id,
          'user_id': logToSync.userId,
          'date': logToSync.date.toIso8601String(),
          'time_in': logToSync.timeIn.toIso8601String(),
          'time_out': logToSync.timeOut?.toIso8601String(),
          'break_start': logToSync.breakStart?.toIso8601String(),
          'break_end': logToSync.breakEnd?.toIso8601String(),
          'status': logToSync.status.name,
        }
      );

      _showSuccess("Timed In at ${DateFormat('hh:mm a').format(now)}");
    } 
    
    // 2. UPDATE EXISTING LOG
    else if (_todayLog != null) {
      switch (actionType) {
        case 'Break Out':
          _todayLog!.breakStart = now;
          break;
        case 'Break In':
          _todayLog!.breakEnd = now;
          break;
        case 'Time Out':
          _todayLog!.timeOut = now;
          _todayLog!.status = AttendanceStatus.onTime; // Or calculate logic
          break;
      }
      _todayLog!.save(); // HiveObject save
      _showSuccess("$actionType recorded at ${DateFormat('hh:mm a').format(now)}");
    }

    setState(() => _isLoading = false);
    
    // Delay then logout automatically
    await Future.delayed(const Duration(seconds: 2));
    if(mounted) _logout();
  }

  void _showSuccess(String message) {
    DialogUtils.showToast(context, message, icon: Icons.check_circle);
  }

  // ──────────────── UI BUILDERS ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // ─── LEFT: CLOCK & PIN ───
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Digital Clock
                  StreamBuilder(
                    stream: Stream.periodic(const Duration(seconds: 1)),
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            DateFormat('hh:mm').format(DateTime.now()),
                            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w200, color: ThemeConfig.primaryGreen, height: 1),
                          ),
                          Text(
                            DateFormat('a').format(DateTime.now()),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ThemeConfig.secondaryGreen),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: const TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const Spacer(),

                  if (_activeUser == null) ...[
                    // PIN Display Dots
                    SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final filled = index < _pinCode.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 16, height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled ? ThemeConfig.primaryGreen : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Keypad
                    SizedBox(
                      width: 300,
                      height: 350,
                      child: NumericPad(
                        onInput: _onKeypadInput,
                        onClear: _onClear,
                        onBackspace: _onBackspace,
                      ),
                    ),
                  ] else ...[
                    // User Profile View (When Logged In)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeConfig.lightGray,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 80, color: ThemeConfig.primaryGreen),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _activeUser!.fullName,
                      style: FontConfig.h2(context),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _activeUser!.role.name.toUpperCase(),
                      style: FontConfig.caption(context),
                    ),
                    const Spacer(),
                    BasicButton(
                      label: "Cancel / Logout",
                      type: AppButtonType.secondary,
                      onPressed: _logout,
                    )
                  ]
                ],
              ),
            ),
          ),

          // ─── RIGHT: DASHBOARD / ACTIONS ───
          Expanded(
            flex: 6,
            child: Container(
              color: ThemeConfig.lightGray,
              padding: const EdgeInsets.all(40),
              child: _activeUser == null
                  ? _buildIdleMessage(context)
                  : _buildActionGrid(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleMessage(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app, size: 100, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          "Enter your PIN to clock in/out",
          style: FontConfig.h2(context).copyWith(color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    // Determine Button States
    final bool hasTimeIn = _todayLog != null;
    final bool hasTimeOut = _todayLog?.timeOut != null;
    final bool isOnBreak = _todayLog?.breakStart != null && _todayLog?.breakEnd == null;
    final bool finishedBreak = _todayLog?.breakEnd != null;

    // 1. Can Time In? (If no log yet)
    final bool canTimeIn = !hasTimeIn;

    // 2. Can Break Out? (If Timed In, Not Timed Out, Not currently on break, Hasn't taken break yet)
    final bool canBreakOut = hasTimeIn && !hasTimeOut && !isOnBreak && !finishedBreak;

    // 3. Can Break In? (If currently on break)
    final bool canBreakIn = isOnBreak;

    // 4. Can Time Out? (If Timed In, Not Timed Out, Not currently on break)
    final bool canTimeOut = hasTimeIn && !hasTimeOut && !isOnBreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              // Visual Indicator
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

        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.3,
            children: [
              _buildActionButton(
                "TIME IN", 
                Icons.login, 
                Colors.green, 
                canTimeIn, 
                () => _performAction('Time In')
              ),
              _buildActionButton(
                "TIME OUT", 
                Icons.logout, 
                Colors.redAccent, 
                canTimeOut, 
                () => _performAction('Time Out')
              ),
              _buildActionButton(
                "BREAK OUT", 
                Icons.coffee, 
                Colors.orange, 
                canBreakOut, 
                () => _performAction('Break Out')
              ),
              _buildActionButton(
                "BREAK IN", 
                Icons.work_history, 
                Colors.blue, 
                canBreakIn, 
                () => _performAction('Break In')
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(bool hasIn, bool hasOut, bool onBreak) {
    if (!hasIn) return "Not clocked in yet.";
    if (hasOut) return "Shift completed today.";
    if (onBreak) return "You are currently on break.";
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
            Text(
              label,
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: enabled ? Colors.white : Colors.grey[500]
              ),
            )
          ],
        ),
      ),
    );
  }
}