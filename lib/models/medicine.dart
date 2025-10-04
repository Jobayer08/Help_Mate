import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  String id;
  String name;
  int quantity;
  String pharmacy;
  GeoPoint location;
  Timestamp timestamp;

  Medicine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.pharmacy,
    required this.location,
    required this.timestamp,
  });

  factory Medicine.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Medicine(
      id: doc.id,
      name: data['name'],
      quantity: data['quantity'],
      pharmacy: data['pharmacy'],
      location: data['location'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'pharmacy': pharmacy,
      'location': location,
      'timestamp': timestamp,
    };
  }
}
