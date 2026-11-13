import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class FirebaseService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static String get currentUid => _auth.currentUser?.uid ?? '';
  static String get currentEmail => _auth.currentUser?.email ?? '';

  static String todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _generateReferralCode() {
    final number = 1000 + Random().nextInt(9000);
    return 'TASK$number';
  }

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('anti_cheat_device_id');
    if (id == null) {
      final rnd = Random();
      id = 'DEV-${1000 + rnd.nextInt(9000)}-${1000 + rnd.nextInt(9000)}';
      await prefs.setString('anti_cheat_device_id', id);
    }
    return id;
  }

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

  // ---------------- 1. AUTHENTICATION ----------------

  static Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanRef = referralCode.trim().toUpperCase();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password.trim(),
    );

    final uid = cred.user!.uid;
    final deviceId = await getOrCreateDeviceId();
    final myCode = _generateReferralCode();
    int welcomeCoins = 50;

    if (cleanRef.isNotEmpty) {
      try {
        final refQuery = await _db
            .collection('task_users')
            .where('myReferralCode', isEqualTo: cleanRef)
            .limit(1)
            .get();

        if (refQuery.docs.isNotEmpty) {
          welcomeCoins += 25;
          final referrerDoc = refQuery.docs.first;
          await referrerDoc.reference.update({
            'coins': FieldValue.increment(25),
          });
          await _db.collection('task_transactions').add({
            'uid': referrerDoc.id,
            'userEmail': referrerDoc.data()['email'] ?? '',
            'title': 'Referral Bonus ($name joined)',
            'coins': 25,
            'type': 'credit',
            'status': 'Credited',
            'date': todayStr(),
            'createdAtMs': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } catch (_) {}
    }

    await _db.collection('task_users').doc(uid).set({
      'uid': uid,
      'name': name.trim(),
      'email': cleanEmail,
      'coins': welcomeCoins,
      'myReferralCode': myCode,
      'referredBy': cleanRef,
      'deviceId': deviceId,
      'checkInStreak': 0,
      'lastCheckInDate': '',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    await _db.collection('task_transactions').add({
      'uid': uid,
      'userEmail': cleanEmail,
      'title': 'Welcome Sign Up Bonus',
      'coins': welcomeCoins,
      'type': 'credit',
      'status': 'Credited',
      'date': todayStr(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cred = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password.trim(),
    );

    final uid = cred.user!.uid;
    final doc = await _db.collection('task_users').doc(uid).get();
    if (!doc.exists) {
      final deviceId = await getOrCreateDeviceId();
      await _db.collection('task_users').doc(uid).set({
        'uid': uid,
        'name': cleanEmail.split('@').first,
        'email': cleanEmail,
        'coins': 50,
        'myReferralCode': _generateReferralCode(),
        'referredBy': '',
        'deviceId': deviceId,
        'checkInStreak': 0,
        'lastCheckInDate': '',
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  // ---------------- 2. USER PROFILE & DAILY CHECK-IN ----------------

  static Future<Map<String, dynamic>> getUserProfile() async {
    if (currentUid.isEmpty) return {};
    final doc = await _db.collection('task_users').doc(currentUid).get();
    return doc.data() ?? {};
  }

  static Future<int> claimDailyCheckIn() async {
    if (currentUid.isEmpty) throw Exception('Not logged in');
    final today = todayStr();
    const rewardCoins = 15;

    final userRef = _db.collection('task_users').doc(currentUid);
    int newStreak = 1;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};
      if (data['lastCheckInDate'] == today) {
        throw Exception('आज का बोनस पहले ही क्लेम हो चुका है!');
      }
      newStreak = ((data['checkInStreak'] as num?)?.toInt() ?? 0) + 1;
      tx.update(userRef, {
        'coins': FieldValue.increment(rewardCoins),
        'lastCheckInDate': today,
        'checkInStreak': newStreak,
      });
    });

    await _db.collection('task_transactions').add({
      'uid': currentUid,
      'userEmail': currentEmail,
      'title': 'Daily Check-in Bonus (Day $newStreak)',
      'coins': rewardCoins,
      'type': 'credit',
      'status': 'Credited',
      'date': today,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    return rewardCoins;
  }

  // ---------------- 3. TASKS / CAMPAIGNS ----------------

  static Future<void> seedDefaultTasksIfFirstTime() async {
    final initDoc = _db.collection('task_settings').doc('seed_status');
    final snap = await initDoc.get();
    if (snap.exists) return;

    final batch = _db.batch();
    int orderOffset = 0;
    for (final task in DemoTaskData.sampleTasks) {
      final map = taskToMap(task);
      map['createdAtMs'] = DateTime.now().millisecondsSinceEpoch - orderOffset;
      orderOffset += 1000;
      batch.set(_db.collection('task_campaigns').doc(task.id), map);
    }
    batch.set(initDoc, {'seeded': true});
    await batch.commit();
  }

  static Future<List<AppTask>> getAllTasks() async {
    await seedDefaultTasksIfFirstTime();
    final snap = await _db.collection('task_campaigns').get();
    final list = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    list.sort((a, b) => ((b['createdAtMs'] as num?) ?? 0)
        .compareTo((a['createdAtMs'] as num?) ?? 0));

    return list.map((m) => taskFromMap(m)).toList();
  }

  static Future<void> addTask(AppTask task) async {
    final map = taskToMap(task);
    map['createdAtMs'] = DateTime.now().millisecondsSinceEpoch;
    await _db.collection('task_campaigns').doc(task.id).set(map);
  }

  static Future<void> deleteTask(String taskId) async {
    await _db.collection('task_campaigns').doc(taskId).delete();
  }

  static Future<void> restoreDefaultTasks() async {
    final batch = _db.batch();
    for (final task in DemoTaskData.sampleTasks) {
      final map = taskToMap(task);
      map['createdAtMs'] = DateTime.now().millisecondsSinceEpoch;
      batch.set(_db.collection('task_campaigns').doc(task.id), map);
    }
    await batch.commit();
  }

  // ---------------- 4. TASK PROGRESS & 14-DAY CLAIMS ----------------

  static Future<Map<String, Map<String, dynamic>>> getAllUserProgress() async {
    if (currentUid.isEmpty) return {};
    final snap = await _db
        .collection('task_progress')
        .where('uid', isEqualTo: currentUid)
        .get();

    final Map<String, Map<String, dynamic>> result = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final taskId = data['taskId']?.toString() ?? '';
      if (taskId.isNotEmpty) {
        result[taskId] = data;
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> getSingleTaskProgress(
      String taskId) async {
    if (currentUid.isEmpty) return {};
    final docId = '${currentUid}_$taskId';
    final doc = await _db.collection('task_progress').doc(docId).get();
    return doc.data() ?? {};
  }

  static Future<void> updateTaskStep({
    required AppTask task,
    bool? joinedGroup,
    bool? optedInStore,
  }) async {
    if (currentUid.isEmpty) return;
    final docId = '${currentUid}_${task.id}';
    final Map<String, dynamic> updateData = {
      'uid': currentUid,
      'userEmail': currentEmail,
      'taskId': task.id,
      'appName': task.appName,
      'started': true,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    if (joinedGroup != null) updateData['joinedGroup'] = joinedGroup;
    if (optedInStore != null) updateData['optedInStore'] = optedInStore;

    await _db
        .collection('task_progress')
        .doc(docId)
        .set(updateData, SetOptions(merge: true));
  }

  static Future<int> claimTaskDayReward({
    required AppTask task,
    String feedback = '',
  }) async {
    if (currentUid.isEmpty) throw Exception('Not logged in');
    final today = todayStr();
    final progressRef =
        _db.collection('task_progress').doc('${currentUid}_${task.id}');
    final userRef = _db.collection('task_users').doc(currentUid);

    int earnedCoins = 0;
    int newCompletedDays = 0;
    bool gotBonus = false;

    await _db.runTransaction((tx) async {
      final progSnap = await tx.get(progressRef);
      final progData = progSnap.data() ?? {};

      final currentDone = (progData['completedDays'] as num?)?.toInt() ?? 0;
      final lastClaim = progData['lastClaimDate']?.toString() ?? '';

      if (currentDone >= task.totalTestingDays) {
        throw Exception('यह टास्क पहले ही पूरा हो चुका है!');
      }
      if (lastClaim == today) {
        throw Exception('आज का टास्क पहले ही क्लेम हो चुका है!');
      }

      newCompletedDays = currentDone + 1;
      gotBonus = newCompletedDays == task.totalTestingDays;
      earnedCoins =
          task.dailyCoins + (gotBonus ? task.completionBonusCoins : 0);

      tx.set(
        progressRef,
        {
          'uid': currentUid,
          'userEmail': currentEmail,
          'taskId': task.id,
          'appName': task.appName,
          'started': true,
          'completedDays': newCompletedDays,
          'lastClaimDate': today,
          if (feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      tx.update(userRef, {'coins': FieldValue.increment(earnedCoins)});
    });

    await _db.collection('task_transactions').add({
      'uid': currentUid,
      'userEmail': currentEmail,
      'title': gotBonus
          ? '${task.appName} (Day $newCompletedDays + Final Bonus)'
          : '${task.appName} (Day $newCompletedDays Task)',
      'coins': earnedCoins,
      'type': 'credit',
      'status': 'Credited',
      'date': today,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });

    return earnedCoins;
  }

  // ---------------- 5. WALLET & WITHDRAWALS ----------------

  static Future<List<Map<String, dynamic>>> getUserTransactions() async {
    if (currentUid.isEmpty) return [];
    final snap = await _db
        .collection('task_transactions')
        .where('uid', isEqualTo: currentUid)
        .get();

    final list = snap.docs.map((d) {
      final m = d.data();
      m['docId'] = d.id;
      return m;
    }).toList();

    list.sort((a, b) => ((b['createdAtMs'] as num?) ?? 0)
        .compareTo((a['createdAtMs'] as num?) ?? 0));
    return list;
  }

  static Future<void> submitWithdrawal({
    required int withdrawCoins,
    required String method,
    required String destination,
  }) async {
    if (currentUid.isEmpty) throw Exception('Not logged in');
    final userRef = _db.collection('task_users').doc(currentUid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final currentCoins = (snap.data()?['coins'] as num?)?.toInt() ?? 0;
      if (currentCoins < withdrawCoins) {
        throw Exception('आपके वॉलेट में पर्याप्त कॉइन्स नहीं हैं!');
      }
      tx.update(userRef, {'coins': FieldValue.increment(-withdrawCoins)});
    });

    await _db.collection('task_transactions').add({
      'uid': currentUid,
      'userEmail': currentEmail,
      'title': '$method Withdrawal ($destination)',
      'method': method,
      'destination': destination,
      'coins': withdrawCoins,
      'type': 'debit',
      'status': 'Pending (24-48 Hrs)',
      'date': todayStr(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---------------- 6. ADMIN CONTROLS ----------------

  static Future<String> getAdminPin() async {
    try {
      final doc = await _db.collection('task_settings').doc('admin').get();
      return doc.data()?['pin']?.toString() ?? '1234';
    } catch (_) {
      return '1234';
    }
  }

  static Future<void> setAdminPin(String newPin) async {
    await _db
        .collection('task_settings')
        .doc('admin')
        .set({'pin': newPin}, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getAllWithdrawalsForAdmin() async {
    final snap = await _db
        .collection('task_transactions')
        .where('type', isEqualTo: 'debit')
        .get();

    final list = snap.docs.map((d) {
      final m = d.data();
      m['docId'] = d.id;
      return m;
    }).toList();

    list.sort((a, b) => ((b['createdAtMs'] as num?) ?? 0)
        .compareTo((a['createdAtMs'] as num?) ?? 0));
    return list;
  }

  static Future<void> adminUpdateWithdrawal({
    required String txDocId,
    required String targetUid,
    required int coins,
    required String newStatus,
    bool refundCoins = false,
  }) async {
    final txRef = _db.collection('task_transactions').doc(txDocId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(txRef);
      final oldStatus = snap.data()?['status']?.toString() ?? '';

      if (refundCoins &&
          oldStatus != 'Rejected (Refunded)' &&
          targetUid.isNotEmpty) {
        final userRef = _db.collection('task_users').doc(targetUid);
        tx.update(userRef, {'coins': FieldValue.increment(coins)});
      }

      tx.update(txRef, {'status': newStatus});
    });
  }

  static Future<List<Map<String, dynamic>>> getAllTestersForAdmin() async {
    final snap = await _db.collection('task_users').get();
    final list = snap.docs.map((d) => d.data()).toList();
    list.sort((a, b) => ((b['createdAtMs'] as num?) ?? 0)
        .compareTo((a['createdAtMs'] as num?) ?? 0));
    return list;
  }
}
