import 'package:flutter/material.dart';
import 'package:rephelp/data/app_database.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rephelp/utils/app_colors.dart';

import 'package:rephelp/screens/students_screen.dart';
import 'package:rephelp/screens/schedule_screen.dart';
import 'package:rephelp/screens/finance_screen.dart';
import 'package:rephelp/screens/analytics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  await AppDatabase().database;
  runApp(const RepHelpApp());
}

class RepHelpApp extends StatelessWidget {
  const RepHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Помощник репетитора',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFf0f0f0),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: AppColors.lavender,
          secondary: AppColors.lavender,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;

  static const List<Widget> _screens = <Widget>[
    ScheduleScreen(),
    StudentsScreen(),
    FinanceScreen(),
    AnalyticsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Расписание',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Ученики'),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Финансы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Аналитика',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.lavender,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
