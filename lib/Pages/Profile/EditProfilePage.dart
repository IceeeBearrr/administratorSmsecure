import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'package:crop/crop.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';

class EditProfilePage extends StatefulWidget {
  final String telecomID;

  const EditProfilePage({super.key, required this.telecomID});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  bool isLoading = true;
  String? profileImageBase64;
  String? tempImageBase64;
  final List<String> genderItems = ['Male', 'Female'];
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  final controller = CropController();
  double _rotation = 0;

  Future<void> _pickImage() async {
    try {
      // Open file picker with accepted types
      final input = html.FileUploadInputElement()..accept = '.jpg,.jpeg,.png';
      input.click();

      await input.onChange.first;
      final file = input.files!.first;

      // Check file size (1MB = 1048576 bytes)
      if (file.size > 1048576) {
        _showError('Image size must be less than 1MB');
        return;
      }

      // Read file
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;

      final result = reader.result as String;
      final base64String = result.split(',').last;

      // Show cropper dialog
      _showImageCropper(base64String);
    } catch (e) {
      print('Error picking image: $e');
      _showError('Failed to pick image');
    }
  }

  void _showImageCropper(String base64Image) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crop & Rotate Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 400,
              height: 400,
              child: Crop(
                controller: controller,
                shape: BoxShape.circle,
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.rotate_left),
                  onPressed: () {
                    setState(() {
                      _rotation -= 90;
                      controller.rotation = _rotation;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right),
                  onPressed: () {
                    setState(() {
                      _rotation += 90;
                      controller.rotation = _rotation;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Get the cropped image
              final croppedImage = await controller.crop();
              if (croppedImage != null) {
                final data =
                    await croppedImage.toByteData(format: ImageByteFormat.png);
                final bytes = data!.buffer.asUint8List();
                final base64String = base64Encode(bytes);

                setState(() {
                  tempImageBase64 = base64String;
                });
                Navigator.pop(context);
                _showImagePreview();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview'),
        content: SizedBox(
          width: 200,
          height: 200,
          child: CircleAvatar(
            backgroundImage: MemoryImage(
              base64Decode(tempImageBase64!),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                tempImageBase64 = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                profileImageBase64 = tempImageBase64;
              });
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updateData = {
          'name': _nameController.text,
          'phoneNo': _phoneController.text,
          'email': _emailController.text,
          'gender': _genderController.text,
          'birthday': _birthdayController.text,
        };

        // Only update image if a new one was selected
        if (profileImageBase64 != null) {
          updateData['profileImageUrl'] = profileImageBase64!;
        }

        await _firestore
            .collection('telecommunicationsAdmin')
            .doc(widget.telecomID)
            .update(updateData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        print("Error updating profile: $e");
        _showError('Error updating profile');
      }
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final docSnapshot = await _firestore
          .collection('telecommunicationsAdmin')
          .doc(widget.telecomID)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phoneNo'] ?? '';
          _emailController.text = data['email'] ?? '';
          _genderController.text = data['gender'] ?? '';
          _birthdayController.text = data['birthday'] ?? '';
          profileImageBase64 = data['profileImageUrl']; // Get Base64 image
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching profile data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text(
          'Back to Profile Page',
          style: TextStyle(color: Colors.black, fontSize: 14),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                    top: 50, left: 450, right: 450, bottom: 50),
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
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              profileImageBase64 != null &&
                                      profileImageBase64!.isNotEmpty
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: MemoryImage(
                                        base64Decode(profileImageBase64!),
                                      ),
                                    )
                                  : CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.grey.shade300,
                                      child: const Icon(Icons.person,
                                          size: 50, color: Colors.white),
                                    ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildReadOnlyField("ID", widget.telecomID),
                        const SizedBox(height: 10),
                        _buildEditableField(
                          "Name",
                          _nameController,
                          prefixIcon:
                              const Icon(Icons.badge, color: Color(0xFF113953)),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
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
                              return 'Please enter your email';
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
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5468FF),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Edit',
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

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        TextFormField(
          initialValue: value,
          readOnly: true,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade200,
          ),
        ),
      ],
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
          buttonStyleData: const ButtonStyleData(
            padding: EdgeInsets.only(right: 8),
          ),
          iconStyleData: const IconStyleData(
            icon: Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF113953),
            ),
          ),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
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
              return 'Please select your birthday';
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
