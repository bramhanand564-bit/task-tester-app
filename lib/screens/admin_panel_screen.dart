import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../services/app_storage.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool isUnlocked = false;
  String savedPin = '1234';

  List<AppTask> allTasks = [];
  List<Map<String, dynamic>> withdrawals = [];
  String testerEmail = '';
  String testerName = '';
  String deviceId = '';
  int userCoins = 0;

  @override
  void initState() {
    super.initState();
    _initAdminData();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _initAdminData() async {
    final pin = await AppStorage.getAdminPin();
    final tasks = await AppStorage.getAllTasks();
    final payouts = await AppStorage.getWithdrawals();
    final prefs = await SharedPreferences.getInstance();
    final devId = await AppStorage.getOrCreateDeviceId();

    if (!mounted) return;
    setState(() {
      savedPin = pin;
      allTasks = tasks;
      withdrawals = payouts;
      testerEmail = prefs.getString('user_email') ?? 'No Email';
      testerName = prefs.getString('user_name') ?? 'Tester';
      userCoins = prefs.getInt('user_coins') ?? 0;
      deviceId = devId;
    });
  }

  void _verifyPin() {
    if (_pinController.text.trim() == savedPin) {
      setState(() => isUnlocked = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('गलत Admin PIN! (डिफ़ॉल्ट PIN: 1234)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAddTaskSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddTaskSheet(
        onSave: (newTask) async {
          await AppStorage.addCustomTask(newTask);
          await _initAdminData();
        },
      ),
    );
  }

  Future<void> _deleteTask(AppTask task) async {
    await AppStorage.deleteTask(task.id);
    await _initAdminData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${task.appName}" हटा दिया गया!')),
    );
  }

  Future<void> _handlePayoutAction(
    Map<String, dynamic> item,
    String newStatus,
    bool refund,
  ) async {
    final rawIndex = item['rawIndex'] as int;
    await AppStorage.updateWithdrawalStatus(
      rawIndex: rawIndex,
      newStatus: newStatus,
      refundCoins: refund,
    );
    await _initAdminData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          refund
              ? 'रिक्वेस्ट रिजेक्ट हुई और कॉइन्स यूज़र के वॉलेट में रिफंड हो गए!'
              : 'पेमेंट स्टेटस "$newStatus" अपडेट हो गया!',
        ),
        backgroundColor: refund ? Colors.orange.shade800 : Colors.green,
      ),
    );
  }

  void _copyTesterGmail() {
    Clipboard.setData(ClipboardData(text: testerEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Play Console के लिए "$testerEmail" कॉपी हो गया!')),
    );
  }

  Future<void> _changePinDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin PIN बदलें'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'नया 4-6 अंकों का PIN डालें',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().length >= 4) {
                await AppStorage.setAdminPin(controller.text.trim());
                await _initAdminData();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('नया Admin PIN सेव हो गया!')),
                  );
                }
              }
            },
            child: const Text('सेव करें'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. यदि अनलॉक नहीं है तो PIN स्क्रीन दिखाएं
    if (!isUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel Lock'),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(Icons.admin_panel_settings,
                          size: 36, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Admin Control Panel',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Demo PIN: $savedPin',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Admin PIN डालें',
                        hintText: '1234',
                      ),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _verifyPin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Unlock Admin Panel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2. अनलॉक होने के बाद पूरा 3-Tab Admin Panel
    final pendingCount = withdrawals
        .where((w) => (w['status']?.toString() ?? '').contains('Pending'))
        .length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _changePinDialog,
              icon: const Icon(Icons.key),
              tooltip: 'Change PIN',
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amberAccent,
            tabs: [
              Tab(text: 'Tasks (${allTasks.length})'),
              Tab(text: 'Payouts ($pendingCount)'),
              const Tab(text: 'Testers'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddTaskSheet,
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('नया ऐप जोड़ें'),
        ),
        body: TabBarView(
          children: [
            // TAB 1: MANAGE TASKS
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                if (allTasks.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('कोई टास्क नहीं है। नीचे "+ नया ऐप जोड़ें" दबाएं।'),
                    ),
                  ),
                ...allTasks.map((task) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade50,
                        child: const Icon(Icons.android, color: Color(0xFF4F46E5)),
                      ),
                      title: Text(
                        task.appName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${task.packageName}\n${task.requiredMinutesPerDay} Min • ${task.totalTestingDays} Days • +${task.totalPotentialCoins} 🪙',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteTask(task),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    await AppStorage.restoreDefaultTasks();
                    await _initAdminData();
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('डिफ़ॉल्ट डेमो ऐप्स वापस लाएं'),
                ),
              ],
            ),

            // TAB 2: WITHDRAWAL REQUESTS
            withdrawals.isEmpty
                ? const Center(
                    child: Text('अभी कोई Withdrawal रिक्वेस्ट नहीं आई है।'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: withdrawals.length,
                    itemBuilder: (context, index) {
                      final w = withdrawals[index];
                      final status = w['status']?.toString() ?? 'Pending';
                      final isPending = status.contains('Pending');
                      final amtCoins = (w['coins'] as num?)?.toInt() ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      w['title']?.toString() ?? 'Withdrawal',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${DemoTaskData.coinsToRupees(amtCoins)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Date: ${w['date']} • Coins: $amtCoins • Status: $status',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPending
                                      ? Colors.orange.shade800
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _handlePayoutAction(
                                          w,
                                          'Paid ✅',
                                          false,
                                        ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Mark Paid'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _handlePayoutAction(
                                          w,
                                          'Rejected (Refunded)',
                                          true,
                                        ),
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'Reject & Refund',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // TAB 3: TESTERS & PLAY CONSOLE EXPORT
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Tester (Google Play Console के लिए)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF4F46E5),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(testerName),
                          subtitle: Text('$testerEmail\nDevice ID: $deviceId'),
                          trailing: Text(
                            '🪙 $userCoins',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _copyTesterGmail,
                            icon: const Icon(Icons.copy),
                            label: const Text(
                              'Copy Gmail for Play Console Closed Testing',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Text(
                    '💡 Pro Tip: जब आप इसमें Firebase जोड़ेंगे, तो यहाँ दुनिया भर के सभी टेस्टर्स की पूरी Gmail लिस्ट और सभी के विड्रॉल रिक्वेस्ट एक साथ लाइव दिखेंगे!',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin द्वारा नया Task जोड़ने का फॉर्म
class _AddTaskSheet extends StatefulWidget {
  final Future<void> Function(AppTask task) onSave;

  const _AddTaskSheet({required this.onSave});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pkgCtrl = TextEditingController();
  final _groupCtrl = TextEditingController(
    text: 'https://groups.google.com/g/your-testers-group',
  );
  final _optInCtrl = TextEditingController(
    text: 'https://play.google.com/apps/testing/',
  );
  final _minsCtrl = TextEditingController(text: '10');
  final _daysCtrl = TextEditingController(text: '14');
  final _dailyCoinsCtrl = TextEditingController(text: '20');
  final _bonusCoinsCtrl = TextEditingController(text: '200');

  String category = '14-Day Testing';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pkgCtrl.dispose();
    _groupCtrl.dispose();
    _optInCtrl.dispose();
    _minsCtrl.dispose();
    _daysCtrl.dispose();
    _dailyCoinsCtrl.dispose();
    _bonusCoinsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final task = AppTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      appName: _nameCtrl.text.trim(),
      packageName: _pkgCtrl.text.trim(),
      category: category,
      googleGroupUrl: _groupCtrl.text.trim(),
      playStoreOptInUrl: _optInCtrl.text.trim(),
      requiredMinutesPerDay: int.tryParse(_minsCtrl.text.trim()) ?? 10,
      totalTestingDays: int.tryParse(_daysCtrl.text.trim()) ?? 14,
      dailyCoins: int.tryParse(_dailyCoinsCtrl.text.trim()) ?? 20,
      completionBonusCoins: int.tryParse(_bonusCoinsCtrl.text.trim()) ?? 200,
      instructions:
          '1. Google Group ज्वाइन करें।\n'
          '2. Play Store Opt-in लिंक से ऐप डाउनलोड करें।\n'
          '3. रोज़ ${_minsCtrl.text.trim()} मिनट ऐप चलाएं।\n'
          '4. ${_daysCtrl.text.trim()} दिन तक ऐप अनइंस्टॉल न करें।',
    );

    await widget.onSave(task);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'नया Play Store टेस्टिंग ऐप जोड़ें',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: ['14-Day Testing', 'Quick 10-Min'].map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: category == cat,
                      onSelected: (_) {
                        setState(() {
                          category = cat;
                          if (cat == 'Quick 10-Min') {
                            _daysCtrl.text = '1';
                            _bonusCoinsCtrl.text = '0';
                            _dailyCoinsCtrl.text = '50';
                          } else {
                            _daysCtrl.text = '14';
                            _bonusCoinsCtrl.text = '200';
                            _dailyCoinsCtrl.text = '20';
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ऐप का नाम (App Name)',
                  hintText: 'उदाहरण: My New Game',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'नाम लिखें' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pkgCtrl,
                decoration: const InputDecoration(
                  labelText: 'Package Name',
                  hintText: 'उदाहरण: com.myname.newgame',
                ),
                validator: (v) =>
                    (v == null || !v.contains('.')) ? 'सही Package Name लिखें' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _groupCtrl,
                decoration: const InputDecoration(labelText: 'Google Group Link'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _optInCtrl,
                decoration: const InputDecoration(
                  labelText: 'Play Store Opt-in Testing Link',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutes/Day'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _daysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Days'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dailyCoinsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Daily Coins'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _bonusCoinsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '14-Day Bonus'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save & Publish Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
