import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class WalletScreen extends StatefulWidget {
  final VoidCallback onBalanceChanged;

  const WalletScreen({super.key, required this.onBalanceChanged});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int coins = 0;
  String userEmail = '';
  List<Map<String, dynamic>> transactions = [];
  static const int minWithdrawCoins = 200; // ₹20 न्यूनतम लिमिट

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadWalletData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('wallet_transactions') ?? [];

    final List<Map<String, dynamic>> parsedList = [];
    for (final item in rawHistory) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          parsedList.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      coins = prefs.getInt('user_coins') ?? 0;
      userEmail = prefs.getString('user_email') ?? '';
      transactions = parsedList;
    });
  }

  Future<void> _processWithdrawal(
    int withdrawCoins,
    String method,
    String destination,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('user_coins') ?? 0;

    if (currentCoins < withdrawCoins) {
      _showSnack('पर्याप्त कॉइन्स नहीं हैं!', isError: true);
      return;
    }

    final updatedCoins = currentCoins - withdrawCoins;
    await prefs.setInt('user_coins', updatedCoins);

    final rawHistory = prefs.getStringList('wallet_transactions') ?? [];
    final newTx = jsonEncode({
      'title': '$method Withdrawal ($destination)',
      'coins': withdrawCoins,
      'type': 'debit',
      'status': 'Pending (24-48 Hrs)',
      'date': _todayStr(),
    });
    rawHistory.insert(0, newTx);
    await prefs.setStringList('wallet_transactions', rawHistory);

    await _loadWalletData();
    widget.onBalanceChanged();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Request Submitted!'),
          ],
        ),
        content: Text(
          'आपकी ₹${DemoTaskData.coinsToRupees(withdrawCoins)} ($method) की रिक्वेस्ट सबमिट हो गई है।\n\n'
          'Destination: $destination\n'
          'Status: 24-48 घंटे में वेरिफिकेशन के बाद पेमेंट भेज दिया जाएगा।',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            child: const Text('ठीक है'),
          ),
        ],
      ),
    );
  }

  // डेवलपर टेस्टिंग के लिए +200 कॉइन जोड़ने का हेल्पर (लॉन्च से पहले हटा दें)
  Future<void> _addDemoTestCoins() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = (prefs.getInt('user_coins') ?? 0) + 200;
    await prefs.setInt('user_coins', updated);

    final rawHistory = prefs.getStringList('wallet_transactions') ?? [];
    rawHistory.insert(
      0,
      jsonEncode({
        'title': 'Developer Test Bonus',
        'coins': 200,
        'type': 'credit',
        'date': _todayStr(),
      }),
    );
    await prefs.setStringList('wallet_transactions', rawHistory);

    await _loadWalletData();
    widget.onBalanceChanged();
    _showSnack('⚡ टेस्टिंग के लिए +200 Coins (₹20) जोड़े गए!');
  }

  void _openWithdrawSheet() {
    if (coins < minWithdrawCoins) {
      _showSnack(
        'पैसे निकालने के लिए कम से कम $minWithdrawCoins Coins (₹20) होने ज़रूरी हैं!',
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WithdrawBottomSheet(
        currentCoins: coins,
        userEmail: userEmail,
        onWithdrawSubmit: _processWithdrawal,
      ),
    );
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
    final progress = (coins / minWithdrawCoins).clamp(0.0, 1.0);
    final remaining = (minWithdrawCoins - coins).clamp(0, minWithdrawCoins);

    return RefreshIndicator(
      onRefresh: _loadWalletData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Main Wallet Balance Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F766E).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'उपलब्ध बैलेंस (Available)',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '10 Coins = ₹1.00',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '🪙 $coins',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '(₹${DemoTaskData.coinsToRupees(coins)})',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Minimum Withdrawal Progress Bar
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Colors.white.withOpacity(0.25),
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 6),
                Text(
                  remaining == 0
                      ? '✅ आप Withdrawal करने के लिए तैयार हैं!'
                      : 'Min ₹20 निकालने के लिए $remaining Coins और कमाएं',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openWithdrawSheet,
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text(
                      'Withdraw Money (UPI / Redeem Code)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Developer Test Helper (केवल टेस्टिंग के लिए)
          OutlinedButton.icon(
            onPressed: _addDemoTestCoins,
            icon: const Icon(Icons.bolt, color: Colors.orange),
            label: const Text(
              '🧪 Test Mode: +200 Coins जोड़कर Withdraw चेक करें',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Transaction History Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                'कुल ${transactions.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  const Text(
                    'अभी कोई ट्रांजैक्शन नहीं है',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daily Check-in या 10-मिनट का टास्क पूरा करने पर यहाँ आपकी कमाई दिखेगी।',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            ...transactions.map((tx) {
              final isDebit = tx['type'] == 'debit';
              final txCoins = tx['coins'] ?? 0;
              final status = tx['status']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isDebit ? Colors.red.shade50 : Colors.green.shade50,
                    child: Icon(
                      isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isDebit ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    tx['title']?.toString() ?? 'Task Reward',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    status != null
                        ? '${tx['date']} • $status'
                        : '${tx['date']} • Credited',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDebit ? Colors.orange.shade800 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: Text(
                    '${isDebit ? "-" : "+"}$txCoins 🪙',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Withdrawal Bottom Sheet (UPI और Redeem Code चुनने का फॉर्म)
class _WithdrawBottomSheet extends StatefulWidget {
  final int currentCoins;
  final String userEmail;
  final Future<void> Function(int coins, String method, String destination)
      onWithdrawSubmit;

  const _WithdrawBottomSheet({
    required this.currentCoins,
    required this.userEmail,
    required this.onWithdrawSubmit,
  });

  @override
  State<_WithdrawBottomSheet> createState() => _WithdrawBottomSheetState();
}

class _WithdrawBottomSheetState extends State<_WithdrawBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _destController = TextEditingController();

  String selectedMethod = 'UPI';
  int selectedCoins = 200;
  bool isSubmitting = false;

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  void _onMethodChanged(String method) {
    setState(() {
      selectedMethod = method;
      if (method == 'Redeem Code' && _destController.text.isEmpty) {
        _destController.text = widget.userEmail;
      } else if (method == 'UPI' && _destController.text == widget.userEmail) {
        _destController.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.currentCoins < selectedCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('आपके पास इतने कॉइन्स नहीं हैं! कम अमाउंट चुनें।'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    await widget.onWithdrawSubmit(
      selectedCoins,
      selectedMethod,
      _destController.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final amountOptions = [200, 500, 1000];

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
                'पैसे निकालें (Withdraw)',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'उपलब्ध: ${widget.currentCoins} Coins (₹${DemoTaskData.coinsToRupees(widget.currentCoins)})',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Method Selector
              const Text(
                '1. पेमेंट तरीका चुनें:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['UPI', 'Redeem Code'].map((method) {
                  final active = selectedMethod == method;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: method == 'UPI' ? 8 : 0),
                      child: ChoiceChip(
                        label: Center(child: Text(method)),
                        selected: active,
                        selectedColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: active ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (_) => _onMethodChanged(method),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Amount Selector
              const Text(
                '2. अमाउंट चुनें:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: amountOptions.map((amt) {
                  final active = selectedCoins == amt;
                  final affordable = widget.currentCoins >= amt;
                  return ChoiceChip(
                    label: Text('₹${DemoTaskData.coinsToRupees(amt)} ($amt🪙)'),
                    selected: active,
                    selectedColor: const Color(0xFF4F46E5),
                    labelStyle: TextStyle(
                      color: active
                          ? Colors.white
                          : (affordable ? Colors.black87 : Colors.grey),
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => selectedCoins = amt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // UPI ID or Email Input
              TextFormField(
                controller: _destController,
                decoration: InputDecoration(
                  labelText: selectedMethod == 'UPI'
                      ? 'आपकी UPI ID'
                      : 'Redeem Code भेजने के लिए Gmail',
                  hintText: selectedMethod == 'UPI'
                      ? 'उदाहरण: 9876543210@ybl या name@okaxis'
                      : 'example@gmail.com',
                  prefixIcon: Icon(
                    selectedMethod == 'UPI'
                        ? Icons.account_balance
                        : Icons.email_outlined,
                  ),
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (selectedMethod == 'UPI') {
                    if (!text.contains('@') || text.length < 5) {
                      return 'सही UPI ID डालें (जैसे name@ybl)';
                    }
                  } else {
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'सही Gmail एड्रेस डालें';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          '₹${DemoTaskData.coinsToRupees(selectedCoins)} Withdraw करें',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
