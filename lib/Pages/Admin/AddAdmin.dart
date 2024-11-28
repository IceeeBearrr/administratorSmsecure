import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  _AddAdminPageState createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  final List<String> genderItems = ['Male', 'Female'];
  DateTime? selectedDate;
  String? profileImageBase64;

  Future<void> _addAdmin() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Check if email or phone number already exists
        final emailQuery = await _firestore
            .collection('telecommunicationsAdmin')
            .where('email', isEqualTo: _emailController.text)
            .get();
        final phoneQuery = await _firestore
            .collection('telecommunicationsAdmin')
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

        // Create new admin data
        final newAdminData = {
          'name': _nameController.text,
          'phoneNo': _phoneController.text,
          'email': _emailController.text,
          'gender': _genderController.text,
          'birthday': _birthdayController.text,
          'profileImageUrl': profileImageBase64 ?? '', // Placeholder image
          'role': 'admin', // Default role for new admin
          'createdAt': FieldValue.serverTimestamp(),
        };

        // Add new admin to Firestore
        await _firestore
            .collection('telecommunicationsAdmin')
            .add(newAdminData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin added successfully!')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        print("Error adding admin: $e");
        _showError('Error adding admin');
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
          'Add New Admin',
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
                        return 'Please enter the admin name';
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
                        return 'Please enter the admin email';
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
                        return 'Please enter the admin phone number';
                      }
                      // Regex for Malaysian phone number
                      final phoneRegex = RegExp(r'^\+601[0-9]{8,9}$');
                      if (!phoneRegex.hasMatch(value)) {
                        return 'Please enter a valid phone number (e.g., +601155050925)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),
                  _buildGenderDropdown(),
                  const SizedBox(height: 10),
                  _buildDatePicker(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _addAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5468FF),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add Admin',
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
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
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
          style: const TextStyle(color: Color.fromARGB(188, 0, 0, 0)),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: prefixIcon,
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

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField2<String>(
          value: _genderController.text.isEmpty ? null : _genderController.text,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon:
                const Icon(Icons.person_outline, color: Color(0xFF113953)),
          ),
          hint: const Text('Select Gender'),
          items: genderItems
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  ))
              .toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select gender';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _genderController.text = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Birthday',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: _birthdayController,
          readOnly: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon:
                const Icon(Icons.calendar_today, color: Color(0xFF113953)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select the admin\'s birthday';
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18), // Set initial date to 18 years ago
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF113953),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }
}
