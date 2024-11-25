import 'package:flutter/material.dart';

class SideBar extends StatelessWidget {
  final ValueChanged<int> onTabSelected;
  final int selectedIndex;

  const SideBar({
    super.key,
    required this.onTabSelected,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Image.asset(
                  'images/smsecureIcon.jpg', // Your logo path
                  height: 40,
                  width: 40,
                ),
                const SizedBox(width: 10),
                const Text(
                  "SMSecure Administrator",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF113953),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            selected: selectedIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text("Administrators"),
            selected: selectedIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text("Users"),
            selected: selectedIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text("Prediction Model"),
            selected: selectedIndex == 3,
            onTap: () => onTabSelected(3),
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text("Continuous Learning"),
            selected: selectedIndex == 4,
            onTap: () => onTabSelected(4),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
