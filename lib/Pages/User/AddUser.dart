import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      
      final userDoc = await FirebaseFirestore.instance
          .collection('smsUser')
          .where('emailAddress', isEqualTo: email)
          .get();

      if (userDoc.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'User already exists';
          _isLoading = false;
        });
        return;
      }

      final token = sha256.convert(utf8.encode('${email}${DateTime.now()}')).toString();

      // Send email using Express server
      final response = await http.post(
        Uri.parse('http://localhost:3000/send-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'to': email,
          'subject': 'Welcome to SMS Secure - Verification Token',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send email');
      }

      // Get the verification code from response
      final responseData = json.decode(response.body);
      final verificationCode = responseData['code'];

      // Add user to Firestore with verification code
      await FirebaseFirestore.instance.collection('smsUser').doc().set({
        'emailAddress': email,
        'token': verificationCode,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Add New User', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          color: Colors.white,  // Explicitly set card color to white
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600), // Increased from 400
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32), // Increased padding
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A991),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Send Invitation',
                            style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}