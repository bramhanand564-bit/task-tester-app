class AppTask {
  final String id;
  final String appName;
  final String packageName;
  final String category; // '14-Day Testing' या 'Quick 10-Min'
  final String googleGroupUrl;
  final String playStoreOptInUrl;
  final int requiredMinutesPerDay;
  final int totalTestingDays;
  final int dailyCoins;
  final int completionBonusCoins;
  final String instructions;

  AppTask({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.category,
    required this.googleGroupUrl,
    required this.playStoreOptInUrl,
    required this.requiredMinutesPerDay,
    required this.totalTestingDays,
    required this.dailyCoins,
    required this.completionBonusCoins,
    required this.instructions,
  });

  int get totalPotentialCoins =>
      (dailyCoins * totalTestingDays) + completionBonusCoins;

  bool get isLongTermTesting => totalTestingDays > 1;
}

class DemoTaskData {
  // 10 Coins = ₹1.00 के हिसाब से रुपये दिखाने का फॉर्मूला
  static String coinsToRupees(int coins) {
    return (coins / 10).toStringAsFixed(2);
  }

  static List<AppTask> sampleTasks = [
    AppTask(
      id: 'task_001',
      appName: 'QuizMaster Pro (Beta)',
      packageName: 'com.example.quizmaster',
      category: '14-Day Testing',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl:
          'https://play.google.com/apps/testing/com.example.quizmaster',
      requiredMinutesPerDay: 10,
      totalTestingDays: 14,
      dailyCoins: 20,
      completionBonusCoins: 200,
      instructions:
          '1. पहले Tester Group ज्वाइन करें।\n'
          '2. Opt-in लिंक से Play Store पर जाकर ऐप डाउनलोड करें।\n'
          '3. ऐप को रोज़ कम से कम 10 मिनट चलाएं।\n'
          '4. 14 दिन तक ऐप डिलीट न करें और आखिरी दिन फीडबैक दें।',
    ),
    AppTask(
      id: 'task_002',
      appName: 'NaxChat Messenger (Beta)',
      packageName: 'com.nax.chat',
      category: '14-Day Testing',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl: 'https://play.google.com/apps/testing/com.nax.chat',
      requiredMinutesPerDay: 10,
      totalTestingDays: 14,
      dailyCoins: 25,
      completionBonusCoins: 250,
      instructions:
          '1. Play Store टेस्टिंग प्रोग्राम Opt-in करें।\n'
          '2. ऐप इंस्टॉल करके अकाउंट बनाएं और 10 मिनट टेस्ट करें।\n'
          '3. लगातार 14 दिन रोज़ 10 मिनट ऐप खोलें।',
    ),
    AppTask(
      id: 'task_003',
      appName: 'Fast Expense Tracker',
      packageName: 'com.example.expensetracker',
      category: 'Quick 10-Min',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl:
          'https://play.google.com/apps/testing/com.example.expensetracker',
      requiredMinutesPerDay: 10,
      totalTestingDays: 1,
      dailyCoins: 50,
      completionBonusCoins: 0,
      instructions:
          '1. ऐप डाउनलोड करें।\n'
          '2. लगातार 10 मिनट तक ऐप में खर्च जोड़ने का टेस्ट करें।\n'
          '3. 10 मिनट पूरे होते ही तुरंत 50 कॉइन क्लेम करें।',
    ),
    AppTask(
      id: 'task_004',
      appName: 'Smart Habit & Focus',
      packageName: 'com.example.smarthabit',
      category: 'Quick 10-Min',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl:
          'https://play.google.com/apps/testing/com.example.smarthabit',
      requiredMinutesPerDay: 10,
      totalTestingDays: 1,
      dailyCoins: 40,
      completionBonusCoins: 0,
      instructions:
          '1. ऐप इंस्टॉल करें और एक नई Habit बनाएं।\n'
          '2. 10 मिनट तक ऐप इस्तेमाल करें और 40 कॉइन पाएं।',
    ),
  ];
}
