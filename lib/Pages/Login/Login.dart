import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mailer/smtp_server.dart';
import 'package:http/http.dart' as http;

class TelecomLogin extends StatefulWidget {
  const TelecomLogin({super.key});

  @override
  State<TelecomLogin> createState() => _TelecomLoginState();
}

class _TelecomLoginState extends State<TelecomLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isOtpVisible = false;
  bool _showSuccessMessage = false;
  String _errorMessage = '';
  String _successMessage = '';
  String? _verificationCode;

  // Hover state variables
  bool _isForgotPasswordHovered = false;
  bool _isSignUpHovered = false;

  // Firestore instance
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _sendOtp(String email) async {
    const backendUrl = 'http://localhost:3000/send-email';

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': email, 'subject': 'Login OTP'}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        _verificationCode = responseBody['code']; // Store the OTP
        setState(() {
          _isOtpVisible = true;
          _showSuccessMessage = true;
          _successMessage = 'OTP sent to $email!';
          _errorMessage = '';
        });

        // Hide success message after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showSuccessMessage = false;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to send OTP. Try again.';
          _showSuccessMessage = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Unable to send OTP.';
        _showSuccessMessage = false;
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        // Fetch document from Firestore
        final querySnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .where('email', isEqualTo: email)
            .where('password', isEqualTo: password)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // Successful login
          await _sendOtp(email);
        } else {
          // Login failed
          setState(() {
            _errorMessage = 'Invalid email or password.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim() == _verificationCode) {
      final email = _emailController.text.trim();

      try {
        final querySnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .where('email', isEqualTo: email)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final telecomID = querySnapshot.docs.first.id;

          // Store telecomID in secure storage
          await _secureStorage.write(key: 'telecomID', value: telecomID);

          // Navigate to the home screen
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Row(
            children: [
              // Left Section: Login Form
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and Title
                      Row(
                        children: [
                          Image.asset(
                            'images/smsecureIcon.jpg', // Path to your custom image
                            height: 40, // Adjust the size as needed
                            width: 40, // Adjust the size as needed
                            fit: BoxFit.contain, // Ensures the image fits well
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "SMSecure Administrator",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).appBarTheme.foregroundColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Login Title and Description
                      const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Login to access your SMSecure administrator account",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 30),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // First dot
                          Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: !_isOtpVisible ? Colors.blue : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          // Line between dots
                          Container(
                            height: 2,
                            width: 30,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          // Second dot
                          Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: _isOtpVisible ? Colors.blue : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Error or Success Message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_showSuccessMessage)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            _successMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Login Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            if (!_isOtpVisible)
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: "Email",
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your email";
                                  }
                                  return null;
                                },
                              ),
                            const SizedBox(height: 20),
                            // Password Field
                            if (!_isOtpVisible)
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your password";
                                  }
                                  return null;
                                },
                              ),

                            // OTP Field
                            if (_isOtpVisible)
                              TextFormField(
                                controller: _otpController,
                                decoration: const InputDecoration(
                                  labelText: "Enter OTP",
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter the OTP";
                                  }
                                  return null;
                                },
                              ),

                            const SizedBox(height: 10),

                            // Forgot Password InkWell with Hover Effect
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  // Forgot password logic
                                  Navigator.pushNamed(
                                      context, '/forgotPassword');
                                },
                                onHover: (hovering) {
                                  setState(() {
                                    _isForgotPasswordHovered = hovering;
                                  });
                                },
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: _isForgotPasswordHovered
                                        ? const Color.fromARGB(255, 13, 42, 61)
                                        : const Color(0xFF113953),
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Login Button
                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!_isOtpVisible) {
                                    await _login();
                                  } else {
                                    await _verifyOtp();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0),
                                  backgroundColor: const Color(0xFF113953),
                                ),
                                child: Text(
                                  _isOtpVisible ? "Verify OTP" : "Login",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Section: Stretched Illustration
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                          'images/signInBanner.jpg'), // Ensure the path is correct
                      fit: BoxFit
                          .cover, // Stretch the image to fit the right section
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
