import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'blood_request_screen.dart';
import 'medicine_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // If not logged in (should rarely happen due to AuthWrapper)
      return Scaffold(
        appBar: AppBar(title: const Text('HelpMate Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You are not logged in.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Go back to login
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Logged-in user sees dashboard
    return Scaffold(
      appBar: AppBar(
        title: const Text('HelpMate Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              // 🔒 Sign out user
              await FirebaseAuth.instance.signOut();
              // No need for Navigator.pop — AuthWrapper in main.dart handles the redirect!
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Welcome, ${user.displayName ?? 'User'} 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Blood Requests Card
            Card(
              color: Colors.red.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.bloodtype, size: 40, color: Colors.red),
                title: const Text('Blood Requests', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Request blood or find nearby donors'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BloodRequestScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Medicine Search Card
            Card(
              color: Colors.green.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.local_pharmacy, size: 40, color: Colors.green),
                title: const Text('Medicine Search', style: TextStyle(fontSize: 18)),
                subtitle: const Text('Find medicines in nearby pharmacies'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicineScreen()),
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
