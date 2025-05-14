import 'package:flutter/material.dart';

void showCustomSnackBar(BuildContext context, bool isCorrect, {String? text}) {
  final overlay = Overlay.of(context);

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _SnackBarBlocker(
      child: _SnackBarAnimationWidget(
        isCorrect: isCorrect,
        text: text,
        onRemove: () => entry.remove(),
      ),
    ),
  );

  overlay.insert(entry);
}

class _SnackBarBlocker extends StatelessWidget {
  final Widget child;

  const _SnackBarBlocker({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // lớp chắn tương tác bên dưới
        Positioned.fill(
          child: GestureDetector(
            onTap: () {}, // chặn chạm
            behavior: HitTestBehavior.opaque,
          ),
        ),
        // lớp snackbar thật
        child,
      ],
    );

  }
}

class _SnackBarAnimationWidget extends StatefulWidget {
  final bool isCorrect;
  final String? text;
  final VoidCallback onRemove;

  const _SnackBarAnimationWidget({
    Key? key,
    required this.isCorrect,
    required this.text,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<_SnackBarAnimationWidget> createState() => _SnackBarAnimationWidgetState();
}

class _SnackBarAnimationWidgetState extends State<_SnackBarAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> offsetAnimation;
  bool dismissedManually = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!dismissedManually) {
        controller.reverse().then((_) => widget.onRemove());
      }
    });
  }

  void _dismiss() {
    if (!dismissedManually) {
      dismissedManually = true;
      controller.reverse().then((_) => widget.onRemove());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: offsetAnimation,
        child: GestureDetector(
          onTap: () {}, // absorb touch
          child: Container(
            height: 80,
            width: double.infinity,
            color: widget.isCorrect ? Colors.green : Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.text ??
                        (widget.isCorrect ? 'Đúng rồi!' : 'Chưa chính xác.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none, // bỏ gạch chân vàng
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _dismiss,
                  splashRadius: 20,
                  tooltip: 'Đóng',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
