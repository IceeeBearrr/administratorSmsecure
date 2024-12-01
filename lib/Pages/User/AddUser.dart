import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final List<String> genderItems = ['Male', 'Female'];
  DateTime? selectedDate;
  String? profileImageBase64;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  Future<void> _addUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Check if email or phone number already exists
        final emailQuery = await _firestore
            .collection('smsUser') // Change the collection to 'users'
            .where('emailAddress', isEqualTo: _emailController.text)
            .get();
        final phoneQuery = await _firestore
            .collection('smsUser') // Change the collection to 'users'
            .where('phoneNo', isEqualTo: _phoneController.text)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          _showError(
              'The email is already in use. Please use a different email.');
          return;
        }

        if (phoneQuery.docs.isNotEmpty) {
          _showError(
              'The phone number is already in use. Please use a different phone number.');
          return;
        }

        // Create new user data
        final newUserData = {
          'name': _nameController.text,
          'phoneNo': _phoneController.text,
          'emailAddress': _emailController.text,
          'password': _passwordController.text,
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Add new user to Firestore
        await _firestore
            .collection('smsUser')
            .add(newUserData); // Changed to 'users'

        final telecomID =
            await const FlutterSecureStorage().read(key: 'telecomID');

        // Log successful action to Firestore
        if (telecomID != null) {
          await _firestore
              .collection('telecommunicationsAdmin')
              .doc(telecomID)
              .collection('log')
              .add({
            'action': 'User ${_nameController.text} added successfully',
            'timestamp': Timestamp.now(),
            'status': 'success',
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User added successfully!')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        // Log failure to Firestore
        final telecomID =
            await const FlutterSecureStorage().read(key: 'telecomID');
        if (telecomID != null) {
          await _firestore
              .collection('telecommunicationsAdmin')
              .doc(telecomID)
              .collection('log')
              .add({
            'action': 'Failed to add user ${_nameController.text}',
            'timestamp': Timestamp.now(),
            'status': 'failed',
          });
        }

        print("Error adding user: $e");
        _showError('Error adding user');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New User', // Changed title to "Add New User"
          style: TextStyle(color: Colors.black, fontSize: 14),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(top: 50, left: 450, right: 450, bottom: 50),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circle Avatar for Profile Image (Not Clickable)
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  _buildEditableField(
                    "Name",
                    _nameController,
                    prefixIcon:
                        const Icon(Icons.badge, color: Color(0xFF113953)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the user name';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                        return 'Only letters and spaces are allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildEditableField(
                    "Email Address",
                    _emailController,
                    prefixIcon:
                        const Icon(Icons.email, color: Color(0xFF113953)),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the user email';
                      }
                      if (!RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildEditableField(
                    "Mobile",
                    _phoneController,
                    prefixIcon:
                        const Icon(Icons.call, color: Color(0xFF113953)),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the user phone number';
                      }
                      final phoneRegex = RegExp(r'^\+601[0-9]{8,9}$');
                      if (!phoneRegex.hasMatch(value)) {
                        return 'Please enter a valid phone number (e.g., +601155050925)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  _buildEditableField(
                    "Password",
                    _passwordController,
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFF113953)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF113953),
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible =
                              !_passwordVisible; // Toggle password visibility
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    obscureText: !_passwordVisible,
                  ),
                  const SizedBox(height: 10),
                  _buildEditableField(
                    "Confirm Password",
                    _confirmPasswordController,
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFF113953)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Color(0xFF113953),
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    obscureText: !_confirmPasswordVisible,
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addUser, // Changed function to _addUser
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5468FF),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add User', // Changed button text
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    Icon? prefixIcon,
    Widget? suffixIcon, // Add suffixIcon parameter

    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false, // Add this parameter
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          obscureText: obscureText, // Pass it to TextFormField
          style: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon, // Ensure this is set

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF113953)),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

}
