import 'package:flutter/material.dart';

import 'package:newfitness/app/widgets/drawer_menu_button.dart';
import 'package:newfitness/app/widgets/tab_switch_signal.dart';

import 'chat_screen.dart';
import 'meals_screen.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    TabSwitchSignal.ai.addListener(_onSignal);
    _onSignal();
  }

  void _onSignal() {
    final index = TabSwitchSignal.ai.value;
    if (index != null) {
      _controller.animateTo(index);
      TabSwitchSignal.ai.value = null;
    }
  }

  @override
  void dispose() {
    TabSwitchSignal.ai.removeListener(_onSignal);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('IA'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Refeições'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [ChatScreen(), MealsScreen()],
      ),
    );
  }
}
