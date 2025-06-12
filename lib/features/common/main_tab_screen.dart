import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../grammar/screens/grammar_point_list.dart';
import '../profile/screens/profile_screen.dart';
import '../vocabulary/screens/topic_list.dart';
import 'pronunciation_home_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // For tab indicator animation
  late List<AnimationController> _tabAnimationControllers;
  late List<Animation<double>> _tabAnimations;

  // Background gradient animation
  late AnimationController _backgroundAnimationController;
  Color _gradientStart = Colors.purple.shade800;
  Color _gradientEnd = Colors.indigo.shade900;

  final List<Widget> _screens = [
    const GrammarPointsList(),
    const PronunciationHomeScreen(),
    const VocabularyTopicListScreen(),
    ProfileScreen(),

  ];

  final List<IconData> _tabIcons = [
    Icons.menu_book,
    Icons.record_voice_over,
    Icons.category,
    Icons.person,
  ];

  final List<String> _tabLabels = [
    'Ngữ pháp',
    'Phát âm',
    'Từ vựng',
    'Cá nhân',

  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);

    // Initialize main animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Initialize background animation
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    // Initialize tab animation controllers
    _tabAnimationControllers = List.generate(
      _tabIcons.length,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );

    // Initialize tab animations
    _tabAnimations = _tabAnimationControllers.map((controller) {
      return Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
      );
    }).toList();

    // Start the animation for the initially selected tab
    _tabAnimationControllers[_selectedIndex].forward();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _updateLastActive();
    }
  }
  Future<void> _updateLastActive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _animationController.dispose();
    _backgroundAnimationController.dispose();
    for (var controller in _tabAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    // If the same tab is tapped again, don't animate
    if (_selectedIndex == index) return;

    // Reverse the previous tab animation
    _tabAnimationControllers[_selectedIndex].reverse();

    setState(() {
      _selectedIndex = index;
    });

    // Animate to the selected page
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Forward the new tab animation
    _tabAnimationControllers[index].forward();
  }

  // For testing the popup


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Important for the floating effect
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(_gradientStart, _gradientEnd, _backgroundAnimationController.value) ?? _gradientStart,
                      Color.lerp(_gradientEnd, _gradientStart, _backgroundAnimationController.value) ?? _gradientEnd,
                    ],
                  ),
                ),
              );
            },
          ),

          // Decorative elements
          Positioned.fill(
            child: CustomPaint(
              painter: DecorationPainter(),
            ),
          ),

          // Content area
          Container(
            margin: const EdgeInsets.only(bottom: 80), // Make room for the bottom nav
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _screens,
                  onPageChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ),
          ),



        ],
      ),

      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade800.withOpacity(0.8),
                  Colors.indigo.shade900.withOpacity(0.8),
                ],
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabIcons.length, (index) {
                  return _buildTabItem(index);
                }),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTabItem(int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedBuilder(
        animation: _tabAnimations[index],
        builder: (context, child) {
          return Transform.scale(
            scale: _tabAnimations[index].value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _tabIcons[index],
                    color: isSelected ? Colors.amber : Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tabLabels[index],
                  style: TextStyle(
                    color: isSelected ? Colors.amber : Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight
                        .normal,
                  ),
                ),
                const SizedBox(height: 2),
                // Indicator dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  width: isSelected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                        : [],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Decorative background painter
class DecorationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Using a fixed seed for consistency
    final paint = Paint()..color = Colors.white.withOpacity(0.1);

    // Draw decorative dots
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final dotSize = random.nextDouble() * 4 + 1;
      canvas.drawCircle(Offset(x, y), dotSize, paint);
    }

    // Draw decorative lines
    for (int i = 0; i < 8; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final endX = startX + (random.nextDouble() - 0.5) * 100;
      final endY = startY + (random.nextDouble() - 0.5) * 100;

      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..strokeWidth = random.nextDouble() * 2 + 0.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(DecorationPainter oldDelegate) => false;
}