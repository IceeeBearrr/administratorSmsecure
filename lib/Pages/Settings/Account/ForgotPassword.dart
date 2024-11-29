import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordProfile extends StatefulWidget {
  const ForgotPasswordProfile({super.key});

  @override
  State<ForgotPasswordProfile> createState() => _ForgotPasswordProfileState();
}

class _ForgotPasswordProfileState extends State<ForgotPasswordProfile> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController =
      TextEditingController(); // Separate controller for the code
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _showSuccessMessage = false; // To track the success message visibility
  String _errorMessage = ''; // To display errors
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isCodeVisible = false;
  bool _isHovered = false; // Hover state for "Back to login"
  String? _verificationCode; // Store verification code sent from the backend
  String _successMessage = '';
  bool _isPasswordFieldsVisible = false;
  final bool _isPasswordVisible = false;
  bool _isNewPasswordVisible = false; // Separate variable for new password
  bool _isConfirmPasswordVisible =
      false; // Separate variable for confirm password
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(); // Secure storage instance

  Future<void> _sendVerificationCode() async {
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
      } else {
        setState(() {
          _errorMessage = "User not found.";
        });
        return;
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error validating email. Please try again.";
      });
      return;
    }


    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'to': email, 'subject': 'Verification Code'}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        _verificationCode = responseBody['code']; // Store the verification code

        setState(() {
          _isCodeVisible = true;
          _showSuccessMessage = true;
          _successMessage = "Verification code sent to $email!";
          _errorMessage = '';
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
          _errorMessage = "Failed to send verification code. Try again.";
          _showSuccessMessage = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: Unable to send verification code.";
        _showSuccessMessage = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    print("Verifying code...");
    print("Entered code: ${_codeController.text}");
    print("Stored code: $_verificationCode");

    if (_codeController.text.trim() == _verificationCode) {
      setState(() {
        _successMessage = "Verification successful!";
        _showSuccessMessage = true;
        _errorMessage = '';
        _isPasswordFieldsVisible = true; // Show password fields
      });
    } else {
      setState(() {
        _errorMessage = "Invalid verification code!";
        _showSuccessMessage = false;
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

          await _firestore
              .collection('telecommunicationsAdmin')
              .doc(docId)
              .update({'password': newPassword});

          setState(() {
            _successMessage = "Password updated successfully!";
            _showSuccessMessage = true;
            _errorMessage = '';
          });

          // Navigate to login page after 5 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
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

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      try {
        print(
            'Checking if email exists in Firestore: ${_emailController.text.trim()}');

        // Check if the email exists in the telecommunicationsAdmin collection
        final querySnapshot = await _firestore
            .collection('telecommunicationsAdmin')
            .where('email', isEqualTo: _emailController.text.trim())
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          print('Email found in Firestore, proceeding to send email...');

          // Email exists, send email
          await _sendVerificationCode();
          setState(() {
            _successMessage = "Verification code sent to your email!";
            _showSuccessMessage = true;
            _errorMessage = '';
            _isCodeVisible = true; // Show the code input field
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
          print('Email not found in Firestore.');
          setState(() {
            _showSuccessMessage = false;
            _errorMessage = 'Email not found. Please try again.';
          });
        }
      } catch (error) {
        print('Error in _sendResetLink: $error');
        setState(() {
          _showSuccessMessage = false;
          _errorMessage = 'An error occurred. Please try again later.';
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
              // Left Section: Form
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
                        // Back to Login Link with InkWell for Hover
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .start, // Align to the start for a natural back button position
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons
                                    .arrow_back_ios, // Changed from `arrow_forward_ios` to `arrow_back_ios`
                                size: 16,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                    context); // Pops the current page and navigates back
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Page Title
                        const Text(
                          "Forgot Password",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Please enter your Email Address. A verification code "
                          "will be sent to your email for resetting your password.",
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
                        if (_errorMessage.isNotEmpty)
                          const SizedBox(height: 20),

                        if (_showSuccessMessage)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(
                                10.0), // This can stay const
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              _successMessage, // Non-constant variable, so no const here
                              style: const TextStyle(
                                // Style can remain constant
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
                                color: !_isCodeVisible
                                    ? Colors.blue
                                    : _isPasswordFieldsVisible
                                        ? Colors.grey
                                        : Colors.grey,
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
                                color:
                                    _isCodeVisible && !_isPasswordFieldsVisible
                                        ? Colors.blue
                                        : _isPasswordFieldsVisible
                                            ? Colors.grey
                                            : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Line between second and third dots
                            Container(
                              height: 2,
                              width: 30,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            // Third dot
                            Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                color: _isPasswordFieldsVisible
                                    ? Colors.blue
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Email Field or Reset Code
                        if (!_isCodeVisible)
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
                              if (!RegExp(
                                      r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
                                  .hasMatch(value)) {
                                return "Enter a valid email address";
                              }
                              return null;
                            },
                          ),

                        // Code Field
                        if (_isCodeVisible && !_isPasswordFieldsVisible)
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Verification Code",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter the verification code";
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
                                obscureText:
                                    !_isNewPasswordVisible, // Use the new password visibility variable
                                decoration: InputDecoration(
                                  labelText: "New Password",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isNewPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isNewPasswordVisible =
                                            !_isNewPasswordVisible;
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
                                  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_]')
                                      .hasMatch(value)) {
                                    return 'Password must contain at least one special character';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText:
                                    !_isConfirmPasswordVisible, // Use the confirm password visibility variable
                                decoration: InputDecoration(
                                  labelText: "Confirm Password",
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible =
                                            !_isConfirmPasswordVisible;
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
                              print("Button pressed");
                              if (!_isCodeVisible) {
                                print("Sending reset link...");
                                await _sendResetLink();
                                print("Reset link sent, showing code input.");
                              } else if (_isPasswordFieldsVisible) {
                                await _updatePassword();
                              } else {
                                print("Verifying code...");
                                _verifyCode(); // Verify the entered code
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 15.0),
                              backgroundColor: const Color(0xFF113953),
                            ),
                            child: Text(
                              _isPasswordFieldsVisible
                                  ? "Update Password"
                                  : _isCodeVisible
                                      ? "Verify Code"
                                      : "Send Verification Code",
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
                      image: AssetImage(
                          'images/forgotPassword.jpg'), // Path to the image
                      fit: BoxFit.cover, // Stretch the image
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
