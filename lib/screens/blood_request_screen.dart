import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BloodRequestScreen extends StatefulWidget {
  const BloodRequestScreen({Key? key}) : super(key: key);

  @override
  _BloodRequestScreenState createState() => _BloodRequestScreenState();
}

class _BloodRequestScreenState extends State<BloodRequestScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String bloodType = '';
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blood Requests')),
      body: Column(
        children: [
          // Form to add a new blood request
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Blood Type'),
                  onChanged: (val) => bloodType = val.trim(),
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Quantity'),
                  onChanged: (val) => quantity = int.tryParse(val) ?? 1,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final user = _auth.currentUser;
                    if (user != null) {
                      await _firestore.collection('blood_requests').add({
                        'userId': user.uid,
                        'bloodType': bloodType,
                        'quantity': quantity,
                        'location': GeoPoint(0, 0), // TODO: Use actual location
                        'status': 'pending',
                        'timestamp': Timestamp.now(),
                      });
                    }
                  },
                  child: Text('Create Request'),
                )
              ],
            ),
          ),

          // Display list of blood requests
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('blood_requests').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final requests = snapshot.data!.docs
                    .map((doc) => BloodRequest.fromDocument(doc))
                    .toList();

                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return ListTile(
                      title: Text('${request.bloodType} - ${request.quantity} unit(s)'),
                      subtitle: Text('Status: ${request.status}'),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
