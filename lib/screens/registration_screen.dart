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
  String locationString = 'Detecting location...';

  double? latitude;
  double? longitude;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Get current location and convert to address
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


      print("Lat: ${position.latitude}, Lng: ${position.longitude}"); // debug print

      latitude = position.latitude;
      longitude = position.longitude;


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
      appBar: AppBar(title: Text('HelpMate Register')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Name'),
                onChanged: (val) => name = val.trim(),
              ),
              TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email'),
                onChanged: (val) => email = val.trim(),
              ),
              TextField(
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                onChanged: (val) => password = val.trim(),
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Blood Type (e.g., A+)'),
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
                decoration: InputDecoration(labelText: 'Role'),
              ),
              SizedBox(height: 10),
              Text('Location: $locationString'),
              SizedBox(height: 20),
              ElevatedButton(
                child: loading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Register'),
                onPressed: () async {
                  if (latitude == null || longitude == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Could not detect location.')));
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
                        'location': locationString,
                        'latitude': latitude,
                        'longitude': longitude,
                      });
                    }

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen()),
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
