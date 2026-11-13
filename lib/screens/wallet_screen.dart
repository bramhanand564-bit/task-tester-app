import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/firebase_service.dart';

class WalletScreen extends StatefulWidget {
  final VoidCallback onBalanceChanged;

  const WalletScreen({super.key, required this.onBalanceChanged});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool isLoading = true;
  int coins = 0;
  String userEmail = '';
  List<Map<String, dynamic>> transactions = [];
  static const int minWithdrawCoins = 200; // ₹20 न्यूनतम लिमिट

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final profile = await FirebaseService.getUserProfile();
      final txList = await FirebaseService.getUserTransactions();

      if (!mounted) return;
      setState(() {
        coins = (profile['coins'] as num?)?.toInt() ?? 0;
        userEmail = profile['email']?.toString() ?? FirebaseService.currentEmail;
        transactions = txList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('वॉलेट लोड करने में दिक्कत आई: $e', isError: true);
    }
  }

  Future<void> _processWithdrawal(
    int withdrawCoins,
    String method,
    String destination,
  ) async {
    try {
      await FirebaseService.submitWithdrawal(
        withdrawCoins: withdrawCoins,
        method: method,
        destination: destination,
      );

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
            'आपकी ₹${DemoTaskData.coinsToRupees(withdrawCoins)} ($method) की रिक्वेस्ट क्लाउड सर्वर पर सबमिट हो गई है।\n\n'
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
    } catch (e) {
      _showSnack('Withdrawal फेल हुआ: $e', isError: true);
    }
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
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final progress = (coins / minWithdrawCoins).clamp(0.0, 1.0);
    final remaining = (minWithdrawCoins - coins).clamp(0, minWithdrawCoins);

    return RefreshIndicator(
      onRefresh: _loadWalletData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      'लाइव क्लाउड बैलेंस',
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
          const SizedBox(height: 20),
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
              child: const Column(
                children: [
                  Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'अभी कोई ट्रांजैक्शन नहीं है',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            ...transactions.map((tx) {
              final isDebit = tx['type'] == 'debit';
              final txCoins = (tx['coins'] as num?)?.toInt() ?? 0;
              final status = tx['status']?.toString() ?? 'Credited';

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
                    '${tx['date']} • $status',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDebit
                          ? (status.contains('Paid')
                              ? Colors.green.shade700
                              : Colors.orange.shade800)
                          : Colors.grey.shade600,
                    ),
                  ),
                  trailing: Text(
                    '${isDebit ? "-" : "+"}$txCoins 🪙',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color:
                          isDebit ? Colors.red.shade700 : Colors.green.shade700,
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
