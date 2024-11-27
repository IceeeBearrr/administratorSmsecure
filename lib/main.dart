import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telecom_smsecure/Pages/Admin/AdminPage.dart';
import 'package:telecom_smsecure/Pages/NavigationBar/SideBar.dart';
import 'package:telecom_smsecure/Pages/NavigationBar/UpperNavigationBar.dart';
import 'package:telecom_smsecure/Pages/ForgotPassword/ForgotPassword.dart';
import 'package:telecom_smsecure/Pages/HomePage/HomePage.dart';
import 'package:telecom_smsecure/Pages/Login/Login.dart';
import 'package:telecom_smsecure/Pages/PredictionModel/PredictionModelPage.dart';
import 'package:telecom_smsecure/Pages/ContinuousLearning/ContinuousLearningPage.dart';
import 'package:telecom_smsecure/Pages/User/User.dart';
import 'package:telecom_smsecure/Pages/User/UserShowDetail.dart';
import 'package:telecom_smsecure/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Using SharedPreferences for web compatibility
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? phone = prefs.getString('userPhone');
  String initialRoute = (phone != null) ? '/home' : '/login';

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 255, 255, 255),
          foregroundColor: Color(0xFF113953),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/home': (context) => const MainApp(),
        '/login': (context) => const TelecomLogin(), // Replace with your login page
        '/forgotPassword': (context) => const TelecomForgotPassword(), // Replace with your login page
      },
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final bool _isDrawerOpen = false;

  void onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _screens = [
    Homepage(),
    const AdministratorPage(),
    Userpage(),
    const PredictionModelPage(),
    const ContinuousLearningPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomNavigationBar(),
      drawer: SideBar(
        selectedIndex: _selectedIndex,
        onTabSelected: onTabChange,
      ),
      body: _screens[_selectedIndex],
    );
  }
}
