import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Location detection
  Future<void> _determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => locationString = 'Location service disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => locationString = 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => locationString = 'Location permission denied forever');
        return;
      }

      Position position =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      latitude = position.latitude;
      longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(latitude!, longitude!);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          locationString = '${place.locality}, ${place.administrativeArea}, ${place.country}';
        });
      } else {
        setState(() {
          locationString = 'Lat:${latitude!.toStringAsFixed(4)}, Lon:${longitude!.toStringAsFixed(4)}';
        });
      }
    } catch (e) {
      setState(() {
        locationString = 'Could not get location';
      });
    }
  }

  // Phone launcher
  Future<void> _launchPhone(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
    }
  }

  // SMS launcher
  Future<void> _launchSMS(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch SMS app')));
    }
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  double distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = _deg2rad(lat2 - lat1);
    double dLon = _deg2rad(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // Create a blood request
  Future<void> _createRequest() async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not detect location')));
      return;
    }
    if (bloodType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a blood type')));
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    await _firestore.collection('blood_requests').add({
      'userId': user.uid,
      'bloodType': bloodType,
      'quantity': quantity,
      'location': GeoPoint(latitude!, longitude!),
      'status': 'pending',
      'timestamp': Timestamp.now(),
    });

    // Feedback & optionally clear
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Blood request created')));
    setState(() {
      // keep bloodType (so donor search can run) or clear if you want:
      // bloodType = '';
      quantity = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blood Requests')),
      body: Column(
        children: [
          // Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Blood Type (e.g., A+)'),
                  onChanged: (val) => bloodType = val.trim(),
                ),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity (units)'),
                  onChanged: (val) => quantity = int.tryParse(val) ?? 1,
                ),
                const SizedBox(height: 8),
                Text('Detected location: $locationString'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _createRequest,
                      child: const Text('Create Request'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _determinePosition,
                      child: const Text('Refresh Location'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Show all blood requests (most recent first)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Row(
              children: const [
                Text('Recent Requests', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          SizedBox(
            height: 180, // small box to show recent requests; scrollable
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('blood_requests').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No requests yet'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data() as Map<String, dynamic>;
                    final ts = (d['timestamp'] as Timestamp?)?.toDate();
                    final loc = d['location'];
                    String locText = '';
                    if (loc is GeoPoint) {
                      locText = '(${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)})';
                    } else if (d.containsKey('latitude') && d.containsKey('longitude')) {
                      locText = '(${(d['latitude'] as num).toDouble().toStringAsFixed(4)}, ${(d['longitude'] as num).toDouble().toStringAsFixed(4)})';
                    }
                    return ListTile(
                      dense: true,
                      title: Text('${d['bloodType'] ?? 'N/A'} • ${d['quantity'] ?? 1} unit(s)'),
                      subtitle: Text('Status: ${d['status'] ?? 'pending'} • $locText'),
                      trailing: Text(ts != null ? '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}' : ''),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(),

          // Donor list (filtered by bloodType)
          Expanded(
            child: bloodType.isEmpty
                ? const Center(child: Text('Enter a blood type and create a request to see nearby donors.'))
                : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final userDocs = snapshot.data!.docs;
                final filtered = <QueryDocumentSnapshot>[];

                for (final doc in userDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['role'] != 'donor') continue;
                  if ((data['bloodType'] ?? '').toString().trim() != bloodType) continue;

                  double? donorLat;
                  double? donorLon;

                  if (data['location'] is GeoPoint) {
                    donorLat = (data['location'] as GeoPoint).latitude;
                    donorLon = (data['location'] as GeoPoint).longitude;
                  } else if (data.containsKey('latitude') && data.containsKey('longitude')) {
                    donorLat = (data['latitude'] as num).toDouble();
                    donorLon = (data['longitude'] as num).toDouble();
                  }

                  if (donorLat == null || donorLon == null) continue;
                  if (latitude == null || longitude == null) continue;

                  final dist = distanceInKm(latitude!, longitude!, donorLat, donorLon);
                  if (dist <= 10) filtered.add(doc);
                }

                if (filtered.isEmpty) return const Center(child: Text('No nearby donors found.'));

                // sort by distance
                filtered.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>;
                  final db = b.data() as Map<String, dynamic>;
                  double la = da['location'] is GeoPoint ? (da['location'] as GeoPoint).latitude : (da['latitude'] as num?)?.toDouble() ?? 0;
                  double loa = da['location'] is GeoPoint ? (da['location'] as GeoPoint).longitude : (da['longitude'] as num?)?.toDouble() ?? 0;
                  double lb = db['location'] is GeoPoint ? (db['location'] as GeoPoint).latitude : (db['latitude'] as num?)?.toDouble() ?? 0;
                  double lob = db['location'] is GeoPoint ? (db['location'] as GeoPoint).longitude : (db['longitude'] as num?)?.toDouble() ?? 0;
                  final dA = distanceInKm(latitude!, longitude!, la, loa);
                  final dB = distanceInKm(latitude!, longitude!, lb, lob);
                  return dA.compareTo(dB);
                });

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final donorDoc = filtered[index];
                    final data = donorDoc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final phone = data['phone'] ?? '';
                    double donorLat = data['location'] is GeoPoint ? (data['location'] as GeoPoint).latitude : (data['latitude'] as num?)?.toDouble() ?? 0;
                    double donorLon = data['location'] is GeoPoint ? (data['location'] as GeoPoint).longitude : (data['longitude'] as num?)?.toDouble() ?? 0;
                    final distText = distanceInKm(latitude ?? 0, longitude ?? 0, donorLat, donorLon).toStringAsFixed(1);

                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text('${data['bloodType'] ?? 'N/A'} • $distText km away'),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.phone),
                          onSelected: (value) {
                            if (phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number provided')));
                              return;
                            }
                            if (value == 'call') {
                              _launchPhone(phone);
                            } else {
                              _launchSMS(phone);
                            }
                          },
                          itemBuilder: (context) => const [
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
}
