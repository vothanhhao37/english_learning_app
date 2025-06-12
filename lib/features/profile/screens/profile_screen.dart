import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../models/profile_model.dart';
import '../../../services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';


// ======= ProfileHeader widget =======
class ProfileHeader extends StatelessWidget {
  final ProfileModel? profile;
  final VoidCallback? onEdit;
  const ProfileHeader({Key? key, required this.profile, this.onEdit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (profile == null) return const SizedBox.shrink();
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
                  color: Colors.white.withOpacity(0.2),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.amber),
                            tooltip: 'Chỉnh sửa thông tin',
                            onPressed: onEdit,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile!.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======= ProgressSection widget =======
class ProgressSection extends StatelessWidget {
  final Map<String, dynamic> grammarProgress;
  final Map<String, dynamic> pronunciationProgress;
  final Map<String, dynamic> vocabularyProgress;
  final Map<String, dynamic> conversationProgress;
  const ProgressSection({Key? key, required this.grammarProgress, required this.pronunciationProgress, required this.vocabularyProgress, required this.conversationProgress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressItem(
                  'Ngữ pháp',
                  _calculateOverallProgress(grammarProgress),
                  Colors.amber,
                ),
                _buildProgressItem(
                  'IPA',
                  _calculateOverallProgress(pronunciationProgress, section: 'IPA'),
                  Colors.greenAccent,
                ),
                _buildProgressItem(
                  'Từ vựng',
                  _calculateOverallProgress(vocabularyProgress),
                  Colors.purpleAccent,
                ),
                _buildProgressItem(
                  'Hội thoại',
                  _calculateOverallProgress(conversationProgress),
                  Colors.blueAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateOverallProgress(Map<String, dynamic> progress, {String? section}) {
    if (section == 'IPA') {
      final summaryRaw = progress['summary'];
      final summary = (summaryRaw is Map) ? Map<String, dynamic>.from(summaryRaw) : <String, dynamic>{};
      final totalCorrect = summary['totalCorrectQuestions'] as int? ?? 0;
      final totalQuestions = summary['totalQuestions'] as int? ?? 0;
      return totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;
    }

    if (progress.containsKey('overallSummary')) {
        final overallSummary = progress['overallSummary'];
         if (overallSummary is Map<String, dynamic> && overallSummary.containsKey('overallCompletionPercentage')) {
            final value = overallSummary['overallCompletionPercentage'];
            if (value is num) return value.toDouble() / 100; // percentage / 100
            if (value is String) return (double.tryParse(value) ?? 0.0) / 100;
         }
    }

    final summaryRaw = progress['summary'];
    final summary = (summaryRaw is Map) ? Map<String, dynamic>.from(summaryRaw) : <String, dynamic>{};

    if (summary.containsKey('overallProgress')) {
        final value = summary['overallProgress'];
        if (value is num) return value.toDouble(); // progress (0.0 - 1.0)
        if (value is String) return double.tryParse(value) ?? 0.0;
    }

    final totalQuestions = (summary['totalQuestions'] as num?)?.toInt() ?? 0;
    final totalCorrect = (summary['totalCorrectQuestions'] as num?)?.toInt() ?? 0;
    if (totalQuestions > 0) {
        return totalCorrect / totalQuestions;
    }

    return 0.0;
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
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
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
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProfileModel? _profile;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic> _grammarProgress = {};
  Map<String, dynamic> _pronunciationProgress = {};
  Map<String, dynamic> _vocabularyProgress = {};
  Map<String, dynamic> _conversationProgress = {};
  final ProfileService _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      _profile = await _profileService.getProfile();
      _grammarProgress = await _profileService.getGrammarProgress();
      _pronunciationProgress = await _profileService.getPronunciationProgress();
      _vocabularyProgress = await _profileService.getVocabularyProgress();
      _conversationProgress = await _profileService.getConversationProgress();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _signOut() async {
    setState(() { _isLoading = true; });
    try {
      await _profileService.signOut();
      _profile = null;
      _error = null;
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showLogoutDialog(BuildContext context) {
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
                        backgroundColor: Colors.white.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF8A4EFC),
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

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profile?.name ?? '');
    final emailController = TextEditingController(text: _profile?.email ?? '');
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'EditProfile',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2B71),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chỉnh sửa thông tin cá nhân', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Tên',
                      labelStyle: const TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.amber),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.amber),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.amber),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: const Color(0xFF3A2B71),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          final newEmail = emailController.text.trim();
                          if (newName.isNotEmpty && newEmail.isNotEmpty && _profile != null) {
                            final updated = _profile!.copyWith(name: newName, email: newEmail);
                            await _profileService.updateProfile(updated);
                            setState(() { _profile = updated; });
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfileData() async {
    setState(() { _isLoading = true; });
    try {
      await _profileService.getGrammarProgress(
        onFreshData: (data) {
          setState(() { _grammarProgress = data; });
        },
        forceRefresh: true,
      );
      _pronunciationProgress = await _profileService.getPronunciationProgress(forceRefresh: true);
      _vocabularyProgress = await _profileService.getVocabularyProgress(forceRefresh: true);
      _conversationProgress = await _profileService.getConversationProgress(forceRefresh: true);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() { _isLoading = false; });
    }
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
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Lỗi: $_error', style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshProfileData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        ProfileHeader(profile: _profile, onEdit: _showEditProfileDialog),
                        const SizedBox(height: 20),
                        ProgressSection(
                          grammarProgress: _grammarProgress,
                          pronunciationProgress: _pronunciationProgress,
                          vocabularyProgress: _vocabularyProgress,
                          conversationProgress: _conversationProgress,
                        ),
                        const SizedBox(height: 10),
                        _buildTabBar(),
                        SizedBox(
                          height: MediaQuery.of(context).size.height - 300,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildGrammarProgressTab(),
                              _buildPronunciationProgressTab(),
                              _buildVocabularyProgressTab(),
                              _buildConversationProgressTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 4;
          return Stack(
            children: [
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
                  Tab(text: 'Hội thoại'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrammarProgressTab() {
    final progress = _grammarProgress;
    dynamic summaryRaw = progress['topics'];
    // Ensure summaryList is a List of Maps
    List<Map<String, dynamic>> summaryList = [];
    if (summaryRaw is List) {
      summaryList = summaryRaw.cast<Map<String, dynamic>>();
    } else if (summaryRaw is Map) {
      summaryList = [summaryRaw.cast<String, dynamic>()];
    }

    if (summaryList.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu tiến trình', style: TextStyle(color: Colors.white)),
      );
    }

    // --- Sắp xếp danh sách theo progress giảm dần --- 
    summaryList.sort((a, b) {
      // Tính progressValue cho từng mục
      final totalQuestionsA = (a['totalQuestions'] as num?)?.toInt() ?? 0;
      final totalCorrectA = (a['correctQuestions'] as num?)?.toInt() ?? 0;
      final progressA = totalQuestionsA > 0 ? (totalCorrectA / totalQuestionsA) : 0.0;

      final totalQuestionsB = (b['totalQuestions'] as num?)?.toInt() ?? 0;
      final totalCorrectB = (b['correctQuestions'] as num?)?.toInt() ?? 0;
      final progressB = totalQuestionsB > 0 ? (totalCorrectB / totalQuestionsB) : 0.0;

      // Sắp xếp giảm dần (progress cao hơn đứng trước)
      return progressB.compareTo(progressA);
    });
    // ------------------------------------------------

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaryList.length,
      itemBuilder: (context, index) {
        final topic = summaryList[index]; // Lấy mục đã sắp xếp
        final topicTitle = topic['topicTitle'] ?? 'Chủ đề';
        // Đọc các giá trị số dưới dạng num trước khi chuyển sang int
        final totalQuestions = (topic['totalQuestions'] as num?)?.toInt() ?? 0;
        final totalCorrect = (topic['correctQuestions'] as num?)?.toInt() ?? 0;
        final completedQuestions = (topic['completedQuestions'] as num?)?.toInt() ?? 0;

        // Tính toán progress
        final progressValue = totalQuestions > 0 ? (totalCorrect / totalQuestions) : 0.0;
        final percent = (progressValue * 100).toInt();
        String description = '$totalCorrect/$completedQuestions/$totalQuestions (đúng/đã làm/tổng)';
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
                            topicTitle,
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
                        color: _getProgressColor(progressValue),
                      ),
                      child: Center(
                        child: Text(
                          '$percent%',
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
                    value: progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progressValue),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPronunciationProgressTab() {
    final progress = _pronunciationProgress;
    if (progress.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu tiến trình', style: TextStyle(color: Colors.white)),
      );
    }
    List<dynamic> topics = progress['topics'] as List<dynamic>? ?? [];
    Map<String, dynamic> topicsQuestions = (progress['summary'] as Map<String, dynamic>? ?? {})['topicsQuestions'] as Map<String, dynamic>? ?? {};
    Map<String, dynamic> ipaSummaries = progress['ipaSummaries'] as Map<String, dynamic>? ?? {};

    // Tạo danh sách kết hợp thông tin IPA topic và tiến độ của người dùng
    List<Map<String, dynamic>> combinedIpaProgress = [];
    for (final ipaId in topics) {
      final summary = ipaSummaries[ipaId] ?? {};
      final totalQuestions = topicsQuestions[ipaId] ?? 0;
      final correct = (summary['correctQuestions'] as num?)?.toInt() ?? 0;
      final completed = (summary['completedQuestions'] as num?)?.toInt() ?? 0;

      // Tính toán progress cho mục này
      final progressValue = totalQuestions > 0 ? (correct / totalQuestions) : 0.0;

      combinedIpaProgress.add({
        'ipaId': ipaId,
        'correctQuestions': correct,
        'completedQuestions': completed,
        'totalQuestions': totalQuestions,
        'progressValue': progressValue, // Lưu progress để sắp xếp
      });
    }

    // --- Sắp xếp danh sách theo progress giảm dần --- 
    combinedIpaProgress.sort((a, b) {
      final progressA = a['progressValue'] as double;
      final progressB = b['progressValue'] as double;
      // Sắp xếp giảm dần (progress cao hơn đứng trước)
      return progressB.compareTo(progressA);
    });
    // ------------------------------------------------

    // Dữ liệu mặc định tạm thời (có thể xóa sau khi xác nhận dữ liệu từ Firestore luôn có)
    // if (topics.isEmpty) {
    //   topics = ['ar', 'au'];
    //   topicsQuestions = {'ar': 20, 'au': 20};
    //   ipaSummaries = {
    //     'ar': {'correctQuestions': 1, 'completedQuestions': 8, 'totalQuestions': 20},
    //     'au': {'correctQuestions': 5, 'completedQuestions': 10, 'totalQuestions': 20},
    //   };
    // }

    // Sử dụng danh sách đã sắp xếp để xây dựng ListView
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: combinedIpaProgress.length, // Sử dụng số lượng trong danh sách kết hợp
      itemBuilder: (context, index) {
        final item = combinedIpaProgress[index]; // Lấy mục đã kết hợp

        final ipaId = item['ipaId'].toString();
        final correct = item['correctQuestions'] as int;
        final completed = item['completedQuestions'] as int;
        final total = item['totalQuestions'] as int;
        final progressValue = item['progressValue'] as double;

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
                            ipaId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$correct/$completed/$total (đúng/đã làm/tổng)',
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
                        color: _getProgressColor(progressValue),
                      ),
                      child: Center(
                        child: Text(
                          '${(progressValue * 100).toInt()}%',
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
                    value: progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progressValue),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVocabularyProgressTab() {
    // Data structure is now a list of combined topic and progress info
    final rawVocabProgress = _vocabularyProgress['topicSummaries'];
    // Check if the data is already a List, otherwise fallback to an empty List
    List<Map<String, dynamic>> topicProgressList = (rawVocabProgress is List) ? rawVocabProgress.cast<Map<String, dynamic>>() : [];

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }

    if (topicProgressList.isEmpty) {
      return const Center(child: Text('Chưa có tiến độ từ vựng nào.', style: TextStyle(color: Colors.white70)));
    }

    // --- Sắp xếp danh sách theo progress giảm dần --- 
    topicProgressList.sort((a, b) {
      // Tính progressValue cho từng mục
      final completedA = (a['completedQuestions'] as num?)?.toInt() ?? 0;
      final totalA = (a['totalQuestions'] as num?)?.toInt() ?? 0;
      final progressA = totalA > 0 ? completedA / totalA : 0.0;

      final completedB = (b['completedQuestions'] as num?)?.toInt() ?? 0;
      final totalB = (b['totalQuestions'] as num?)?.toInt() ?? 0;
      final progressB = totalB > 0 ? completedB / totalB : 0.0;

      // Sắp xếp giảm dần (progress cao hơn đứng trước)
      return progressB.compareTo(progressA);
    });
    // ------------------------------------------------

    return ListView.builder(
      padding: const EdgeInsets.all(16), // Padding cho ListView
      itemCount: topicProgressList.length, // Sử dụng số lượng topic trong danh sách
      itemBuilder: (context, index) {
        // Lấy dữ liệu kết hợp, kiểu dynamic sẽ được xử lý bởi null-aware operators và default values
        final topicData = topicProgressList[index]; 

        // Lấy thông tin từ dữ liệu kết hợp, xử lý an toàn hơn cho các giá trị số nguyên
        // Sử dụng 'title' từ topic gốc, fallback về 'topicId' (là id gốc) nếu không có title
        final topicTitle = topicData['title'] ?? topicData['id'] ?? 'Chủ đề';
        // Đọc các giá trị số dưới dạng num trước khi chuyển sang int
        final completedQuestions = (topicData['completedQuestions'] as num?)?.toInt() ?? 0;
        final totalQuestions = (topicData['totalQuestions'] as num?)?.toInt() ?? 0;
        final correctQuestions = (topicData['correctQuestions'] as num?)?.toInt() ?? 0; // Lấy correctQuestions

        // --- Thêm log để kiểm tra giá trị --- 


        // Tính toán progress dựa trên completedQuestions / totalQuestions
        final progressValue = totalQuestions > 0 ? completedQuestions / totalQuestions : 0.0; 
        
        // Xây dựng giao diện mục danh sách giống tab IPA/Grammar
        return Card(
          margin: const EdgeInsets.only(bottom: 12), // Margin giữa các Card
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12), // Padding bên trong Card
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
                            topicTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$correctQuestions/$completedQuestions/$totalQuestions (đúng/đã làm/tổng)',
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
                        color: _getProgressColor(progressValue), // Sử dụng hàm có sẵn để lấy màu dựa trên progress
                      ),
                      child: Center(
                        child: Text(
                          '${(progressValue * 100).toInt()}%',
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
                    value: progressValue,
                    backgroundColor: Colors.grey[200], // Màu nền progress bar
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progressValue), // Màu progress bar
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationProgressTab() {
    // Lấy danh sách topicSummaries từ dữ liệu ConversationProgress
    final progressData = _conversationProgress; // Lấy toàn bộ map trả về từ ProfileService

    // Lấy và ép kiểu danh sách topicSummaries một cách an toàn
    List<Map<String, dynamic>> topicSummaries = [];
    final rawTopicSummaries = progressData['topicSummaries'];
    if (rawTopicSummaries is List) {
      // Duyệt qua danh sách thô và ép kiểu từng phần tử nếu có thể
      for (final item in rawTopicSummaries) {
        if (item is Map) {
          try {
            topicSummaries.add(Map<String, dynamic>.from(item.cast<String, dynamic>()));
          } catch (e) {
            // Bỏ qua nếu không thể ép kiểu một mục cụ thể
             print('[PROFILE] Could not cast conversation topic item: $item, error: $e');
          }
        }
      }
    }

    if (topicSummaries.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu tiến trình Hội thoại', style: TextStyle(color: Colors.white)),
      );
    }

     // Sắp xếp danh sách theo completionPercentage giảm dần
     topicSummaries.sort((a, b) {
       final percentageA = (a['completionPercentage'] as num?)?.toDouble() ?? 0.0;
       final percentageB = (b['completionPercentage'] as num?)?.toDouble() ?? 0.0;
       return percentageB.compareTo(percentageA);
     });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topicSummaries.length,
      itemBuilder: (context, index) {
        final topic = topicSummaries[index];

        // --- Debugging Log ---
        print('[PROFILE] Conversation Topic Data (from cache): ${topic}'); // Log entire topic map
        // ---------------------

        final topicName = topic['topicName'] ?? topic['topicId'] ?? 'Chủ đề Hội thoại';
        final averageScore = (topic['averageScore'] as num?)?.toDouble() ?? 0.0;
        final completedLessons = (topic['completedLessons'] as num?)?.toInt() ?? 0;
        final totalSubQuestionsWithResults = (topic['totalSubQuestionsWithResults'] as num?)?.toInt() ?? 0;
        final completionPercentage = (topic['completionPercentage'] as num?)?.toDouble() ?? 0.0;

        // Định dạng hiển thị thông tin theo cấu trúc Card chung
        // Sử dụng description để hiển thị completed/total subs and average score
        final descriptionText = 'Đã hoàn thành: $completedLessons bài / $totalSubQuestionsWithResults câu | Điểm TB: ${averageScore.toStringAsFixed(1)}%';
        final progressValue = completionPercentage / 100; // Chuyển percentage về dạng 0.0 - 1.0
        final percentDisplay = completionPercentage.toStringAsFixed(0); // Hiển thị % làm tròn

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Sử dụng màu nền mặc định hoặc tương tự các tab khác nếu cần
          // color: Colors.white, // Hoặc một màu nền nhẹ
          child: Padding(
            padding: const EdgeInsets.all(12), // Padding bên trong Card giống các tab khác
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
                            topicName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16, // Kích thước font giống các tab khác
                              // color: Colors.black87, // Màu text mặc định hoặc tương phản
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descriptionText,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]), // Style giống description các tab khác
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40, // Kích thước vòng tròn giống các tab khác
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getProgressColor(progressValue), // Sử dụng màu dựa trên progressValue (completionPercentage)
                      ),
                      child: Center(
                        child: Text(
                          '$percentDisplay%',
                          style: const TextStyle(
                            color: Colors.white, // Màu text trong vòng tròn
                            fontWeight: FontWeight.bold,
                            fontSize: 12, // Kích thước font trong vòng tròn
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // Khoảng cách giống các tab khác
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(progressValue), // Màu progress bar dựa trên progressValue
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) {
      return Colors.green;
    } else if (progress >= 0.6) {
      return Colors.amber;
    } else {
      return Colors.redAccent;
    }
  }
}