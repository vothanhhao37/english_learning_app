import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FocusScope.of(context).unfocus();
        });
      }
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  Future<void> _saveUserToFirestore(User user) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final snapshot = await userDoc.get();
    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'name': user.displayName ?? 'Người dùng',
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'avatarUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } else {
      // Cập nhật last active nếu đã tồn tại
      await userDoc.update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    }
  }

  // Đăng nhập bằng Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Lưu dữ liệu người dùng vào Firestore
        await _saveUserToFirestore(user);
        // Đăng nhập thành công, điều hướng đến màn hình chính
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // Xử lý lỗi đăng nhập
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập thất bại: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Gửi mã OTP đến số điện thoại
  Future<void> _verifyPhoneNumber() async {
    final sdt = _phoneController.text.trim();
    if (sdt.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+84$sdt',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            await _saveUserToFirestore(user);
            Navigator.pushReplacementNamed(context, '/home');
          }
          setState(() {
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });

          String message;
          if (e.code == 'billing-not-enabled' || e.message?.contains('BILLING_NOT_ENABLED') == true) {
            message = 'Tính năng đăng nhập bằng số điện thoại hiện chưa được kích hoạt. Vui lòng thử lại sau.';
          } else {
            message = 'Đăng nhập thất bại: ${e.message ?? 'Lỗi không xác định.'}';
          }

          showDialog(
            context: context,
            builder: (ctx) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF3A2B71), // tím đậm
                        Color(0xFF8A4EFC), // tím nhạt
                      ],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Lỗi xác thực',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text('Đóng', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã xảy ra lỗi'),
          content: Text('Vui lòng thử lại. Chi tiết: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }



  // Xác thực mã OTP
  Future<void> _verifyOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Lưu dữ liệu người dùng
        await _saveUserToFirestore(user);
        // chuyển hướng đến trang chủ
        Navigator.pushReplacementNamed(context, '/home');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mã OTP không hợp lệ: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3A2B71),
              Color(0xFF8A4EFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildLogo(),
              const SizedBox(height: 30),
              _buildWelcomeText(),
              const SizedBox(height: 40),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGoogleSignIn(),
                    _buildPhoneSignIn(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          "E",
          style: TextStyle(
            color: const Color(0xFF8A4EFC),
            fontSize: 70,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Color.fromRGBO(0, 0, 0, 0.1),
                offset: const Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: const [
        Text(
          "Chào mừng đến với",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "LINGO BUDDY",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: 15),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Ứng dụng giúp bạn học tiếng Anh mọi lúc mọi nơi với phương pháp hiệu quả",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 49,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 2;

          return Stack(
            children: [
              // Custom background indicator (vùng trắng di chuyển)
              AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, _) {
                  final animationValue = _tabController.animation?.value ?? _tabController.index.toDouble();
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    left: animationValue * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  );
                },
              ),

              // TabBar nội dung
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.transparent,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Google'),
                  Tab(text: 'Số điện thoại'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildGoogleSignIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 70,bottom: 70),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Đăng nhập nhanh chóng và dễ dàng",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF8A4EFC),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/google_logo.png',
                  height: 24,
                ),
                const SizedBox(width: 15),
                _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8A4EFC),
                  ),
                )
                    : const Text(
                  "Đăng nhập với Google",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            "Bằng việc đăng nhập, bạn đồng ý với điều khoản\nsử dụng của ứng dụng",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSignIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: !_codeSent ? _buildPhoneInput() : _buildOtpInput(),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      children: [
        const Text(
          "Vui lòng nhập số điện thoại của bạn",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 30),
        Container(
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: TextFormField(
            controller: _phoneController,
            onChanged: (_) => setState(() {}), // rebuild nút
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: "Nhập số điện thoại",
              hintStyle: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.7)),
              prefixIcon: Container(
                padding: const EdgeInsets.all(15),
                child: Text(
                  "+84",
                  style: TextStyle(
                    color: Color.fromRGBO(255, 255, 255, 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _isLoading || !_isValidPhoneNumber(_phoneController.text)
              ? null
              : _verifyPhoneNumber,

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF8A4EFC),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          ),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF8A4EFC),
            ),
          )
              : const Text(
            "Tiếp tục",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "Chúng tôi sẽ gửi mã xác nhận tới số điện thoại của bạn",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  bool _isValidPhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 9 && digits.length <= 11;
  }
  Widget _buildOtpInput() {
    return Column(
      children: [
        const Text(
          "Nhập mã xác nhận",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Mã xác nhận đã được gửi đến\n+84${_phoneController.text}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.7),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 30),
        _buildOtpBoxes(),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _isLoading || _otpController.text.length < 6
              ? null
              : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF8A4EFC),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
          ),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF8A4EFC),
            ),
          )
              : const Text(
            "Xác nhận",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _isLoading ? null : _verifyPhoneNumber,
          child: Text(
            "Gửi lại mã",
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.9),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
            setState(() {
              _codeSent = false;
              _otpController.clear();
            });
          },
          child: Text(
            "Thay đổi số điện thoại",
            style: TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.9),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBoxes() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: PinCodeTextField(
        appContext: context,
        length: 6,
        obscureText: false,
        animationType: AnimationType.fade,
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(10),
          fieldHeight: 50,
          fieldWidth: 40,
          activeFillColor: Colors.white,
          activeColor: Colors.white,
          selectedColor: const Color(0xFF8A4EFC),
          selectedFillColor: Colors.white,
          inactiveColor: Color.fromRGBO(255, 255, 255, 0.5),
          inactiveFillColor: Color.fromRGBO(255, 255, 255, 0.2),
        ),
        animationDuration: const Duration(milliseconds: 300),
        enableActiveFill: true,
        controller: _otpController,
        onCompleted: (v) {
          // Tự động xác thực khi nhập đủ 6 số
          if (_otpController.text.length == 6) {
            _verifyOTP();
          }
        },
        onChanged: (value) {
          setState(() {
            // Cập nhật giá trị khi thay đổi
          });
        },
        beforeTextPaste: (text) {
          // Chỉ cho phép dán số
          return text?.contains(RegExp(r'^[0-9]+$')) ?? false;
        },
        keyboardType: TextInputType.number,
        textStyle: const TextStyle(
          color: Color(0xFF8A4EFC),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

// Widget PinCodeTextField tự tạo (để không phải sử dụng thư viện ngoài)
class PinCodeTextField extends StatefulWidget {
  final BuildContext appContext;
  final int length;
  final bool obscureText;
  final AnimationType animationType;
  final PinTheme pinTheme;
  final Duration animationDuration;
  final bool enableActiveFill;
  final TextEditingController controller;
  final Function(String) onCompleted;
  final Function(String) onChanged;
  final bool Function(String?)? beforeTextPaste;
  final TextInputType keyboardType;
  final TextStyle textStyle;

  const PinCodeTextField({
    Key? key,
    required this.appContext,
    required this.length,
    this.obscureText = false,
    this.animationType = AnimationType.fade,
    required this.pinTheme,
    this.animationDuration = const Duration(milliseconds: 300),
    this.enableActiveFill = false,
    required this.controller,
    required this.onCompleted,
    required this.onChanged,
    this.beforeTextPaste,
    this.keyboardType = TextInputType.number,
    required this.textStyle,
  }) : super(key: key);

  @override
  _PinCodeTextFieldState createState() => _PinCodeTextFieldState();
}

class _PinCodeTextFieldState extends State<PinCodeTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              widget.length,
                  (index) {
                bool isSelected = widget.controller.text.length == index;
                bool isCompleted = widget.controller.text.length > index;

                return AnimatedContainer(
                  duration: widget.animationDuration,
                  width: widget.pinTheme.fieldWidth,
                  height: widget.pinTheme.fieldHeight,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? widget.pinTheme.activeFillColor
                        : isSelected
                        ? widget.pinTheme.selectedFillColor
                        : widget.pinTheme.inactiveFillColor,
                    borderRadius: widget.pinTheme.borderRadius,
                    border: Border.all(
                      width: 1,
                      color: isCompleted
                          ? widget.pinTheme.activeColor
                          : isSelected
                          ? widget.pinTheme.selectedColor
                          : widget.pinTheme.inactiveColor,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Text(
                      widget.obscureText
                          ? '•'
                          : widget.controller.text[index],
                      style: widget.textStyle,
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              maxLength: widget.length,
              showCursor: false,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              onChanged: (text) {
                setState(() {
                  widget.onChanged(text);
                  if (text.length == widget.length) {
                    widget.onCompleted(text);
                  }
                });
              },
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          // Lớp GestureDetector để bắt sự kiện chạm
          GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
            },
            child: Container(
              width: double.infinity,
              height: widget.pinTheme.fieldHeight,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

// Enums phụ trợ
enum AnimationType { fade, scale, slide, none }

class PinTheme {
  final PinCodeFieldShape shape;
  final BorderRadius borderRadius;
  final double fieldHeight;
  final double fieldWidth;
  final Color activeFillColor;
  final Color activeColor;
  final Color selectedColor;
  final Color selectedFillColor;
  final Color inactiveColor;
  final Color inactiveFillColor;

  const PinTheme({
    this.shape = PinCodeFieldShape.box,
    this.borderRadius = BorderRadius.zero,
    this.fieldHeight = 50,
    this.fieldWidth = 40,
    this.activeFillColor = Colors.white,
    this.activeColor = Colors.blue,
    this.selectedColor = Colors.blue,
    this.selectedFillColor = Colors.white,
    this.inactiveColor = Colors.grey,
    this.inactiveFillColor = Colors.transparent,
  });
}

enum PinCodeFieldShape { box, circle, underline }