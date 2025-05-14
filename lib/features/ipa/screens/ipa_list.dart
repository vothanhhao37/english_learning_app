import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/ipa_section.dart';
import '../widgets/ipa_subsection.dart';
import '../widgets/ipa_item.dart';


class IpaListScreen extends StatelessWidget {
  const IpaListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const IPAHomePage();
  }
}

class IPAHomePage extends StatefulWidget {
  const IPAHomePage({super.key});

  @override
  State<IPAHomePage> createState() => _IPAHomePageState();
}

class _IPAHomePageState extends State<IPAHomePage> with TickerProviderStateMixin {
  final Map<String, AnimationController> _animationControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAnimations();
    });
  }

  void _runAnimations() {
    for (var controller in _animationControllers.values) {
      controller.reset();
    }
    int index = 0;
    for (var key in _animationControllers.keys) {
      Future.delayed(Duration(milliseconds: index * 50), () {
        if (mounted && _animationControllers.containsKey(key)) {
          _animationControllers[key]!.forward(from: 0.0);
        }
      });
      index++;
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _capitalizeWords(String input) {
    return input
        .split(' ')
        .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF6B48FF)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ipa_pronunciation').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Lỗi khi tải dữ liệu.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'Chưa có dữ liệu IPA.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              );
            }

            final List<String> allIpaIds = snapshot.data!.docs.map((doc) => doc.id).toList();

            final Map<String, Map<String, List<QueryDocumentSnapshot>>> groupedData = {};
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final group = data['group'] as String? ?? 'unknown';
              final type = data['type'] as String? ?? 'unknown';

              groupedData[group] ??= {};
              groupedData[group]![type] ??= [];
              groupedData[group]![type]!.add(doc);
            }

            int globalIndex = 0;
            final sections = groupedData.entries.map((groupEntry) {
              final group = groupEntry.key;
              final firstDoc = groupEntry.value.values.isNotEmpty && groupEntry.value.values.first.isNotEmpty
                  ? groupEntry.value.values.first.first
                  : null;
              final translatedGroup = firstDoc != null
                  ? (firstDoc.data() as Map<String, dynamic>)['translated_group'] as String? ?? group
                  : group;

              final subsections = groupEntry.value.entries.map((typeEntry) {
                final type = typeEntry.key;
                final items = typeEntry.value.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final symbol = data['word'] as String? ?? doc.id;
                  final example = '${data['example_word']}  /${data['example_word_ipa']}/' as String? ?? symbol;

                  final itemKey = 'item_$globalIndex';
                  globalIndex++;

                  if (!_animationControllers.containsKey(itemKey)) {
                    _animationControllers[itemKey] = AnimationController(
                      vsync: this,
                      duration: const Duration(milliseconds: 500),
                    );
                  }

                  return IPAItem(
                    ipaId: symbol,
                    example: example,
                    ipaType: data['type'],
                    ipaAudio: data['ipa_audio'] ?? '',
                    animationController: _animationControllers[itemKey]!,
                    allIpaIds: allIpaIds,
                  );
                }).toList();
                return IPASubsection(title: type[0].toUpperCase() + type.substring(1), items: items);
              }).toList();
              final title = '${_capitalizeWords(translatedGroup)} (${_capitalizeWords(group)})';
              return IPASection(title: title, subsections: subsections);
            }).toList();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _runAnimations();
            });

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Danh sách âm IPA',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 8.0,
                            color: Colors.black45,
                            offset: Offset(0, 4),
                          ),
                        ],
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20.0),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 32,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sections,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}