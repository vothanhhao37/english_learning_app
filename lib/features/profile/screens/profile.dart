import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController(
    text: "Nguyễn Văn A",
  );
  final TextEditingController _emailController = TextEditingController(
    text: "example@gmail.com",
  );
  bool _isEditing = false;

  // Biến cho phần ngữ pháp
  List<Map<String, dynamic>> grammarProgress = [];
  double overallGrammarProgress = 0.0;
  bool _isLoading = true;
  DateTime? _lastLoadTime;

  // Biến cho phần phát âm
  List<Map<String, dynamic>> pronunciationProgress = [];
  double overallPronunciationProgress = 0.0;
  bool _isLoadingPronunciation = true;
  DateTime? _lastPronunciationLoadTime;

  // Biến cho từ vựng
  List<Map<String, dynamic>> vocabularyProgress = [];
  double overallVocabularyProgress = 0.0;
  bool _isLoadingVocabulary = true;
  DateTime? _lastVocabLoadTime;

  // Biến mới cho phần hội thoại
  List<Map<String, dynamic>> conversationProgress = [];
  double overallConversationProgress = 0.0;
  bool _isLoadingConversation = true;
  DateTime? _lastConversationLoadTime;

  final _cacheThreshold = Duration(minutes: 5); // Chỉ tải lại sau 5 phút

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserProfile(); // Add this line
    _loadGrammarProgress();
    _loadPronunciationProgress();
    _loadVocabularyProgress();
    _loadConversationProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          setState(() {
            _nameController.text = userData['name'] ?? "Người dùng";
            _emailController.text = userData['email'] ?? user.email ?? "example@gmail.com";
          });
        }
      } catch (e) {
        print('Lỗi khi tải thông tin người dùng: $e');
      }
    }
  }
  // Thêm phương thức tải dữ liệu hội thoại từ Firestore
  Future<void> _loadConversationProgress() async {
    final now = DateTime.now();
    if (_lastConversationLoadTime != null &&
        now.difference(_lastConversationLoadTime!) < _cacheThreshold &&
        conversationProgress.isNotEmpty) {
      setState(() {
        _isLoadingConversation = false;
      });
      return;
    }

    setState(() {
      _isLoadingConversation = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingConversation = false;
      });
      return;
    }

    try {
      // Lấy summary tổng thể
      final summaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('conversation')
          .get();
      final summaryData = summaryDoc.data()?['summary'] ?? {};
      double calculatedOverallProgress = summaryData['overallCompletion']?.toDouble() ?? 0.0;

      // Lấy danh sách tất cả topics từ pronunciation_topics
      final allTopicsSnapshot = await FirebaseFirestore.instance
          .collection('pronunciation_topics')
          .get();

      // Lấy danh sách topics mà người dùng đã học từ learningProgress/conversation/topics
      final userTopicsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('conversation')
          .collection('topics')
          .get();

      Map<String, Map<String, dynamic>> userTopicsMap = {};
      for (var doc in userTopicsSnapshot.docs) {
        userTopicsMap[doc.id] = doc.data();
      }

      List<Map<String, dynamic>> allTopicsProgress = [];
      for (var topicDoc in allTopicsSnapshot.docs) {
        final String topicId = topicDoc.id;
        final Map<String, dynamic> topicData = topicDoc.data();
        final userData = userTopicsMap[topicId] ?? {};
        // Lấy số lesson thực tế của topic
        final lessonsSnapshot = await FirebaseFirestore.instance
            .collection('pronunciation_topics')
            .doc(topicId)
            .collection('lessons')
            .get();
        int topicTotalLessons = lessonsSnapshot.docs.length;
        int topicPossibleScore = topicTotalLessons * 100;
        int topicBestScore = 0;
        int topicCompletedLessons = userData['completedLessons'] ?? 0;
        // Tính tổng điểm bestScore thực tế của user cho topic này
        for (var lessonDoc in lessonsSnapshot.docs) {
          final lessonId = lessonDoc.id;
          final userLessonDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('learningProgress')
              .doc('conversation')
              .collection('lessons')
              .doc(lessonId)
              .get();
          if (userLessonDoc.exists) {
            final data = userLessonDoc.data();
            // Chỉ cộng nếu lesson này thuộc topic hiện tại!
            if (data?['topicId'] == topicId) {
              if (data?['type'] == 'sentence' || data?['type'] == 'single_sentence') {
                topicBestScore += (data?['bestScore'] is int)
                    ? data!['bestScore'] as int
                    : (data?['bestScore'] is num)
                    ? (data!['bestScore'] as num).toInt()
                    : int.tryParse(data?['bestScore']?.toString() ?? '0') ?? 0;
              } else if (data?['type'] == 'dialogue') {
                final bestScores = data?['bestScores'] as Map<String, dynamic>? ?? {};
                for (var score in bestScores.values) {
                  topicBestScore += score is int ? score : score is num ? score.toInt() : int.tryParse(score.toString()) ?? 0;
                }
              }
            }
          }
        }
        // Tính phần trăm hoàn thành dựa trên điểm (clamp về 100%)
        double topicProgress = topicPossibleScore > 0 ? (topicBestScore / topicPossibleScore).clamp(0.0, 1.0) : 0.0;
        allTopicsProgress.add({
          'topic_id': topicId,
          'title': topicData['title'] ?? 'Chủ đề $topicId',
          'description': topicData['description'] ?? 'Chưa có mô tả',
          'imageUrl': topicData['imageUrl'] ?? '',
          'totalLessons': topicTotalLessons,
          'completedLessons': topicCompletedLessons,
          'totalScore': topicPossibleScore,
          'bestScore': topicBestScore,
          'progress': topicProgress,
        });
      }

      allTopicsProgress.sort((a, b) => b['progress'].compareTo(a['progress']));

      setState(() {
        conversationProgress = allTopicsProgress;
        overallConversationProgress = calculatedOverallProgress;
        _isLoadingConversation = false;
        _lastConversationLoadTime = now;
      });
    } catch (e) {
      setState(() {
        _isLoadingConversation = false;
      });
    }
  }

  Future<void> _loadGrammarProgress() async {
    final now = DateTime.now();
    // Kiểm tra cache
    if (_lastLoadTime != null &&
        now.difference(_lastLoadTime!) < _cacheThreshold &&
        grammarProgress.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Vui lòng đăng nhập để xem tiến trình');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. Truy vấn tất cả topic từ grammar (một lần duy nhất)
      final grammarSnapshot =
      await FirebaseFirestore.instance.collection('grammar').get();

      // 2. Truy vấn tiến trình từ grammarSummary (một lần duy nhất)
      final summarySnapshot =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('grammarSummary')
          .collection('grammarSummary')
          .get();

      // Tạo map từ grammarSummary để dễ tra cứu
      final summaryMap = {
        for (var doc in summarySnapshot.docs) doc.id: doc.data(),
      };

      // 3. Thực hiện song song các truy vấn exercises
      final List<Future<Map<String, dynamic>>> futures = [];

      for (var grammarDoc in grammarSnapshot.docs) {
        final grammarId = grammarDoc.id;
        final grammarData = grammarDoc.data();
        futures.add(_processGrammarTopic(grammarId, grammarData, summaryMap));
      }

      // Chờ tất cả các truy vấn hoàn thành cùng lúc
      final results = await Future.wait(futures);

      // Tính tổng số câu hỏi và số câu đúng trên toàn bộ grammar
      int totalQuestionsAcrossAllTopics = 0;
      int totalCorrectAcrossAllTopics = 0;

      for (var result in results) {
        totalQuestionsAcrossAllTopics += result['totalQuestions'] as int;
        totalCorrectAcrossAllTopics += result['totalCorrect'] as int;
      }

      // Tính overallGrammarProgress
      double calculatedOverallProgress =
      totalQuestionsAcrossAllTopics > 0
          ? totalCorrectAcrossAllTopics / totalQuestionsAcrossAllTopics
          : 0.0;

      // Sắp xếp theo progress giảm dần (từ cao đến thấp)
      results.sort((a, b) => b['progress'].compareTo(a['progress']));

      setState(() {
        grammarProgress = results;
        overallGrammarProgress = calculatedOverallProgress;
        _isLoading = false;
        _lastLoadTime = now;
      });
    } catch (e) {
      print('Lỗi khi tải tiến trình ngữ pháp: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Thêm phương thức tải dữ liệu từ vựng
  Future<void> _loadVocabularyProgress() async {
    final now = DateTime.now();
    if (_lastVocabLoadTime != null &&
        now.difference(_lastVocabLoadTime!) < _cacheThreshold &&
        vocabularyProgress.isNotEmpty) {
      setState(() {
        _isLoadingVocabulary = false;
      });
      return;
    }

    setState(() {
      _isLoadingVocabulary = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingVocabulary = false;
      });
      return;
    }

    try {
      // Get all vocabulary topics
      final allTopicsSnap = await FirebaseFirestore.instance
          .collection('vocabs_topics')
          .get();

      // Get overall vocabulary summary
      final summaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('vocabulary')
          .get();

      final summaryData = summaryDoc.data()?['summary'] ?? {};
      final double calculatedOverallProgress = summaryData['overallProgress']?.toDouble() ?? 0.0;

      // Process each topic
      List<Map<String, dynamic>> topicsProgress = [];
      for (var topicDoc in allTopicsSnap.docs) {
        final topicId = topicDoc.id;
        final topicData = topicDoc.data();

        // Get topic summary
        final topicSummaryDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('learningProgress')
            .doc('vocabulary')
            .collection(topicId)
            .doc('summary')
            .get();

        final topicSummary = topicSummaryDoc.data() ?? {};
        final int totalQuestions = topicSummary['totalQuestions'] ?? 0;
        final int completedQuestions = topicSummary['completedQuestions'] ?? 0;
        final int correctQuestions = topicSummary['correctQuestions'] ?? 0;

        // Calculate progress (completed/total) and accuracy (correct/completed)
        final double progress = totalQuestions > 0 ? completedQuestions / totalQuestions : 0.0;
        final double accuracy = completedQuestions > 0 ? correctQuestions / completedQuestions : 0.0;

        topicsProgress.add({
          'topic_id': topicId,
          'title': topicData['title'] ?? 'Chủ đề $topicId',
          'description': topicData['description'] ?? 'Chưa có mô tả',
          'progress': progress,
          'accuracy': accuracy,
          'totalQuestions': totalQuestions,
          'completedQuestions': completedQuestions,
          'correctQuestions': correctQuestions,
        });
      }

      // Sort by progress
      topicsProgress.sort((a, b) => b['progress'].compareTo(a['progress']));

      setState(() {
        vocabularyProgress = topicsProgress;
        overallVocabularyProgress = calculatedOverallProgress;
        _isLoadingVocabulary = false;
        _lastVocabLoadTime = now;
      });
    } catch (e) {
      print('Error loading vocabulary progress: $e');
      setState(() {
        _isLoadingVocabulary = false;
      });
    }
  }

  // Phương thức tải dữ liệu phát âm
  Future<void> _loadPronunciationProgress() async {
    final now = DateTime.now();
    // Kiểm tra cache
    if (_lastPronunciationLoadTime != null &&
        now.difference(_lastPronunciationLoadTime!) < _cacheThreshold &&
        pronunciationProgress.isNotEmpty) {
      setState(() {
        _isLoadingPronunciation = false;
      });
      return;
    }

    setState(() {
      _isLoadingPronunciation = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Vui lòng đăng nhập để xem tiến trình');
      setState(() {
        _isLoadingPronunciation = false;
      });
      return;
    }

    try {
      // Lấy dữ liệu tổng quan về phát âm từ tiến trình học của người dùng
      final pronunciationSummaryDoc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('ipa')
          .get();

      Map<String, dynamic>? pronunciationSummaryData;
      if (pronunciationSummaryDoc.exists) {
        pronunciationSummaryData = pronunciationSummaryDoc.data();
      }

      // Trích xuất thống kê tổng thể
      final int totalTopics =
          pronunciationSummaryData?['summary']?['totalTopics'] ?? 0;
      final int totalQuestions =
          pronunciationSummaryData?['summary']?['totalQuestions'] ?? 0;
      final int totalCompletedQuestions =
          pronunciationSummaryData?['summary']?['totalCompletedQuestions'] ?? 0;
      final int totalCorrectQuestions =
          pronunciationSummaryData?['summary']?['totalCorrectQuestions'] ?? 0;

      // Tính toán tiến độ tổng thể
      final double calculatedOverallProgress =
      totalQuestions > 0 ? totalCorrectQuestions / totalQuestions : 0.0;

      // Lấy danh sách âm IPA mà người dùng đã làm bài
      final List<dynamic> userIpaTopics =
          pronunciationSummaryData?['summary']?['topics'] ?? [];

      // Lấy tất cả IPA có sẵn
      final allIpasSnapshot =
      await FirebaseFirestore.instance
          .collection('ipa_pronunciation')
          .get();

      // Tạo một danh sách để lưu dữ liệu tiến độ của tất cả âm IPA
      final List<Map<String, dynamic>> ipaProgress = [];

      // Lấy chi tiết cho tất cả âm IPA có sẵn
      for (var ipaDoc in allIpasSnapshot.docs) {
        final String ipaId = ipaDoc.id;
        final ipaData = ipaDoc.data();

        // Lấy thông tin nhóm và loại
        final String group = ipaData['group'] ?? '';
        final String translatedGroup = ipaData['translated_group'] ?? group;
        final String type = ipaData['type'] ?? '';
        final String translatedType = ipaData['translated_type'] ?? type;

        // Số câu đúng và số câu đã làm mặc định là 0
        int completedQuestions = 0;
        int correctQuestions = 0;

        // Nếu người dùng đã làm bài với IPA này, lấy thông tin chi tiết
        if (userIpaTopics.contains(ipaId)) {
          final ipaDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('learningProgress')
              .doc('ipa')
              .collection(ipaId)
              .doc('summary')
              .get();

          if (ipaDoc.exists && ipaDoc.data() != null) {
            final data = ipaDoc.data()!;
            completedQuestions = data['completedQuestions'] as int? ?? 0;
            correctQuestions = data['correctQuestions'] as int? ?? 0;
          }
        }

        // Tổng số câu hỏi từ topicsQuestions nếu có, hoặc truy vấn trực tiếp
        int ipaTotalQuestions = 0;
        if (pronunciationSummaryData != null &&
            pronunciationSummaryData['summary'] != null &&
            pronunciationSummaryData['summary']['topicsQuestions'] != null) {
          final Map<String, dynamic> topicsQuestions =
          Map<String, dynamic>.from(
            pronunciationSummaryData['summary']['topicsQuestions'],
          );

          if (topicsQuestions.containsKey(ipaId)) {
            ipaTotalQuestions = topicsQuestions[ipaId] as int? ?? 0;
          }
        }

        // Nếu không có trong cache, truy vấn trực tiếp
        if (ipaTotalQuestions == 0) {
          final lessonsSnapshot =
          await FirebaseFirestore.instance
              .collection('ipa_pronunciation')
              .doc(ipaId)
              .collection('lessons')
              .get();

          ipaTotalQuestions = lessonsSnapshot.docs.length;
        }

        // Tính số câu đúng / tổng số câu
        final double progress =
        ipaTotalQuestions > 0 ? correctQuestions / ipaTotalQuestions : 0.0;

        // Format the title for display with capitalized group and type
        String groupDisplay =
        translatedGroup.isNotEmpty
            ? '${translatedGroup[0].toUpperCase()}${translatedGroup.substring(1)}'
            : '';

        String typeDisplay =
        translatedType.isNotEmpty
            ? '${translatedType[0].toUpperCase()}${translatedType.substring(1)}'
            : '';

        final String title = '$ipaId - $typeDisplay';
        final String description =
            '$groupDisplay ($group) - $typeDisplay ($type)';

        ipaProgress.add({
          'topic_id': ipaId,
          'title': title,
          'description': description,
          'progress': progress,
          'totalCorrect': correctQuestions,
          'totalQuestions': ipaTotalQuestions,
          'completedQuestions': completedQuestions,
          'group': group,
          'type': type,
        });
      }

      // Sắp xếp theo tiến độ từ cao đến thấp
      ipaProgress.sort((a, b) => b['progress'].compareTo(a['progress']));

      setState(() {
        pronunciationProgress = ipaProgress;
        overallPronunciationProgress = calculatedOverallProgress;
        _isLoadingPronunciation = false;
        _lastPronunciationLoadTime = now;
      });
    } catch (e) {
      print('Lỗi khi tải tiến trình phát âm: $e');
      setState(() {
        _isLoadingPronunciation = false;
      });
    }
  }

  // Hàm xử lý riêng cho mỗi topic grammar
  Future<Map<String, dynamic>> _processGrammarTopic(
      String grammarId,
      Map<String, dynamic> grammarData,
      Map<String, dynamic> summaryMap,
      ) async {
    // Lấy tổng số câu hỏi từ exercises
    final exercisesSnapshot =
    await FirebaseFirestore.instance
        .collection('grammar')
        .doc(grammarId)
        .collection('exercises')
        .get();

    int totalQuestions = exercisesSnapshot.docs.length;

    // Lấy dữ liệu từ grammarSummary (nếu có)
    final summaryData = summaryMap[grammarId];
    int totalCorrect =
    summaryData != null ? (summaryData['totalCorrect'] ?? 0) : 0;
    double progress = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;

    return {
      'topic_id': grammarId,
      'title':
      grammarData['title'] ?? grammarId.replaceAll('_', ' ').toUpperCase(),
      'description':
      grammarData['description'] ?? 'Chưa có mô tả cho chủ đề này',
      'progress': progress,
      'totalCorrect': totalCorrect,
      'totalQuestions': totalQuestions,
    };
  }

  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3A2B71), Color(0xFF8A4EFC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Bạn chắc chắn muốn đăng xuất?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha:0.3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();

                        Navigator.pop(context); // Đóng popup
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF8A4EFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3A2B71),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A2B71),
        elevation: 0,
        title: const Text(
          'CÁ NHÂN',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              showLogoutDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          _buildProgressSection(),
          const SizedBox(height: 10),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrammarProgressTab(),
                _buildPronunciationProgressTab(),
                _buildVocabularyProgressTab(),
                _buildConversationProgressTab(), // Thêm tab hội thoại
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha:0.2),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Center(
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isEditing
                        ? TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    )
                        : Text(
                      _nameController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _isEditing
                        ? TextField(
                      controller: _emailController,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.8),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha:0.5),
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    )
                        : Text(
                      _emailController.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha:0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check : Icons.edit,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_isEditing) {
                    // Save changes to Firestore
                    _saveUserProfileChanges();
                  }
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserProfileChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Update the Firestore document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'name': _nameController.text,
          'email': _emailController.text,
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thông tin đã được cập nhật'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Lỗi khi cập nhật thông tin: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi cập nhật thông tin'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến độ học tập',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressItem(
                  'Ngữ pháp',
                  overallGrammarProgress,
                  Colors.amber,
                ),
                _buildProgressItem(
                  'IPA',
                  overallPronunciationProgress,
                  Colors.greenAccent,
                ),
                _buildProgressItem(
                  'Từ vựng',
                  overallVocabularyProgress,
                  Colors.purpleAccent,
                ),
                _buildProgressItem(
                  'Hội thoại',
                  overallConversationProgress,
                  Colors.blueAccent,
                ), // Thêm vòng tròn hội thoại
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, double progress, Color color) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          width: 60,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  height: 50,
                  width: 50,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha:0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(color: Colors.white.withValues(alpha:0.9), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 4; // Sửa thành 4 tabs
          return Stack(
            children: [
              AnimatedBuilder(
                animation: _tabController.animation!,
                builder: (context, _) {
                  final animationValue =
                      _tabController.animation?.value ??
                          _tabController.index.toDouble();
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    left: animationValue * tabWidth,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  );
                },
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.transparent,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
                tabs: const [
                  Tab(text: 'Ngữ pháp'),
                  Tab(text: 'Phát âm'),
                  Tab(text: 'Từ vựng'),
                  Tab(text: 'Hội thoại'), // Thêm tab hội thoại
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrammarProgressTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (grammarProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chưa có dữ liệu tiến trình',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGrammarProgress,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grammarProgress.length,
      itemBuilder: (context, index) {
        final progress = grammarProgress[index];
        return _buildProgressCard(
          progress['title'],
          progress['progress'].toDouble(),
          progress['description'],
        );
      },
    );
  }

  Widget _buildPronunciationProgressTab() {
    if (_isLoadingPronunciation) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (pronunciationProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chưa có dữ liệu tiến trình phát âm',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPronunciationProgress,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pronunciationProgress.length,
      itemBuilder: (context, index) {
        final progress = pronunciationProgress[index];
        return _buildProgressCard(
          progress['title'],
          progress['progress'],
          '${progress['totalCorrect']}/${progress['totalQuestions']} câu đúng (${progress['completedQuestions']}/${progress['totalQuestions']} đã làm)',
        );
      },
    );
  }

  // Cập nhật tab từ vựng
  Widget _buildVocabularyProgressTab() {
    if (_isLoadingVocabulary) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (vocabularyProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chưa có dữ liệu tiến trình từ vựng',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVocabularyProgress,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vocabularyProgress.length,
      itemBuilder: (context, index) {
        final progress = vocabularyProgress[index];
        final int correctQuestions = progress['correctQuestions'] ?? 0;
        final int completedQuestions = progress['completedQuestions'] ?? 0;
        final int totalQuestions = progress['totalQuestions'] ?? 0;
        final double accuracy = progress['accuracy'] ?? 0.0;
        
        String display = '$correctQuestions/$completedQuestions câu đúng (tổng $totalQuestions câu)';
        if (completedQuestions > 0) {
          display += ' - Độ chính xác: ${(accuracy * 100).toInt()}%';
        }
        
        return _buildProgressCard(
          progress['title'],
          progress['progress'],
          display,
        );
      },
    );
  }

  // Thêm tab hiển thị tiến trình học hội thoại
  Widget _buildConversationProgressTab() {
    if (_isLoadingConversation) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (conversationProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chưa có dữ liệu tiến trình hội thoại',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversationProgress,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conversationProgress.length,
      itemBuilder: (context, index) {
        final progress = conversationProgress[index];
        return _buildConversationCard(
          progress['title'],
          progress['progress'],
          progress['bestScore'],
          progress['totalScore'],
          progress['completedLessons'],
          progress['totalLessons'],
          progress['imageUrl'],
        );
      },
    );
  }

  // Card đặc biệt cho phần hội thoại
  Widget _buildConversationCard(
      String title,
      double progress,
      int bestScore,
      int totalScore,
      int completedLessons,
      int totalLessons,
      String imageUrl,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header với hình ảnh chủ đề (nếu có)
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 80,
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$bestScore/$totalScore điểm',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$completedLessons/$totalLessons bài học đã hoàn thành',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getProgressColor(progress),
                      ),
                      child: Center(
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progress),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, double progress, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getProgressColor(progress),
                  ),
                  child: Center(
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(progress),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.4) {
      return Colors.redAccent;
    } else if (progress < 0.7) {
      return Colors.orangeAccent;
    } else {
      return Colors.greenAccent;
    }
  }
}