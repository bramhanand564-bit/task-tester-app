import 'package:flutter/material.dart';
import 'models/task_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskTesterApp());
}

class TaskTesterApp extends StatelessWidget {
  const TaskTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskEarn & Beta Tester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // प्रोफेशनल Indigo रंग
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: const Part1PreviewScreen(),
    );
  }
}

/// Part 1 चेक करने के लिए अस्थायी स्क्रीन (Part 2 में यहाँ Auth Screen आएगी)
class Part1PreviewScreen extends StatelessWidget {
  const Part1PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = DemoTaskData.sampleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskEarn - Part 1 Ready'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: const Text(
                'Part 1 सेटअप सफल! नीचे आपके Example Tasks का डेटा दिख रहा है। Part 2 में हम Single-Form Login & Sign Up पेज जोड़ेंगे।',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Example Tasks (Demo Data):',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF4F46E5),
                        child: Icon(Icons.android, color: Colors.white),
                      ),
                      title: Text(
                        task.appName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${task.requiredMinutesPerDay} Min/Day • ${task.totalTestingDays} Days • Total ${task.totalPotentialCoins} Coins',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
