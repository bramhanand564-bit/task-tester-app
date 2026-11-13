import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_model.dart';
import '../services/firebase_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final AppTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with WidgetsBindingObserver {
  bool isLoadingProgress = true;
  bool isClaiming = false;

  bool joinedGroup = false;
  bool optedInStore = false;
  int completedDays = 0;
  String lastClaimDate = '';

  int? timerStartMs;
  int targetSeconds = 600;
  int elapsedSeconds = 0;
  Timer? _uiTimer;

  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    targetSeconds = widget.task.requiredMinutesPerDay * 60;
    _loadTaskProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimerCalculations();
    }
  }

  String get _id => widget.task.id;
  String get _uid => FirebaseService.currentUid;

  Future<void> _loadTaskProgress() async {
    try {
      await FirebaseService.updateTaskStep(task: widget.task);
      final prog = await FirebaseService.getSingleTaskProgress(_id);
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;
      setState(() {
        joinedGroup = prog['joinedGroup'] == true;
        optedInStore = prog['optedInStore'] == true;
        completedDays = (prog['completedDays'] as num?)?.toInt() ?? 0;
        lastClaimDate = prog['lastClaimDate']?.toString() ?? '';
        timerStartMs = prefs.getInt('timer_start_ms_${_uid}_$_id');
        targetSeconds = prefs.getInt('timer_target_sec_${_uid}_$_id') ??
            (widget.task.requiredMinutesPerDay * 60);
        isLoadingProgress = false;
      });

      if (timerStartMs != null) {
        _startUiTicker();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingProgress = false);
      _showSnack('डेटा लोड करने में दिक्कत आई: $e', isError: true);
    }
  }

  void _syncTimerCalculations() {
    if (timerStartMs == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffSec = ((nowMs - timerStartMs!) / 1000).floor();

    if (!mounted) return;
    setState(() {
      elapsedSeconds = diffSec.clamp(0, targetSeconds);
    });

    if (elapsedSeconds >= targetSeconds) {
      _uiTimer?.cancel();
    }
  }

  void _startUiTicker() {
    _uiTimer?.cancel();
    _syncTimerCalculations();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncTimerCalculations();
    });
  }

  Future<void> _openExternalUrl(String url, bool isGroupStep) async {
    final fixedUrl = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(fixedUrl);
    if (uri == null) {
      _showSnack('लिंक सही नहीं है!', isError: true);
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      await FirebaseService.updateTaskStep(
        task: widget.task,
        joinedGroup: isGroupStep ? true : null,
        optedInStore: isGroupStep ? null : true,
      );

      if (!mounted) return;
      setState(() {
        if (isGroupStep) {
          joinedGroup = true;
        } else {
          optedInStore = true;
        }
      });

      if (!launched) {
        _showSnack('लिंक नहीं खुल सका, कृपया ब्राउज़र चेक करें।', isError: true);
      }
    } catch (e) {
      _showSnack('लिंक खोलने में दिक्कत आई: $e', isError: true);
    }
  }

  Future<void> _startTimer({required bool isDemoTenSeconds}) async {
    if (!joinedGroup || !optedInStore) {
      _showSnack(
        'पहले Step 1 (Group Join) और Step 2 (Opt-in) बटन पर क्लिक करें!',
        isError: true,
      );
      return;
    }

    if (isCampaignFinished) {
      _showSnack('यह टास्क पहले ही पूरा हो चुका है!');
      return;
    }

    if (claimedToday) {
      _showSnack(
        'आज का टास्क पूरा हो चुका है! अब कल अगला दिन क्लेम करें।',
        isError: true,
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sec = isDemoTenSeconds ? 10 : (widget.task.requiredMinutesPerDay * 60);

    await prefs.setInt('timer_start_ms_${_uid}_$_id', nowMs);
    await prefs.setInt('timer_target_sec_${_uid}_$_id', sec);

    if (!mounted) return;
    setState(() {
      timerStartMs = nowMs;
      targetSeconds = sec;
      elapsedSeconds = 0;
    });

    _startUiTicker();
    _showSnack(
      isDemoTenSeconds
          ? '⚡ Demo 10-Second Timer शुरू हो गया!'
          : '⏱️ ${widget.task.requiredMinutesPerDay} मिनट का टाइमर शुरू! अब टेस्ट ऐप ओपन करके चलाएं।',
    );
  }

  bool get isCampaignFinished => completedDays >= widget.task.totalTestingDays;
  bool get claimedToday => lastClaimDate == FirebaseService.todayStr();
  bool get isTimerRunning => timerStartMs != null && elapsedSeconds < targetSeconds;
  bool get isTimerCompleted => timerStartMs != null && elapsedSeconds >= targetSeconds;
  bool get isFinalDay => (completedDays + 1) == widget.task.totalTestingDays;

  Future<void> _claimDailyReward() async {
    if (!isTimerCompleted || isClaiming) return;

    if (isFinalDay && _feedbackController.text.trim().length < 5) {
      _showSnack(
        'आखिरी दिन पूरा करने के लिए कृपया ऐप के बारे में छोटा सा फीडबैक लिखें!',
        isError: true,
      );
      return;
    }

    setState(() => isClaiming = true);
    try {
      final earnedCoins = await FirebaseService.claimTaskDayReward(
        task: widget.task,
        feedback: _feedbackController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('timer_start_ms_${_uid}_$_id');

      if (!mounted) return;
      setState(() {
        completedDays += 1;
        lastClaimDate = FirebaseService.todayStr();
        timerStartMs = null;
        elapsedSeconds = 0;
        isClaiming = false;
      });

      _showSnack(
        completedDays == widget.task.totalTestingDays
            ? '🏆 कमाल! पूरे ${widget.task.totalTestingDays} दिन पूरे हुए और +$earnedCoins Coins मिले!'
            : '🎉 Day $completedDays पूरा! आपको +$earnedCoins Coins मिल गए!',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isClaiming = false);
      _showSnack('क्लेम करने में दिक्कत आई: $e', isError: true);
    }
  }

  Future<void> _resetLocalTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_start_ms_${_uid}_$_id');
    _uiTimer?.cancel();
    if (!mounted) return;
    setState(() {
      timerStartMs = null;
      elapsedSeconds = 0;
    });
    _showSnack('लोकल टाइमर रीसेट हो गया!');
  }

  String _formatDuration(int totalSec) {
    final min = (totalSec ~/ 60).toString().padLeft(2, '0');
    final sec = (totalSec % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds =
        (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);
    final progressPercent =
        targetSeconds > 0 ? (elapsedSeconds / targetSeconds).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.appName),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _resetLocalTimer,
            icon: const Icon(Icons.timer_off_outlined),
            tooltip: 'Reset Timer',
          ),
        ],
      ),
      body: isLoadingProgress
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.android,
                              size: 30,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.task.appName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Package: ${widget.task.packageName}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoBadge('रोज़ाना: ${widget.task.dailyCoins} 🪙'),
                          _infoBadge(
                              'बोनस: ${widget.task.completionBonusCoins} 🪙'),
                          _infoBadge(
                            'कुल: ₹${DemoTaskData.coinsToRupees(widget.task.totalPotentialCoins)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Testing Progress (${widget.task.totalTestingDays} Days)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '$completedDays / ${widget.task.totalTestingDays} Done',
                            style: const TextStyle(
                              color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(widget.task.totalTestingDays,
                            (index) {
                          final dayNum = index + 1;
                          final isDone = dayNum <= completedDays;
                          final isTodayTarget = dayNum == completedDays + 1;

                          return Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.green
                                  : (isTodayTarget
                                      ? Colors.indigo.shade50
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDone
                                    ? Colors.green
                                    : (isTodayTarget
                                        ? const Color(0xFF4F46E5)
                                        : Colors.grey.shade300),
                                width: isTodayTarget ? 2 : 1,
                              ),
                            ),
                            child: isDone
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : Text(
                                    'D$dayNum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isTodayTarget
                                          ? const Color(0xFF4F46E5)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Play Store Closed Testing स्टेप्स:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      _buildStepTile(
                        stepNum: 'Step 1',
                        title: 'Tester Google Group ज्वाइन करें',
                        subtitle: 'ताकि Play Store आपको टेस्टर मान ले',
                        isDone: joinedGroup,
                        buttonLabel: joinedGroup ? 'Joined ✅' : 'Join Group',
                        onTap: () =>
                            _openExternalUrl(widget.task.googleGroupUrl, true),
                      ),
                      const Divider(height: 20),
                      _buildStepTile(
                        stepNum: 'Step 2',
                        title: 'Opt-in करें और ऐप डाउनलोड करें',
                        subtitle:
                            'Play Store से "Become a Tester" दबाकर इंस्टॉल करें',
                        isDone: optedInStore,
                        buttonLabel: optedInStore ? 'Opened ✅' : 'Opt-in App',
                        onTap: () => _openExternalUrl(
                            widget.task.playStoreOptInUrl, false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isTimerCompleted
                          ? Colors.green
                          : const Color(0xFF4F46E5).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Step 3: Play Time Tracker',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCampaignFinished
                                  ? 'Completed 🏆'
                                  : 'Day ${completedDays + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isCampaignFinished
                            ? 'सभी दिन पूरे हुए!'
                            : (claimedToday
                                ? 'आज का क्लेम हो चुका ✅'
                                : (isTimerCompleted
                                    ? '00:00 (समय पूरा हुआ!)'
                                    : _formatDuration(remainingSeconds))),
                        style: TextStyle(
                          fontSize:
                              (isCampaignFinished || claimedToday) ? 20 : 34,
                          fontWeight: FontWeight.bold,
                          color: isTimerCompleted
                              ? Colors.green
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: claimedToday || isCampaignFinished
                            ? 1.0
                            : progressPercent,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.grey.shade200,
                        color: isTimerCompleted || claimedToday
                            ? Colors.green
                            : const Color(0xFF4F46E5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isTimerRunning
                            ? 'अब डाउनलोड किए गए ऐप को ओपन करके खेलें। यह टाइमर बैकग्राउंड में भी गिनती चालू रखेगा!'
                            : 'बटन दबाकर टाइमर चालू करें और टेस्ट ऐप को ${widget.task.requiredMinutesPerDay} मिनट इस्तेमाल करें।',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 14),
                      if (isFinalDay && isTimerCompleted && !claimedToday) ...[
                        TextField(
                          controller: _feedbackController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                'आखिरी दिन का फीडबैक (Play Console के लिए)',
                            hintText:
                                'उदाहरण: App smooth chala, koi crash nahi mila.',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!isCampaignFinished && !claimedToday) ...[
                        if (timerStartMs == null) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _startTimer(isDemoTenSeconds: false),
                              icon: const Icon(Icons.timer),
                              label: Text(
                                'Start ${widget.task.requiredMinutesPerDay}-Min Timer',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                _startTimer(isDemoTenSeconds: true),
                            icon: const Icon(Icons.bolt, color: Colors.orange),
                            label: const Text(
                              '⚡ Demo Test: 10 सेकंड में टाइमर चेक करें',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ] else if (isTimerCompleted) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: isClaiming ? null : _claimDailyReward,
                              icon: const Icon(Icons.card_giftcard),
                              label: Text(
                                isClaiming
                                    ? 'Saving to Cloud...'
                                    : (isFinalDay
                                        ? 'Claim +${widget.task.dailyCoins + widget.task.completionBonusCoins} Coins (With Bonus!)'
                                        : 'Claim +${widget.task.dailyCoins} Coins'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            onPressed: _syncTimerCalculations,
                            icon: const Icon(Icons.sync),
                            label: const Text('Timer चल रहा है... Refresh करें'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'टास्क के पूरे निर्देश:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.task.instructions,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStepTile({
    required String stepNum,
    required String title,
    required String subtitle,
    required bool isDone,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: isDone ? Colors.green : Colors.indigo.shade50,
          child: Icon(
            isDone ? Icons.check : Icons.open_in_new,
            size: 18,
            color: isDone ? Colors.white : const Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNum: $title',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDone ? Colors.green : const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(buttonLabel, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
