import 'package:flutter/material.dart';

import '../../../services/ipa_service.dart';
import '../../../models/ipa_pronunciation_model.dart';
import 'ipa_quiz.dart';

class IpaDetailScreen extends StatefulWidget {
  final String ipaId;
  final List<String> allIpaIds;

  const IpaDetailScreen({
    Key? key,
    required this.ipaId,
    required this.allIpaIds,
  }) : super(key: key);

  @override
  State<IpaDetailScreen> createState() => _IpaDetailScreenState();
}

class _IpaDetailScreenState extends State<IpaDetailScreen> {
  late PageController _pageController;
  int currentIpaIndex = 0;
  bool isLoading = true;
  List<IpaPronunciation?> ipaDataList = [];
  final IpaService _ipaService = IpaService();

  @override
  void initState() {
    super.initState();
    _setupPageController();
    _preloadAllIpaData();
  }

  void _setupPageController() {
    currentIpaIndex = widget.allIpaIds.indexOf(widget.ipaId);
    if (currentIpaIndex < 0) currentIpaIndex = 0;
    _pageController = PageController(initialPage: currentIpaIndex);
    ipaDataList = List.generate(widget.allIpaIds.length, (_) => null);
  }

  Future<void> _preloadAllIpaData() async {
    await _fetchIpaData(currentIpaIndex);
    setState(() {
      isLoading = false;
    });
    final preloadIndexes = _getPreloadIndexes(currentIpaIndex);
    for (final index in preloadIndexes) {
      await _fetchIpaData(index);
    }
  }

  List<int> _getPreloadIndexes(int currentIndex) {
    final indexes = <int>[];
    if (currentIndex > 0) indexes.add(currentIndex - 1);
    if (currentIndex < widget.allIpaIds.length - 1) indexes.add(currentIndex + 1);
    return indexes;
  }

  Future<void> _fetchIpaData(int index) async {
    if (ipaDataList[index] != null) return;
    final ipaData = await _ipaService.fetchIpaData(widget.allIpaIds[index]);
    if (ipaData != null && mounted) {
      setState(() {
        ipaDataList[index] = ipaData;
      });
      await _ipaService.preloadAudio(index, ipaData.ipaAudio);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ipaService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chi tiết IPA',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6937A1), Color(0xFF4B6BD6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F2F70), Color(0xFF2E3F88), Color(0xFF482878)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Column(
            children: [
              _buildNavigationButtons(),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.allIpaIds.length,
                  onPageChanged: (index) {
                    setState(() {
                      if (currentIpaIndex != index) {
                        _ipaService.dispose();
                      }
                      currentIpaIndex = index;
                      final preloadIndexes = _getPreloadIndexes(index);
                      for (final preloadIndex in preloadIndexes) {
                        _fetchIpaData(preloadIndex);
                      }
                    });
                    if (ipaDataList[index] != null) {
                      _ipaService.preloadAudio(index, ipaDataList[index]!.ipaAudio, play: true);
                    }
                  },
                  itemBuilder: (context, index) {
                    if (ipaDataList[index] == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _buildIpaCard(index),
                      ),
                    );
                  },
                ),
              ),
              _buildPracticeButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.arrow_back_ios,
            onPressed: currentIpaIndex > 0
                ? () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
                : null,
            label: 'Trước',
            isStart: true,
          ),
          _buildNavButton(
            icon: Icons.arrow_forward_ios,
            onPressed: currentIpaIndex < widget.allIpaIds.length - 1
                ? () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
                : null,
            label: 'Sau',
            isStart: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String label,
    required bool isStart,
  }) {
    final isDisabled = onPressed == null;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisabled ? Colors.grey.withOpacity(0.3) : const Color(0xFF4B6BD6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.only(
          left: isStart ? 8 : 12,
          right: isStart ? 12 : 8,
          top: 8,
          bottom: 8,
        ),
      ),
    );
  }

  Widget _buildIpaCard(int index) {
    final ipaData = ipaDataList[index]!;
    final ipaId = widget.allIpaIds[index];

    String translatedGroupCapitalized = ipaData.translatedGroup.isNotEmpty
        ? '${ipaData.translatedGroup[0].toUpperCase()}${ipaData.translatedGroup.substring(1)}'
        : ipaData.translatedGroup;
    String translatedTypeCapitalized = ipaData.translatedType.isNotEmpty
        ? '${ipaData.translatedType[0].toUpperCase()}${ipaData.translatedType.substring(1)}'
        : ipaData.translatedType;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF2A3980),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ipaId,
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF56C5FF),
                              ),
                            ),
                          ),
                          _buildAudioButton(
                            onPressed: () => _ipaService.preloadAudio(index, ipaData.ipaAudio, play: true),
                            color: const Color(0xFF4B76D6),
                            iconData: Icons.volume_up,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ipaData.exampleWord,
                                  style: const TextStyle(fontSize: 24, color: Colors.white),
                                ),
                                Text(
                                  ipaData.exampleWordIpa,
                                  style: const TextStyle(fontSize: 18, color: Color(0xFFBBC1F3)),
                                ),
                              ],
                            ),
                          ),
                          _buildAudioButton(
                            onPressed: () => _ipaService.playWord(ipaData.exampleWord),
                            color: const Color(0xFF7957A1),
                            iconData: Icons.record_voice_over,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1, color: Color(0xFF4B6BD6)),
            _buildCombinedInfoRow('Nhóm', '$translatedGroupCapitalized (${ipaData.group})'),
            _buildCombinedInfoRow('Phân loại', '$translatedTypeCapitalized (${ipaData.type})'),
            const SizedBox(height: 16),
            Text(
              'Mô tả:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              ipaData.description,
              style: const TextStyle(fontSize: 16, color: Color(0xFFDFE1F9)),
            ),
            const SizedBox(height: 20),
            _buildImageSection(ipaData),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioButton({
    required VoidCallback onPressed,
    required Color color,
    required IconData iconData,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, Color(0xFF56C5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: IconButton(
        icon: Icon(iconData, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCombinedInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Color(0xFFDFE1F9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(IpaPronunciation ipaData) {
    String? imagePath = ipaData.ipaDescriptionImage;

    return Center(
      child: Container(
        height: 180,
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2F70),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imagePath != null && imagePath.isNotEmpty
              ? Image.asset(
            'assets/images/ipaSound/$imagePath',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1F2F70),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.image_not_supported, size: 50, color: Color(0xFF4B6BD6)),
            SizedBox(height: 8),
            Text(
              'No image available',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IpaQuizScreen(ipaId: widget.ipaId),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6937A1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 24),
            SizedBox(width: 12),
            Text(
              'LUYỆN TẬP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}