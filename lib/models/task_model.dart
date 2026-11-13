class AppTask {
  final String id;
  final String appName;
  final String packageName;
  final String category;
  final String googleGroupUrl;
  final String playStoreOptInUrl;
  final int requiredMinutesPerDay; // जैसे: 10 मिनट
  final int totalTestingDays;      // जैसे: 14 दिन
  final int dailyCoins;            // रोज़ के कॉइन (जैसे: 20)
  final int completionBonusCoins;  // 14 दिन पूरे होने पर बड़ा बोनस (जैसे: 200)
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

  // कुल कितने कॉइन मिलेंगे (उदाहरण: 14 * 20 + 200 = 480 Coins)
  int get totalPotentialCoins =>
      (dailyCoins * totalTestingDays) + completionBonusCoins;
}

/// समझने के लिए Example Tasks (बाद में ये एडमिन पैनल/Firebase से आएंगे)
class DemoTaskData {
  static List<AppTask> sampleTasks = [
    AppTask(
      id: 'task_001',
      appName: 'QuizMaster Pro (Beta)',
      packageName: 'com.example.quizmaster',
      category: '14-Day Play Store Testing',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl: 'https://play.google.com/apps/testing/com.example.quizmaster',
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
      appName: 'Fast Expense Tracker',
      packageName: 'com.example.expensetracker',
      category: 'Quick 10-Min Task',
      googleGroupUrl: 'https://groups.google.com/g/your-testers-group',
      playStoreOptInUrl: 'https://play.google.com/apps/testing/com.example.expensetracker',
      requiredMinutesPerDay: 10,
      totalTestingDays: 1, // सिंगल डे टास्क का उदाहरण
      dailyCoins: 50,
      completionBonusCoins: 0,
      instructions:
          '1. ऐप डाउनलोड करें।\n'
          '2. लगातार 10 मिनट तक ऐप में खर्च जोड़ने का टेस्ट करें।\n'
          '3. 10 मिनट पूरे होते ही तुरंत 50 कॉइन क्लेम करें।',
    ),
  ];
}
