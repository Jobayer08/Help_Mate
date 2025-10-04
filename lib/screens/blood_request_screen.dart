import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/location_utils.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

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

  double? latitude;
  double? longitude;
  String locationString = 'Detecting location...';

  List<QueryDocumentSnapshot> nearbyDonors = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Detect user's GPS location and convert to address
  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      latitude = position.latitude;
      longitude = position.longitude;

      List<Placemark> placemarks =
      await placemarkFromCoordinates(latitude!, longitude!);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          locationString =
          '${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      }
    } catch (e) {
      setState(() {
        locationString = 'Could not get location';
      });
    }
  }

  // Launch phone dialer
  Future<void> _launchPhone(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not launch dialer')));
    }
  }

  // Launch SMS app
  Future<void> _launchSMS(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not launch SMS app')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Blood Requests')),
      body: Column(
        children: [
          // Blood request form
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
                Text('Location: $locationString'),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    if (latitude == null || longitude == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not detect location')));
                      return;
                    }

                    final user = _auth.currentUser;
                    if (user != null) {
                      // Save blood request
                      await _firestore.collection('blood_requests').add({
                        'userId': user.uid,
                        'bloodType': bloodType,
                        'quantity': quantity,
                        'location': GeoPoint(latitude!, longitude!),
                        'status': 'pending',
                        'timestamp': Timestamp.now(),
                      });

                      // Find nearby donors
                      final donors = await findNearbyDonors(
                        bloodType: bloodType,
                        lat: latitude!,
                        lon: longitude!,
                        radiusKm: 10,
                      );

                      donors.sort((a, b) {
                        final locA = a['location'] as GeoPoint;
                        final locB = b['location'] as GeoPoint;
                        final distA = distanceInKm(
                            latitude!, longitude!, locA.latitude, locA.longitude);
                        final distB = distanceInKm(
                            latitude!, longitude!, locB.latitude, locB.longitude);
                        return distA.compareTo(distB);
                      });

                      setState(() {
                        nearbyDonors = donors;
                      });
                    }
                  },
                  child: Text('Create Request'),
                ),
              ],
            ),
          ),

          if (nearbyDonors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Nearby Donors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),

          // Real-time donor list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                final donors = snapshot.data!.docs.where((doc) {
                  if (doc['role'] != 'donor' || doc['bloodType'] != bloodType)
                    return false;
                  final loc = doc['location'] as GeoPoint;
                  final distance =
                  distanceInKm(latitude!, longitude!, loc.latitude, loc.longitude);
                  return distance <= 10;
                }).toList();

                donors.sort((a, b) {
                  final locA = a['location'] as GeoPoint;
                  final locB = b['location'] as GeoPoint;
                  final distA =
                  distanceInKm(latitude!, longitude!, locA.latitude, locA.longitude);
                  final distB =
                  distanceInKm(latitude!, longitude!, locB.latitude, locB.longitude);
                  return distA.compareTo(distB);
                });

                if (donors.isEmpty) return Center(child: Text('No nearby donors found.'));

                return ListView.builder(
                  itemCount: donors.length,
                  itemBuilder: (context, index) {
                    final donor = donors[index];
                    final loc = donor['location'] as GeoPoint;
                    final distance = distanceInKm(
                        latitude!, longitude!, loc.latitude, loc.longitude)
                        .toStringAsFixed(1);

                    return Card(
                      child: ListTile(
                        title: Text(donor['name']),
                        subtitle: Text(
                            '${donor['bloodType']} • ${distance} km away • ${donor['role']}'),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.phone),
                          onSelected: (value) {
                            final phone = donor['phone'];
                            if (phone == null || phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('No phone provided')));
                              return;
                            }
                            if (value == 'call') {
                              _launchPhone(phone);
                            } else if (value == 'sms') {
                              _launchSMS(phone);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'call', child: Text('Call')),
                            PopupMenuItem(value: 'sms', child: Text('Message')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Distance helper
  double distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (3.141592653589793 / 180);
}
