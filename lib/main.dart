import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase initialization failed: $e");
    return;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(),
        '/musicHome': (context) => MusicHomePage(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      Navigator.pushReplacementNamed(context, '/musicHome');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFF4A2C2A),
          image: DecorationImage(
            image: AssetImage('assets/ss01.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.2),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFA500),
                    letterSpacing: 2.0,
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(0xFF6B4E4A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Icon(Icons.login, color: Color(0xFFFFA500)),
                          label: Text(
                            'Sign in with Google',
                            style: TextStyle(color: Color(0xFFFFA500)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Color(0xFFFFA500)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading) CircularProgressIndicator(color: Color(0xFFFFA500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MusicHomePage extends StatefulWidget {
  @override
  _MusicHomePageState createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  String? selectedSong;
  String? selectedFilePath;
  bool isLoading = false;
  String? analysisResult;
  Map<String, dynamic>? analysisDetails;

  Future<void> _pickMp3File() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
    );

    if (result != null) {
      setState(() {
        selectedSong = result.files.single.name;
        selectedFilePath = result.files.single.path;
        // Clear previous results when selecting a new file
        analysisResult = null;
        analysisDetails = null;
      });
    } else {
      setState(() {
        selectedSong = null;
        selectedFilePath = null;
      });
    }
  }

  Future<void> _analyzeSong() async {
    if (selectedFilePath == null) {
      _showMessage("Please select a song first!");
      return;
    }

    setState(() {
      isLoading = true;
      analysisResult = null;
      analysisDetails = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      var uri = Uri.parse("http://10.0.2.2:5000/analyze");
      var request = http.MultipartRequest("POST", uri);
      request.files.add(await http.MultipartFile.fromPath('audio', selectedFilePath!));
      var streamedResponse = await request.send();
      var responseData = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        var jsonResponse = jsonDecode(responseData);
        setState(() {
          analysisResult = jsonResponse['message'];
          // Parse the results object
          if (jsonResponse.containsKey('results')) {
            analysisDetails = jsonResponse['results'];
          }
        });
      } else {
        setState(() {
          analysisResult = "Error: ${streamedResponse.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        analysisResult = "Error: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://blue-titans-web-app.vercel.app');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch URL')),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/ss01.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.menu, color: Colors.white, size: 28),
                        onPressed: () {},
                      ),
                      Text(
                        "MYMUSIC",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                SizedBox(height: 60),
                Container(
                  width: 280,
                  height: 50,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedSong ?? "No song selected",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.upload, color: Colors.orange.shade600),
                        onPressed: _pickMp3File,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                _buildButton("Analyze Now", FontAwesomeIcons.drum, Colors.orange.shade300, isLarge: true, onPressed: _analyzeSong),
                SizedBox(height: 15),
                _buildButton("Synthesis", FontAwesomeIcons.waveSquare, Colors.orange.shade400, isLarge: true, onPressed: _launchURL),
                SizedBox(height: 15),
                _buildButton("Train with AI", FontAwesomeIcons.guitar, Colors.orange.shade500, isLarge: true, onPressed: () {}),
                SizedBox(height: 20),
                if (isLoading)
                  CircularProgressIndicator(color: Colors.orange.shade600)
                else if (analysisResult != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Analysis Results",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 15),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.orange.shade400,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    analysisResult!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.orange.shade300,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  if (analysisDetails != null) ...[
                                    _buildAnalysisItem("Genre", analysisDetails!['genre'] ?? "Unknown"),
                                    _buildAnalysisItem("Taal", analysisDetails!['taal'] ?? "Unknown"),
                                    _buildAnalysisItem(
                                      "Tonic", 
                                      analysisDetails!['tonic'] != null ? analysisDetails!['tonic'] : "Not detected"
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.orange.shade200,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, Color color, {bool isLarge = false, required VoidCallback onPressed}) {
    return Container(
      width: isLarge ? 250 : 130,
      height: isLarge ? 60 : 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, color: Colors.white),
        label: Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: isLarge ? 20 : 16),
        ),
      ),
    );
  }
}