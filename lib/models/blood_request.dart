import 'package:cloud_firestore/cloud_firestore.dart';

class BloodRequest {
  String id;
  String userId;
  String bloodType;
  int quantity;
  GeoPoint location;
  String status;
  Timestamp timestamp;

  BloodRequest({
    required this.id,
    required this.userId,
    required this.bloodType,
    required this.quantity,
    required this.location,
    required this.status,
    required this.timestamp,
  });

  factory BloodRequest.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BloodRequest(
      id: doc.id,
      userId: data['userId'],
      bloodType: data['bloodType'],
      quantity: data['quantity'],
      location: data['location'],
      status: data['status'],
      timestamp: data['timestamp'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bloodType': bloodType,
      'quantity': quantity,
      'location': location,
      'status': status,
      'timestamp': timestamp,
    };
  }
}
