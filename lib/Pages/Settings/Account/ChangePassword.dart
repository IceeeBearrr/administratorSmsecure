import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _showSuccessMessage = false; // To track the success message visibility
  String _errorMessage = ''; // To display errors
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isPasswordFieldsVisible = false; // Determines whether to show the password fields step
  String _successMessage = '';
  bool _isNewPasswordVisible = false; // Visibility toggle for new password
  bool _isConfirmPasswordVisible = false; // Visibility toggle for confirm password
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(); // Secure storage instance

  Future<void> _validateEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email.";
      });
      return;
    }

    // Validate if the email matches the email in Firestore using telecomID
    final telecomID = await _secureStorage.read(key: "telecomID");
    if (telecomID == null) {
      setState(() {
        _errorMessage = "Unable to verify user. Please try again.";
      });
      return;
    }

    try {
      final adminDoc = await _firestore.collection('telecommunicationsAdmin').doc(telecomID).get();

      if (adminDoc.exists) {
        final storedEmail = adminDoc.data()?['email'];

        if (storedEmail != email) {
          setState(() {
            _errorMessage = "The entered email does not match your current email.";
          });
          return;
        }

        // If email is validated, proceed to the password update step
        setState(() {
          _isPasswordFieldsVisible = true; // Show password fields
          _errorMessage = '';
          _showSuccessMessage = true;
          _successMessage = "Email validated successfully!";
        });

        // Hide the success message after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showSuccessMessage = false;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = "User not found.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error validating email. Please try again.";
      });
    }
  }

  Future<void> _updatePassword() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (newPassword != confirmPassword) {
        setState(() {
          _errorMessage = "Passwords do not match.";
        });
        return;
      }

      try {
        // Update the password in Firestore
        final querySnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .where('email', isEqualTo: email)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docId = querySnapshot.docs.first.id;

          await _firestore.collection('telecommunicationsAdmin').doc(docId).update({'password': newPassword});

          setState(() {
            _successMessage = "Password updated successfully!";
            _showSuccessMessage = true;
            _errorMessage = '';
          });

          // Navigate to HomePage after 5 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home'); // Replace '/home' with the route name of your HomePage
            }
          });
        } else {
          setState(() {
            _errorMessage = "Email not found in Firestore.";
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = "Error updating password. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Back Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                size: 16,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Page Title
                        const Text(
                          "Change Password",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Please enter your Email Address to validate your account before changing your password.",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 30),

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
                        if (_errorMessage.isNotEmpty) const SizedBox(height: 20),

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
                        if (_showSuccessMessage) const SizedBox(height: 20),

                        // Progress Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // First dot
                            Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                color: !_isPasswordFieldsVisible ? Colors.blue : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Line between first and second dots
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
                                color: _isPasswordFieldsVisible ? Colors.blue : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Email Field or Password Fields
                        if (!_isPasswordFieldsVisible)
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              hintText: "Enter your email",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your email";
                              }
                              if (!RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$").hasMatch(value)) {
                                return "Enter a valid email address";
                              }
                              return null;
                            },
                          ),

                        // Password Fields
                        if (_isPasswordFieldsVisible)
                          Column(
                            children: [
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: !_isNewPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: "New Password",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isNewPasswordVisible = !_isNewPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                    return 'Password must contain at least one uppercase letter';
                                  }
                                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                                    return 'Password must contain at least one lowercase letter';
                                  }
                                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                                    return 'Password must contain at least one digit';
                                  }
                                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_]').hasMatch(value)) {
                                    return 'Password must contain at least one special character';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: "Confirm Password",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please confirm your password";
                                  }
                                  if (value != _newPasswordController.text) {
                                    return "Passwords do not match";
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Next Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!_isPasswordFieldsVisible) {
                                await _validateEmail();
                              } else {
                                await _updatePassword();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15.0),
                              backgroundColor: const Color(0xFF113953),
                            ),
                            child: Text(
                              _isPasswordFieldsVisible ? "Update Password" : "Validate Email",
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
                ),
              ),

              // Right Section: Illustration
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('images/forgotPassword.jpg'),
                      fit: BoxFit.cover,
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
