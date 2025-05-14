import 'package:flutter/material.dart';

class CustomSnackBarClaude {
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    // Đóng snackbar hiện tại nếu có
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Lấy thông tin về snackbar dựa trên loại
    final snackBarInfo = _getSnackBarInfo(type);

    final snackBar = SnackBar(
      content: Container(
        padding: EdgeInsets.zero,
        child: _CustomSnackBarContent(
          message: message,
          type: type,
          icon: snackBarInfo.icon,
          color: snackBarInfo.color,
          onTap: onTap,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.zero,
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static _SnackBarInfo _getSnackBarInfo(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarInfo(
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green,
        );
      case SnackBarType.error:
        return _SnackBarInfo(
          icon: Icons.error_outline_rounded,
          color: Colors.red,
        );
      case SnackBarType.warning:
        return _SnackBarInfo(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        );
      case SnackBarType.info:
      default:
        return _SnackBarInfo(
          icon: Icons.info_outline_rounded,
          color: Colors.blue,
        );
    }
  }
}

class _CustomSnackBarContent extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CustomSnackBarContent({
    required this.message,
    required this.type,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  State<_CustomSnackBarContent> createState() => _CustomSnackBarContentState();
}

class _CustomSnackBarContentState extends State<_CustomSnackBarContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  border: Border.all(color: widget.color.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.color.withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: widget.color.withOpacity(0.6),
                        size: 20,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

class _SnackBarInfo {
  final IconData icon;
  final Color color;

  _SnackBarInfo({
    required this.icon,
    required this.color,
  });
}

// Ví dụ sử dụng:
class SnackBarExample extends StatelessWidget {
  const SnackBarExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Snackbar Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                CustomSnackBarClaude.show(
                  context: context,
                  message: 'Thông tin đã được lưu thành công!',
                  type: SnackBarType.success,
                );
              },
              child: const Text('Show Success Snackbar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                CustomSnackBarClaude.show(
                  context: context,
                  message: 'Có lỗi xảy ra, vui lòng thử lại!',
                  type: SnackBarType.error,
                );
              },
              child: const Text('Show Error Snackbar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                CustomSnackBarClaude.show(
                  context: context,
                  message: 'Cảnh báo: Dữ liệu sắp hết hạn!',
                  type: SnackBarType.warning,
                );
              },
              child: const Text('Show Warning Snackbar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                CustomSnackBarClaude.show(
                  context: context,
                  message: 'Đây là thông báo thông tin!',
                  type: SnackBarType.info,
                );
              },
              child: const Text('Show Info Snackbar'),
            ),
          ],
        ),
      ),
    );
  }
}