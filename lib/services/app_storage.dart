import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class AppStorage {
  static const String _customTasksKey = 'custom_admin_tasks';
  static const String _deletedTasksKey = 'deleted_task_ids';
  static const String _deviceIdKey = 'anti_cheat_device_id';
  static const String _adminPinKey = 'admin_panel_pin';

  /// Task को JSON Map में बदलना
  static Map<String, dynamic> taskToMap(AppTask t) {
    return {
      'id': t.id,
      'appName': t.appName,
      'packageName': t.packageName,
      'category': t.category,
      'googleGroupUrl': t.googleGroupUrl,
      'playStoreOptInUrl': t.playStoreOptInUrl,
      'requiredMinutesPerDay': t.requiredMinutesPerDay,
      'totalTestingDays': t.totalTestingDays,
      'dailyCoins': t.dailyCoins,
      'completionBonusCoins': t.completionBonusCoins,
      'instructions': t.instructions,
    };
  }

  /// JSON Map से Task बनाना
  static AppTask taskFromMap(Map<String, dynamic> m) {
    return AppTask(
      id: m['id']?.toString() ?? 'task_custom',
      appName: m['appName']?.toString() ?? 'New App',
      packageName: m['packageName']?.toString() ?? 'com.example.app',
      category: m['category']?.toString() ?? '14-Day Testing',
      googleGroupUrl: m['googleGroupUrl']?.toString() ?? '',
      playStoreOptInUrl: m['playStoreOptInUrl']?.toString() ?? '',
      requiredMinutesPerDay: (m['requiredMinutesPerDay'] as num?)?.toInt() ?? 10,
      totalTestingDays: (m['totalTestingDays'] as num?)?.toInt() ?? 14,
      dailyCoins: (m['dailyCoins'] as num?)?.toInt() ?? 20,
      completionBonusCoins: (m['completionBonusCoins'] as num?)?.toInt() ?? 200,
      instructions: m['instructions']?.toString() ?? '',
    );
  }

  /// सभी Active Tasks लाना (Admin द्वारा जोड़े गए + डिफ़ॉल्ट)
  static Future<List<AppTask>> getAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawCustom = prefs.getStringList(_customTasksKey) ?? [];
    final deletedIds = prefs.getStringList(_deletedTasksKey) ?? [];

    final List<AppTask> customList = [];
    for (final item in rawCustom) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map) {
          final task = taskFromMap(Map<String, dynamic>.from(decoded));
          if (!deletedIds.contains(task.id)) {
            customList.add(task);
          }
        }
      } catch (_) {}
    }

    final defaultFiltered = DemoTaskData.sampleTasks
        .where((t) => !deletedIds.contains(t.id))
        .toList();

    return [...customList, ...defaultFiltered];
  }

  /// Admin द्वारा नया Task जोड़ना
  static Future<void> addCustomTask(AppTask task) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCustom = prefs.getStringList(_customTasksKey) ?? [];
    rawCustom.insert(0, jsonEncode(taskToMap(task)));
    await prefs.setStringList(_customTasksKey, rawCustom);
  }

  /// Admin द्वारा Task हटाना
  static Future<void> deleteTask(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawCustom = prefs.getStringList(_customTasksKey) ?? [];
    rawCustom.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded is Map && decoded['id'] == taskId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_customTasksKey, rawCustom);

    final deletedIds = prefs.getStringList(_deletedTasksKey) ?? [];
    if (!deletedIds.contains(taskId)) {
      deletedIds.add(taskId);
      await prefs.setStringList(_deletedTasksKey, deletedIds);
    }
  }

  /// डिफ़ॉल्ट डेमो टास्क वापस लाना
  static Future<void> restoreDefaultTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deletedTasksKey);
  }

  /// Anti-Cheat यूनीक डिवाइस ID बनाना या लाना
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      final rnd = Random();
      final p1 = 1000 + rnd.nextInt(9000);
      final p2 = 1000 + rnd.nextInt(9000);
      id = 'DEV-$p1-$p2';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  /// Admin PIN चेक करना (डिफ़ॉल्ट PIN: 1234)
  static Future<String> getAdminPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminPinKey) ?? '1234';
  }

  static Future<void> setAdminPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPinKey, newPin);
  }

  /// सभी Withdrawal Requests लाना (उनके असली index के साथ)
  static Future<List<Map<String, dynamic>>> getWithdrawals() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('wallet_transactions') ?? [];
    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < rawList.length; i++) {
      try {
        final decoded = jsonDecode(rawList[i]);
        if (decoded is Map && decoded['type'] == 'debit') {
          final map = Map<String, dynamic>.from(decoded);
          map['rawIndex'] = i;
          result.add(map);
        }
      } catch (_) {}
    }
    return result;
  }

  /// Admin द्वारा Payout Approve या Reject+Refund करना
  static Future<void> updateWithdrawalStatus({
    required int rawIndex,
    required String newStatus,
    bool refundCoins = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('wallet_transactions') ?? [];
    if (rawIndex < 0 || rawIndex >= rawList.length) return;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(rawList[rawIndex]) as Map);
      final oldStatus = map['status']?.toString() ?? '';

      // डबल रिफंड से बचाव
      if (refundCoins && oldStatus != 'Rejected (Refunded)') {
        final refundAmt = (map['coins'] as num?)?.toInt() ?? 0;
        final currentCoins = prefs.getInt('user_coins') ?? 0;
        await prefs.setInt('user_coins', currentCoins + refundAmt);
      }

      map['status'] = newStatus;
      rawList[rawIndex] = jsonEncode(map);
      await prefs.setStringList('wallet_transactions', rawList);
    } catch (_) {}
  }
}
