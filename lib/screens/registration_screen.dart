import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String name = '';
  String email = '';
  String password = '';
  String bloodType = '';
  String role = 'donor';
  String phone = '';
  String locationString = 'Detecting location...';

  double? latitude;
  double? longitude;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HelpMate Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (val) => name = val.trim(),
              ),
              TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                onChanged: (val) => email = val.trim(),
              ),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: (val) => password = val.trim(),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                onChanged: (val) => phone = val.trim(),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Blood Type (e.g., A+)'),
                onChanged: (val) => bloodType = val.trim(),
              ),
              DropdownButtonFormField<String>(
                value: role,
                items: ['donor', 'recipient']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) role = val;
                },
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              const SizedBox(height: 10),
              Text('Location: $locationString'),
              const SizedBox(height: 20),
              ElevatedButton(
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
                onPressed: () async {
                  if (latitude == null || longitude == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not detect location.')));
                    return;
                  }

                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a phone number.')));
                    return;
                  }

                  setState(() => loading = true);

                  try {
                    final userCredential = await _auth
                        .createUserWithEmailAndPassword(email: email, password: password);
                    final user = userCredential.user;

                    if (user != null) {
                      await _firestore.collection('users').doc(user.uid).set({
                        'name': name,
                        'email': email,
                        'bloodType': bloodType,
                        'role': role,
                        'phone': phone,
                        'location': locationString,
                        'latitude': latitude,
                        'longitude': longitude,
                      });
                    }

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message ?? 'Error')));
                  }

                  setState(() => loading = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
