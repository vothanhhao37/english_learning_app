import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../services/grammar_service.dart';
import '../../../services/firebase_service.dart';
import 'grammar_detail_screen.dart';

class GrammarPointsList extends StatefulWidget {
  const GrammarPointsList({super.key});

  @override
  State<GrammarPointsList> createState() => _GrammarPointsListState();
}

class _GrammarPointsListState extends State<GrammarPointsList>
    with TickerProviderStateMixin {
  late final AnimationController _backgroundController;
  final Map<int, bool> _expandedItems = {};
  final Map<int, AnimationController> _itemControllers = {};
  final Map<int, AnimationController> _animationControllers = {};

  List<Map<String, dynamic>> _grammarPoints = [];
  bool _isLoading = true;
  late GrammarService _grammarService;

  @override
  void initState() {
    super.initState();
    _grammarService = GrammarService(FirebaseService());
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _fetchGrammarPoints();
  }

  void _fetchGrammarPoints() {
    _grammarService.fetchGrammarPoints().listen((points) {
      if (!mounted) return;
      setState(() {
        _grammarPoints = points;
        for (int i = 0; i < _grammarPoints.length; i++) {
          _itemControllers[i] = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          );
          _animationControllers[i] = AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 600),
          );
          _expandedItems[i] = false;
        }
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (int i = 0; i < _grammarPoints.length; i++) {
          Future.delayed(Duration(milliseconds: i * 50), () {
            if (!mounted) return;
            if (_animationControllers[i] != null && !_animationControllers[i]!.isAnimating) {
              _animationControllers[i]!.forward(from: 0.0);
            }
          });
        }
      });
    }, onError: (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading grammar points: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    for (var controller in _itemControllers.values) {
      controller.dispose();
    }
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleItem(int index) {
    if (!mounted) return;
    setState(() {
      if (_expandedItems[index] == true) {
        _itemControllers[index]!.reverse();
      } else {
        _itemControllers[index]!.forward();
      }
      _expandedItems[index] = !(_expandedItems[index] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: GrammarBackgroundPainter(
                    animation: _backgroundController.value,
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildHeader(),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 144,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGrammarPointsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade800,
            Colors.indigo.shade900,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 30.0),
                  child: Text(
                    "ĐIỂM NGỮ PHÁP",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.search,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "Tìm hiểu các điểm ngữ pháp tiếng Anh cơ bản và nâng cao",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrammarPointsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.purple.shade800,
            Colors.indigo.shade900,
          ],
        ),
      ),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _grammarPoints.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _animationControllers[index]!,
            builder: (context, child) {
              final scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(
                  parent: _animationControllers[index]!,
                  curve: Curves.easeOut,
                ),
              );
              final translateAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
                CurvedAnimation(
                  parent: _animationControllers[index]!,
                  curve: Curves.easeOut,
                ),
              );

              final scale = scaleAnimation.value;
              final translateY = translateAnimation.value;

              return Transform.translate(
                offset: Offset(0.0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: _animationControllers[index]!.value,
                    child: child,
                  ),
                ),
              );
            },
            child: _buildGrammarPointItem(index),
          );
        },
      ),
    );
  }

  Widget _buildGrammarPointItem(int index) {
    final isExpanded = _expandedItems[index] ?? false;
    final details = _grammarPoints[index]['details'] as List<dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isExpanded
              ? [Colors.purple.shade400, Colors.indigo.shade700]
              : [Colors.indigo.shade400, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? Colors.purple.withValues(alpha:0.4)
                : Colors.blue.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha:0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _toggleItem(index),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isExpanded
                        ? [Colors.purple.shade600, Colors.indigo.shade900]
                        : [Colors.indigo.shade600, Colors.blue.shade900],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.menu_book,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _grammarPoints[index]['title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _grammarPoints[index]['description'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha:0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _itemControllers[index]!,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _itemControllers[index]!.value * math.pi,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _itemControllers[index]!,
              builder: (context, child) {
                return ClipRect(
                  child: Align(
                    heightFactor: _itemControllers[index]!.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...List.generate(details.length, (detailIndex) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.amber.withValues(alpha:0.8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (detailIndex + 1).toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        details[detailIndex]['name'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        details[detailIndex]['description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withValues(alpha:0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (detailIndex < details.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 36),
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha:0.2),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GrammarDetailScreen(
                                grammarId: _grammarPoints[index]['id'],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "HỌC NGAY",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GrammarBackgroundPainter extends CustomPainter {
  final double animation;

  GrammarBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.indigo.shade900,
        Colors.blue.shade900,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(GrammarBackgroundPainter oldDelegate) =>
      oldDelegate.animation != animation;
}

class GrammarListPage extends StatelessWidget {
  const GrammarListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GrammarPointsList(),
    );
  }
}