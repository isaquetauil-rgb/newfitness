import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'meals_screen.dart';

class AiHubScreen extends StatelessWidget {
  const AiHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IA'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Refeições'),
            ],
          ),
        ),
        body: const TabBarView(children: [ChatScreen(), MealsScreen()]),
      ),
    );
  }
}
