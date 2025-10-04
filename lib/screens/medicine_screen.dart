import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine.dart';
import 'dart:math';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({Key? key}) : super(key: key);

  @override
  _MedicineScreenState createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final _firestore = FirebaseFirestore.instance;
  String searchQuery = '';
  double userLat = 23.8103; // replace with actual GPS if needed
  double userLon = 90.4125;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Medicines')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                  labelText: 'Search Medicine',
                  suffixIcon: Icon(Icons.search)),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('medicines').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                final medicines = snapshot.data!.docs
                    .map((doc) => Medicine.fromDocument(doc))
                    .where((med) => med.name.toLowerCase().contains(searchQuery.toLowerCase()))
                    .toList();

                if (medicines.isEmpty)
                  return Center(child: Text('No medicines found'));

                // Sort by distance
                medicines.sort((a, b) {
                  final distA = distanceInKm(userLat, userLon, a.location.latitude, a.location.longitude);
                  final distB = distanceInKm(userLat, userLon, b.location.latitude, b.location.longitude);
                  return distA.compareTo(distB);
                });

                return ListView.builder(
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final med = medicines[index];
                    final dist = distanceInKm(userLat, userLon, med.location.latitude, med.location.longitude).toStringAsFixed(1);

                    return Card(
                      child: ListTile(
                        title: Text(med.name),
                        subtitle: Text('${med.pharmacy} • $dist km away • Quantity: ${med.quantity}'),
                        trailing: med.quantity < 5
                            ? Icon(Icons.warning, color: Colors.red)
                            : null,
                      ),
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

  double distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat/2) * sin(dLat/2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon/2) * sin(dLon/2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (3.141592653589793 / 180);
}
