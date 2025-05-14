import 'package:flutter/material.dart';

import '../conversation/screens/topic_list.dart';
import '../ipa/screens/ipa_list.dart';


class PronunciationHomeScreen extends StatelessWidget {
  const PronunciationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.deepPurple;
    final secondaryColor = Colors.blue;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            // AppBar tùy chỉnh
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              padding: const EdgeInsets.only(top: 48, bottom: 16),
              child: Column(
                children: [
                  const Text(
                    "Luyện phát âm",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom TabBar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tabWidth = constraints.maxWidth / 2;
                        final controller = DefaultTabController.of(context);

                        return Stack(
                          children: [
                            // Custom background indicator
                            AnimatedBuilder(
                              animation: controller.animation!,
                              builder: (context, _) {
                                final animationValue = controller.animation?.value ?? controller.index.toDouble();
                                return AnimatedPositioned(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                  left: animationValue * tabWidth,
                                  top: 0,
                                  bottom: 0,
                                  width: tabWidth,
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                );
                              },
                            ),


                            // TabBar nội dung
                            const TabBar(
                              indicatorColor: Colors.transparent,
                              labelColor: Colors.blueAccent,
                              unselectedLabelColor: Colors.white,
                              labelStyle: TextStyle(fontWeight: FontWeight.bold),
                              tabs: [
                                Tab(
                                  text: "Theo âm IPA",
                                  icon: Icon(Icons.record_voice_over),
                                ),
                                Tab(
                                  text: "Theo chủ đề",
                                  icon: Icon(Icons.menu_book),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Nội dung 2 tab
            const Expanded(
              child: TabBarView(
                children: [
                  IpaListScreen(),
                  ConversationTopicListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
