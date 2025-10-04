import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371; // Earth radius in km
  double dLat = _deg2rad(lat2 - lat1);
  double dLon = _deg2rad(lon2 - lon1);
  double a =
      sin(dLat/2) * sin(dLat/2) +
          cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
              sin(dLon/2) * sin(dLon/2);
  double c = 2 * atan2(sqrt(a), sqrt(1-a));
  return R * c;
}

double _deg2rad(double deg) => deg * (pi/180);

Future<List<QueryDocumentSnapshot>> findNearbyDonors({
  required String bloodType,
  required double lat,
  required double lon,
  double radiusKm = 10.0,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'donor')
      .where('bloodType', isEqualTo: bloodType)
      .get();

  final nearby = snapshot.docs.where((doc) {
    final loc = doc['location'] as GeoPoint;
    final distance = _distanceInKm(lat, lon, loc.latitude, loc.longitude);
    return distance <= radiusKm;
  }).toList();

  return nearby;
}
