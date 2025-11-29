import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/constants.dart';
import '../dashboard/dashboard_screen.dart';
import '../chat/chat_list_screen.dart';
import '../forum/forum_list_screen.dart';

import '../profile/profile_screen.dart';
import '../events/events_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    
    // Determine if user is a society handler
    final isSocietyHandler = user?.role == AppConstants.roleSocietyHandler;

    // Define screens based on role
    final screens = isSocietyHandler
        ? [
            const DashboardScreen(), // Society Dashboard
            const ChatListScreen(),
            const ForumListScreen(),
            const ProfileScreen(),
          ]
        : [
            const EventsListScreen(), // Student Events List
            const ChatListScreen(),
            const ForumListScreen(),
            const ProfileScreen(),
          ];

    // Define navigation destinations based on role
    final destinations = isSocietyHandler
        ? const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Events',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Forum',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
      floatingActionButton: isSocietyHandler
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, AppConstants.createEventRoute);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            )
          : null,
    );
  }
}
