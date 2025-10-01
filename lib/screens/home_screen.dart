import 'package:flutter/material.dart';
import 'blood_request_screen.dart'; // make sure this import exists

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('HelpMate Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to HelpMate!'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BloodRequestScreen()),
                );
              },
              child: Text('View/Create Blood Requests'),
            ),
          ],
        ),
      ),
    );
  }
}
