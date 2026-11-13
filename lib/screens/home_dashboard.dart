import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../services/app_storage.dart';
import 'admin_panel_screen.dart';
import 'auth_screen.dart';
import 'task_detail_screen.dart';
import 'wallet_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _currentTabIndex = 0;
  int _walletRefreshKey = 0;
  String _selectedCategory = 'All';

  String name = 'Tester';
  String email = '';
  String referralCode = 'TASK000';
  String deviceId = 'DEV-0000';
  int coins = 0;
  bool checkedInToday = false;
  int checkInStreak = 0;

  List<AppTask> allTasks = [];
  Map<String, int> taskCompletedDays = {};
  Map<String, bool> taskStartedMap = {};
  Map<String, bool> taskClaimedTodayMap = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDashboardData() async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = await AppStorage.getAllTasks();
    final devId = await AppStorage.getOrCreateDeviceId();
    final lastCheckIn = prefs.getString('last_checkin_date') ?? '';
    final today = _getTodayDateString();

    final Map<String, int> daysMap = {};
    final Map<String, bool> startedMap = {};
    final Map<String, bool> claimedMap = {};

    for (final task in tasks) {
      final doneDays = prefs.getInt('completed_days_${task.id}') ?? 0;
      final started = (prefs.getBool('started_${task.id}') ?? false) ||
          doneDays > 0 ||
          (prefs.getInt('timer_start_ms_${task.id}') != null);
      final claimedToday =
          (prefs.getString('last_claim_date_${task.id}') ?? '') == today;

      daysMap[task.id] = doneDays;
      startedMap[task.id] = started;
      claimedMap[task.id] = claimedToday;
    }

    if (!mounted) return;
    setState(() {
      allTasks = tasks;
      deviceId = devId;
      name = prefs.getString('user_name') ?? 'Tester';
      email = prefs.getString('user_email') ?? '';
      referralCode = prefs.getString('my_referral_code') ?? 'TASK000';
      coins = prefs.getInt('user_coins') ?? 0;
      checkInStreak = prefs.getInt('checkin_streak') ?? 0;
      checkedInToday = (lastCheckIn == today);
      taskCompletedDays = daysMap;
      taskStartedMap = startedMap;
      taskClaimedTodayMap = claimedMap;
    });
  }

  Future<void> _claimDailyCheckIn() async {
    if (checkedInToday) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayDateString();
    const rewardCoins = 15;

    final newCoins = coins + rewardCoins;
    final newStreak = checkInStreak + 1;

    await prefs.setInt('user_coins', newCoins);
    await prefs.setString('last_checkin_date', today);
    await prefs.setInt('checkin_streak', newStreak);

    final history = prefs.getStringList('wallet_transactions') ?? [];
    history.insert(
      0,
      jsonEncode({
        'title': 'Daily Check-in Bonus (Day $newStreak)',
        'coins': rewardCoins,
        'type': 'credit',
        'date': today,
      }),
    );
    await prefs.setStringList('wallet_transactions', history);

    if (!mounted) return;
    setState(() {
      coins = newCoins;
      checkInStreak = newStreak;
      checkedInToday = true;
      _walletRefreshKey++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 बधाई हो! आज का +15 Daily Check-in Bonus मिल गया!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Referral Code "$referralCode" कॉपी हो गया!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyInviteMessage() {
    final msg =
        'नमस्ते! TaskEarn & Beta Tester ऐप पर नए ऐप्स को 10 मिनट टेस्ट करके रोज़ कॉइन और UPI कैश कमाएं! '
        'साइन अप के समय मेरा Referral Code "$referralCode" डालें और +25 एक्स्ट्रा कॉइन पाएं!';
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite मैसेज कॉपी हो गया! अब WhatsApp/Telegram पर भेजें।'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFaqDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('14-Day Testing के नियम & FAQ'),
        content: const SingleChildScrollView(
          child: Text(
            '1. सही Gmail डालें: जिस Gmail से साइन अप किया है, उसी से Play Store Opt-in करें।\n\n'
            '2. 10 मिनट टाइमर: टास्क पेज पर जाकर Start Timer दबाएं और टेस्ट ऐप को 10 मिनट इस्तेमाल करें।\n\n'
            '3. 14 दिन लगातार: बीच में ऐप अनइंस्टॉल न करें। 14वें दिन फीडबैक लिखने पर पूरा बोनस मिलेगा।\n\n'
            '4. Withdrawal: 200 Coins = ₹20 पूरे होते ही आप UPI या Redeem Code से पैसे निकाल सकते हैं।',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('समझ गया'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTaskDetail(AppTask task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
    await _loadDashboardData();
    if (mounted) setState(() => _walletRefreshKey++);
  }

  Future<void> _openAdminPanel() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
    );
    await _loadDashboardData();
    if (mounted) setState(() => _walletRefreshKey++);
  }

  // ---------------- TAB 1: HOME (TASKS) ----------------
  Widget _buildHomeTab() {
    final filteredTasks = _selectedCategory == 'All'
        ? allTasks
        : allTasks.where((t) => t.category == _selectedCategory).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'नमस्ते, $name 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '10 Coins = ₹1.00 • Streak: $checkInStreak दिन 🔥',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => setState(() => _currentTabIndex = 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🪙 $coins',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        Text(
                          '≈ ₹${DemoTaskData.coinsToRupees(coins)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Check-in Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: checkedInToday
                    ? Colors.green.shade200
                    : Colors.amber.shade300,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: checkedInToday
                      ? Colors.green.shade50
                      : Colors.amber.shade50,
                  child: Icon(
                    checkedInToday ? Icons.check_circle : Icons.card_giftcard,
                    color: checkedInToday ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Check-in Bonus',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        checkedInToday
                            ? 'आज का बोनस क्लेम हो चुका है!'
                            : 'रोज़ ऐप खोलने पर +15 Coins फ्री पाएं',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: checkedInToday ? null : _claimDailyCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        checkedInToday ? Colors.grey.shade300 : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(checkedInToday ? 'Claimed ✅' : 'Claim +15'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Tasks चुनें और कमाएं',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', '14-Day Testing', 'Quick 10-Min'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          if (filteredTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('इस कैटेगरी में कोई टास्क उपलब्ध नहीं है।'),
              ),
            )
          else
            ...filteredTasks.map((task) {
              final doneDays = taskCompletedDays[task.id] ?? 0;
              final isStarted = taskStartedMap[task.id] ?? false;
              final isFinished = doneDays >= task.totalTestingDays;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: task.isLongTermTesting
                                  ? Colors.indigo.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              task.isLongTermTesting
                                  ? Icons.science_outlined
                                  : Icons.flash_on,
                              color: task.isLongTermTesting
                                  ? const Color(0xFF4F46E5)
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.appName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${task.requiredMinutesPerDay} Min/Day • ${task.totalTestingDays} ${task.totalTestingDays > 1 ? "Days" : "Day"}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+${task.totalPotentialCoins} 🪙',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isStarted
                                  ? 'Progress: $doneDays / ${task.totalTestingDays} Days'
                                  : task.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: isStarted
                                    ? const Color(0xFF4F46E5)
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _openTaskDetail(task),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFinished
                                  ? Colors.green
                                  : const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              isFinished
                                  ? 'Completed 🏆'
                                  : (isStarted ? 'Continue →' : 'Start Task →'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------- TAB 2: MY ACTIVE TESTS ----------------
  Widget _buildMyTestsTab() {
    final activeTasks =
        allTasks.where((t) => taskStartedMap[t.id] == true).toList();

    if (activeTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 72,
                color: Colors.indigo.shade200,
              ),
              const SizedBox(height: 16),
              const Text(
                'अभी कोई टेस्ट शुरू नहीं किया है',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Home (Tasks) टैब में जाकर किसी भी ऐप पर "Start Task" दबाएं, वह यहाँ ट्रैक होने लगेगा।',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeTasks.length,
      itemBuilder: (context, index) {
        final task = activeTasks[index];
        final doneDays = taskCompletedDays[task.id] ?? 0;
        final claimedToday = taskClaimedTodayMap[task.id] ?? false;
        final isFinished = doneDays >= task.totalTestingDays;
        final ratio = (doneDays / task.totalTestingDays).clamp(0.0, 1.0);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openTaskDetail(task),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isFinished
                              ? Colors.green.shade50
                              : (claimedToday
                                  ? Colors.blue.shade50
                                  : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isFinished
                              ? '100% पूरा 🏆'
                              : (claimedToday
                                  ? 'आज का हो गया ✅'
                                  : 'आज 10 Min बाकी ⏳'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isFinished
                                ? Colors.green.shade800
                                : (claimedToday
                                    ? Colors.blue.shade800
                                    : Colors.orange.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(6),
                    backgroundColor: Colors.grey.shade200,
                    color: isFinished ? Colors.green : const Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Day $doneDays / ${task.totalTestingDays} Completed • टैप करके खोलें →',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- TAB 3: FULL WALLET ----------------
  Widget _buildWalletTab() {
    return WalletScreen(
      key: ValueKey(_walletRefreshKey),
      onBalanceChanged: _loadDashboardData,
    );
  }

  // ---------------- TAB 4: PROFILE, ADMIN & RULES ----------------
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF4F46E5),
                  child: Icon(Icons.person, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Device Verified: $deviceId ✅',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Refer & Earn Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Refer & Earn (+25 Coins प्रति दोस्त)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'अपने दोस्तों को जोड़ें ताकि 14-दिन की टेस्टिंग जल्दी पूरी हो सके:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text(
                        referralCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _copyReferralCode,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyInviteMessage,
                  icon: const Icon(Icons.share),
                  label: const Text('WhatsApp / Telegram Invite मैसेज कॉपी करें'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Admin Panel, Rules & Logout Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1E293B),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
                title: const Text(
                  'Admin Panel (Owner Only)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('नए ऐप्स जोड़ें, पेमेंट अप्रूव करें (PIN: 1234)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _openAdminPanel,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Color(0xFF4F46E5)),
                title: const Text('14-Day Testing के नियम & FAQ'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _showFaqDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout करें',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      _buildMyTestsTab(),
      _buildWalletTab(),
      _buildProfileTab(),
    ];

    final titles = [
      'TaskEarn & Beta Tester',
      'My 14-Day Tests',
      'My Wallet',
      'Profile & Admin',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentTabIndex]),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openAdminPanel,
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Panel',
          ),
        ],
      ),
      body: tabs[_currentTabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'My Tests',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
