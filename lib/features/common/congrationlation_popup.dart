import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class LessonCompletionPopup extends StatefulWidget {
  final String lessonTitle;
  final int correctAnswers;
  final int totalQuestions;
  final VoidCallback onContinue;
  final VoidCallback? onRestart;
  final String? assessment;

  const LessonCompletionPopup({
    super.key,
    required this.lessonTitle,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.onContinue,
    this.onRestart,
    this.assessment,
  });

  // Calculate stars earned based on correct answers ratio
  int get starsEarned {
    return (correctAnswers * 5 / totalQuestions).round();
  }

  // Default total stars is 5
  int get totalStars => 5;

  // Calculate score ratio
  double get scoreRatio => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;

  // Get assessment message based on score ratio
  String get assessmentMessage {
    if (scoreRatio >= 0.8) {
      return "Bạn đã làm rất xuất sắc!";
    } else if (scoreRatio >= 0.65) {
      return "Bạn đã hoàn thành tốt bài tập này!";
    } else if (scoreRatio >= 0.5) {
      return "Hãy cố gắng thêm nhé!";
    } else {
      return "Bạn có thể thử lại để cải thiện kết quả!";
    }
  }

  static void show(
      BuildContext context, {
        required String lessonTitle,
        required int correctAnswers,
        required int totalQuestions,
        required VoidCallback onContinue,
        VoidCallback? onRestart,
        String? assessment,
      }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "Celebration Popup",
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation1, animation2) {
        return LessonCompletionPopup(
          lessonTitle: lessonTitle,
          correctAnswers: correctAnswers,
          totalQuestions: totalQuestions,
          onContinue: onContinue,
          onRestart: onRestart,
          assessment: assessment,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        var curve = Curves.easeInOutBack;
        var curvedAnimation = CurvedAnimation(parent: animation, curve: curve);

        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<LessonCompletionPopup> createState() => _LessonCompletionPopupState();
}

class _LessonCompletionPopupState extends State<LessonCompletionPopup> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _starAnimationController;
  late AnimationController _trophyAnimationController;
  late AnimationController _backgroundController;
  late List<AnimationController> _starControllers;
  late List<Animation<double>> _starScales;
  bool _showAppreciation = false;

  @override
  void initState() {
    super.initState();

    // Confetti controller - adjust duration based on score
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Trophy bounce animation
    _trophyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Star animation controller
    _starAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Background animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Individual star animations
    _starControllers = List.generate(
      widget.totalStars,
          (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 500 + (index * 200)),
      ),
    );

    _starScales = _starControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();

    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Only play confetti for scores >= 0.5
    if (widget.scoreRatio >= 0.5) {
      _confettiController.play();
    }

    _trophyAnimationController.forward();

    // Animate stars sequentially based on stars earned
    for (var i = 0; i < widget.starsEarned; i++) {
      await Future.delayed(Duration(milliseconds: 300 + (i * 300)));
      if (i < _starControllers.length) {
        _starControllers[i].forward();
      }
    }

    // Show appreciation if available
    if (widget.assessment != null) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _showAppreciation = true;
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _starAnimationController.dispose();
    _trophyAnimationController.dispose();
    _backgroundController.dispose();
    for (var controller in _starControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Animated background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CelebrationBackgroundPainter(
                    animation: _backgroundController.value,
                    intensity: _getParticleIntensity(),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: BoxConstraints(
                maxWidth: 400,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple.shade800,
                    Colors.indigo.shade900,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha:0.2),
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  // Decorative elements
                  _buildDecorativeElements(),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Completion text
                        const Text(
                          'HOÀN THÀNH!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Lesson title
                        Text(
                          widget.lessonTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.yellow.shade200,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Trophy animation
                        _buildTrophyAnimation(),

                        const SizedBox(height: 20),

                        // Assessment message
                        Text(
                          widget.assessmentMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getAssessmentColor(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Stars earned
                        _buildStarsRow(),

                        const SizedBox(height: 20),

                        // Correct answers / total questions
                        _buildScoreDisplay(),

                        const SizedBox(height: 16),

                        // Achievement (if unlocked)
                        if (widget.assessment != null)
                          _buildAchievement(),

                        const SizedBox(height: 24),

                        // Action buttons
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti - only show for scores >= 0.5
          if (widget.scoreRatio >= 0.5) ...[
            // Center confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                maxBlastForce: _getConfettiIntensity(5),
                minBlastForce: _getConfettiIntensity(2),
                emissionFrequency: _getConfettiFrequency(),
                numberOfParticles: _getConfettiParticleCount(),
                gravity: 0.1,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ],
              ),
            ),

            // Side confetti - only for higher scores
            if (widget.scoreRatio >= 0.65) ...[
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: -math.pi / 4,
                  emissionFrequency: _getConfettiFrequency(),
                  numberOfParticles: (_getConfettiParticleCount() / 2).round(),
                  maxBlastForce: _getConfettiIntensity(7),
                  minBlastForce: _getConfettiIntensity(3),
                  gravity: 0.3,
                ),
              ),

              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: -3 * math.pi / 4,
                  emissionFrequency: _getConfettiFrequency(),
                  numberOfParticles: (_getConfettiParticleCount() / 2).round(),
                  maxBlastForce: _getConfettiIntensity(7),
                  minBlastForce: _getConfettiIntensity(3),
                  gravity: 0.3,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Helper methods for dynamic confetti based on score
  double _getConfettiFrequency() {
    if (widget.scoreRatio >= 0.8) return 0.05; // More frequent for excellent scores
    if (widget.scoreRatio >= 0.65) return 0.08;
    return 0.1; // Less frequent for lower scores
  }

  int _getConfettiParticleCount() {
    if (widget.scoreRatio >= 0.8) return 20;
    if (widget.scoreRatio >= 0.65) return 12;
    return 8;
  }

  double _getConfettiIntensity(double baseValue) {
    if (widget.scoreRatio >= 0.8) return baseValue;
    if (widget.scoreRatio >= 0.65) return baseValue * 0.8;
    return baseValue * 0.6;
  }

  // Helper method for background particle intensity
  int _getParticleIntensity() {
    if (widget.scoreRatio >= 0.8) return 100; // Many particles
    if (widget.scoreRatio >= 0.65) return 60; // Medium particles
    if (widget.scoreRatio >= 0.5) return 30; // Few particles
    return 10; // Very few particles
  }

  // Helper method for assessment text color
  Color _getAssessmentColor() {
    if (widget.scoreRatio >= 0.8) return Colors.green.shade300;
    if (widget.scoreRatio >= 0.65) return Colors.lightGreen.shade300;
    if (widget.scoreRatio >= 0.5) return Colors.amber.shade300;
    return Colors.orange.shade300;
  }

  Widget _buildDecorativeElements() {
    return Stack(
      children: [
        // Top light circle
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.purple.withValues(alpha:0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom light circle
        Positioned(
          bottom: -60,
          left: -60,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.withValues(alpha:0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Sparkles - adjust number based on score
        ...List.generate(_getParticleIntensity() ~/ 10, (index) {
          final random = math.Random();
          return Positioned(
            top: random.nextDouble() * 300,
            left: random.nextDouble() * 300,
            child: _buildSparkle(
              size: 4.0 + random.nextDouble() * 6,
              duration: Duration(milliseconds: 700 + random.nextInt(1000)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSparkle({required double size, required Duration duration}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(
          opacity: math.sin(value * math.pi),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha:0.8),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }

  Widget _buildTrophyAnimation() {
    return AnimatedBuilder(
      animation: _trophyAnimationController,
      builder: (context, child) {
        final double bounce = -math.sin(_trophyAnimationController.value * math.pi * 4) *
            (1 - _trophyAnimationController.value) * 10;

        final double scale = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _trophyAnimationController,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
        )).value;

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getTrophyColor().shade300,
              _getTrophyColor().shade800,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _getTrophyColor().withValues(alpha:0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _getTrophyIcon(),
            size: 70,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Helper method for trophy color based on score
  MaterialColor _getTrophyColor() {
    if (widget.scoreRatio >= 0.8) return Colors.amber; // Gold
    if (widget.scoreRatio >= 0.65) return Colors.blue; // Silver-blue
    if (widget.scoreRatio >= 0.5) return Colors.orange; // Bronze
    return Colors.grey; // Poor performance
  }

  // Helper method for trophy icon based on score
  IconData _getTrophyIcon() {
    if (widget.scoreRatio >= 0.8) return Icons.emoji_events;
    if (widget.scoreRatio >= 0.65) return Icons.emoji_events;
    if (widget.scoreRatio >= 0.5) return Icons.thumb_up;
    return Icons.refresh; // Suggest trying again
  }

  Widget _buildStarsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.totalStars, (index) {
        final bool isEarned = index < widget.starsEarned;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ScaleTransition(
            scale: _starScales[index],
            child: Icon(
              isEarned ? Icons.star : Icons.star_border,
              size: 40,
              color: isEarned ? Colors.amber : Colors.grey.shade400,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildScoreDisplay() {
    return AnimatedBuilder(
      animation: _trophyAnimationController,
      builder: (context, child) {

        return Column(
          children: [
            const Text(
              'SỐ CÂU LÀM ĐÚNG',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final displayedCorrect = (widget.correctAnswers * value).round();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getScoreColor(),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: _getScoreColor().withValues(alpha:0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        "$displayedCorrect / ${widget.totalQuestions}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  // Helper method for score display color
  Color _getScoreColor() {
    if (widget.scoreRatio >= 0.8) return Colors.green.shade800;
    if (widget.scoreRatio >= 0.65) return Colors.lightGreen.shade700;
    if (widget.scoreRatio >= 0.5) return Colors.amber.shade700;
    return Colors.red.shade700;
  }

  Widget _buildAchievement() {
    return AnimatedOpacity(
      opacity: _showAppreciation ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeIn,
      child: AnimatedScale(
        scale: _showAppreciation ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade300,
                Colors.deepPurple.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha:0.4),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 30,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    Text(
                      widget.assessment!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.onRestart != null) ...[
          ElevatedButton.icon(
            onPressed: widget.onRestart,
            icon: const Icon(Icons.replay),
            label: const Text('LÀM LẠI'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        ElevatedButton.icon(
          onPressed: widget.onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('TIẾP TỤC'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// Background painter
class CelebrationBackgroundPainter extends CustomPainter {
  final double animation;
  final int intensity;

  CelebrationBackgroundPainter({
    required this.animation,
    this.intensity = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // Fixed seed for consistency

    // Adjust number of particles based on intensity
    final particleCount = intensity;

    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sparkSize = random.nextDouble() * 3 + 1;

      // Vary opacity based on animation
      final opacity = (math.sin(animation * 2 * math.pi + i * 0.1) * 0.3 + 0.5).clamp(0.1, 0.8);

      final sparkPaint = Paint()
        ..color = Colors.primaries[random.nextInt(Colors.primaries.length)]
            .withValues(alpha:opacity);

      canvas.drawCircle(Offset(x, y), sparkSize, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(CelebrationBackgroundPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.intensity != intensity;
}

// Example of how to use this widget
void showCompletionPopup(BuildContext context) {
  LessonCompletionPopup.show(
    context,
    lessonTitle: "Bài 3: Từ vựng cơ bản",
    correctAnswers: 12,  // Example: 12 correct answers
    totalQuestions: 15,  // Example: out of 15 total questions
    assessment: "Học 5 ngày liên tiếp!",
    onContinue: () {
      Navigator.of(context).pop();
      // Tiếp tục tới bài học tiếp theo
    },
    onRestart: () {
      Navigator.of(context).pop();
      // Làm lại bài học
    },
  );
}