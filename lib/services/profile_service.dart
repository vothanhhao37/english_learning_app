import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/profile_model.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'conversation_pronunciation_service.dart';

class ProfileService {
  final FirebaseService _firebaseService;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  ProfileService({
    FirebaseService? firebaseService,
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  Future<ProfileModel> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final userDoc = await _firebaseService.profile_getUserDocument(user.uid);
    if (!userDoc.exists) {
      throw Exception('User profile not found');
    }

    return ProfileModel.fromMap(userDoc.data()!, user.uid);
  }

  Future<void> updateProfile(ProfileModel profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    await _firebaseService.profile_updateUserDocument(user.uid, profile.toMap());
  }

  /// Lấy tiến trình grammar, ưu tiên cache local, đồng thời load mới từ Firestore và update cache
  Future<Map<String, dynamic>> getGrammarProgress({void Function(Map<String, dynamic>)? onFreshData, bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString('grammar_progress_cache');
    if (!forceRefresh && cacheString != null) {
      try {
        final decoded = jsonDecode(cacheString);
        if (decoded is Map && decoded['timestamp'] != null && decoded['data'] != null) {
          final timestamp = DateTime.tryParse(decoded['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (DateTime.now().difference(timestamp) < Duration(hours: 2)) {
            // Cache còn hạn, trả về data
            final elapsed = DateTime.now().difference(startTime).inMilliseconds;
            print('[PROFILE] getGrammarProgress (from cache) executed in $elapsed ms');
            return Map<String, dynamic>.from(decoded['data']);
          } else {
            await prefs.remove('grammar_progress_cache');
          }
        }
      } catch (e) {
        // ignore
      }
    }

    // if (forceRefresh) {
    //   await Future.delayed(const Duration(milliseconds: 1200));
    // }

    // Nếu forceRefresh hoặc không có cache, lấy mới từ Firestore
    final overallSummaryDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('learningProgress')
        .doc('grammar')
        .collection('summary')
        .doc('summary')
        .get(forceRefresh ? const GetOptions(source: Source.server) : null);
    final overallSummary = overallSummaryDoc.exists ? overallSummaryDoc.data() ?? {} : {};

    final topicsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('learningProgress')
        .doc('grammar')
        .collection('topics');
    final topicsSnap = await topicsCollection.get(forceRefresh ? const GetOptions(source: Source.server) : null);
    final topicSummaryList = topicsSnap.docs.map((doc) => doc.data()).toList();

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    final result = {
      'summary': overallSummary,
      'topics': topicSummaryList,
    };
    print('[PROFILE] getGrammarProgress executed in ${elapsed} ms');

    // 3. Lưu lại cache mới với timestamp
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': convertTimestamps(result),
    };
    print('[PROFILE] Cache data (before jsonEncode): ${cacheData}');
    await prefs.setString('grammar_progress_cache', jsonEncode(cacheData));
    // 4. Nếu có callback, gọi để update UI
    if (onFreshData != null) {
      onFreshData(result);
    }
    return result;
  }

  Future<Map<String, dynamic>> getPronunciationProgress({bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString('ipa_progress_cache');
    if (!forceRefresh && cacheString != null) {
      try {
        final decoded = jsonDecode(cacheString);
        if (decoded is Map && decoded['timestamp'] != null && decoded['data'] != null) {
          final timestamp = DateTime.tryParse(decoded['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (DateTime.now().difference(timestamp) < Duration(hours: 2)) {
            // Cache còn hạn, trả về data
            final elapsed = DateTime.now().difference(startTime).inMilliseconds;
            print('[PROFILE] getPronunciationProgress (from cache) executed in $elapsed ms');
            return Map<String, dynamic>.from(decoded['data']);
          } else {
            await prefs.remove('ipa_progress_cache');
          }
        }
      } catch (e) {
        // ignore
      }
    }

    // Nếu forceRefresh hoặc không có cache, lấy mới từ Firestore
    final userIpaDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('learningProgress')
        .doc('ipa')
        .get();
    final summary = userIpaDoc.data()?['summary'] as Map<String, dynamic>? ?? {};
    final topics = userIpaDoc.data()?['topics'] as List<dynamic>? ?? [];
    final topicsQuestions = userIpaDoc.data()?['topicsQuestions'] as Map<String, dynamic>? ?? {};

    // Lấy tất cả các IPA từ root
    final allIpaDocs = await FirebaseFirestore.instance.collection('ipa_pronunciation').get();
    final allIpaIds = allIpaDocs.docs.map((doc) => doc.id).toList();

    // Lấy summary từng IPA (subcollection) song song
    Map<String, dynamic> ipaSummaries = {};
    final futures = allIpaIds.map((ipaId) async {
      final summaryDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('learningProgress')
          .doc('ipa')
          .collection(ipaId)
          .doc('summary')
          .get();
      final totalQuestions = topicsQuestions[ipaId] ?? 0;
      if (summaryDoc.exists) {
        ipaSummaries[ipaId] = {
          ...summaryDoc.data()!,
          'totalQuestions': totalQuestions,
        };
      } else {
        ipaSummaries[ipaId] = {
          'correctQuestions': 0,
          'completedQuestions': 0,
          'totalQuestions': totalQuestions,
        };
      }
    }).toList();
    await Future.wait(futures);

    // Đảm bảo topicsQuestions có đủ key cho tất cả các IPA
    final mergedTopicsQuestions = Map<String, dynamic>.from(topicsQuestions);
    for (final ipaId in allIpaIds) {
      if (!mergedTopicsQuestions.containsKey(ipaId)) {
        mergedTopicsQuestions[ipaId] = 0;
      }
    }

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    print('[PROFILE] getPronunciationProgress executed in [32m${elapsed} ms[0m');

    final result = {
      'summary': summary,
      'topics': allIpaIds, // Trả về tất cả các IPA
      'topicsQuestions': mergedTopicsQuestions,
      'ipaSummaries': ipaSummaries,
    };

    // Lưu lại cache mới với timestamp
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': convertTimestamps(result),
    };
    print('[PROFILE] Cache data (before jsonEncode): ${cacheData}');
    await prefs.setString('ipa_progress_cache', jsonEncode(cacheData));

    return result;
  }

  Future<Map<String, dynamic>> getVocabularyProgress({bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final prefs = await SharedPreferences.getInstance();
    
    // --- TẠM THỜI: Xóa cache để buộc đọc lại từ Firestore --- 
    // await prefs.remove('vocabulary_progress_cache');
    // --------------------------------------------------------

    final cacheString = prefs.getString('vocabulary_progress_cache');
    if (!forceRefresh && cacheString != null) {
      try {
        final decoded = jsonDecode(cacheString);
        if (decoded is Map && decoded['timestamp'] != null && decoded['data'] != null) {
          final timestamp = DateTime.tryParse(decoded['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (DateTime.now().difference(timestamp) < Duration(hours: 2)) {
            // Cache còn hạn, trả về data
            final elapsed = DateTime.now().difference(startTime).inMilliseconds;
            print('[PROFILE] getVocabularyProgress (from cache) executed in $elapsed ms');
          
            return Map<String, dynamic>.from(decoded['data']);
          } else {
            await prefs.remove('vocabulary_progress_cache');
          }
        }
      } catch (e) {
        // ignore
      }
    }

    // 1. Lấy summary tổng thể từ vựng
    final overallSummaryDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('learningProgress')
        .doc('vocabulary')
        .get(forceRefresh ? const GetOptions(source: Source.server) : null);
    // Lấy subfield 'summary', fallback về map rỗng nếu document không tồn tại hoặc trường summary là null
    final overallSummary = overallSummaryDoc.data()?['summary'] as Map<String, dynamic>? ?? {};

    // 2. Lấy danh sách TẤT CẢ các chủ đề từ vựng gốc cùng với thông tin của chúng
    print('[PROFILE] Fetching vocab topics from vocabs_topics...');
    final vocabTopicsSnap = await FirebaseFirestore.instance.collection('vocabs_topics').get(forceRefresh ? const GetOptions(source: Source.server) : null);
    print('[PROFILE] Fetched ${vocabTopicsSnap.docs.length} docs from vocabs_topics.');
    final allVocabTopics = vocabTopicsSnap.docs.map((doc) => {
      'id': doc.id,
      'title': doc.data()['title'] ?? doc.id, // Lấy title, fallback về id nếu không có
      // Thêm các trường thông tin khác của topic gốc nếu cần
    }).toList();

    // 3. Lặp qua danh sách chủ đề gốc và lấy summary tiến độ của người dùng cho từng chủ đề (nếu có)
    Map<String, Map<String, dynamic>> userVocabSummaries = {};
     print('[PROFILE] Fetching user vocab summaries for each topic...');
     int fetchedSummariesCount = 0;

     final futures = allVocabTopics.map((topic) async {
       final topicId = topic['id'] as String;
       final summaryDoc = await FirebaseFirestore.instance
           .collection('users')
           .doc(user.uid)
           .collection('learningProgress')
           .doc('vocabulary')
           .collection(topicId) // <-- Sử dụng topicId làm tên subcollection
           .doc('summary') // <-- Đọc document 'summary'
           .get(forceRefresh ? const GetOptions(source: Source.server) : null);

       if (summaryDoc.exists) {
         userVocabSummaries[topicId] = summaryDoc.data()!;
         fetchedSummariesCount++;
       } else {
         // Nếu chưa có summary, tạo một object rỗng hoặc default
         userVocabSummaries[topicId] = {
           'completedQuestions': 0,
           'correctQuestions': 0,
           'totalQuestions': 0, 
           'progress': 0.0,
           'accuracy': 0.0,
           'lastUpdated': null,
         };
       }
     }).toList();

     await Future.wait(futures);

     print('[PROFILE] Fetched ${fetchedSummariesCount} user vocab summaries.');

    
    // 4. Kết hợp thông tin chủ đề gốc với tiến độ của người dùng
    List<Map<String, dynamic>> combinedProgressList = [];
    for (final topic in allVocabTopics) {
      final topicId = topic['id'] as String;
      final topicTitle = topic['title'] as String;
      final userSummary = userVocabSummaries[topicId] ?? {
        // Tạo dữ liệu tiến độ mặc định nếu chưa có summary
        'completedQuestions': 0,
        'correctQuestions': 0,
        'totalQuestions': 0, 
        'progress': 0.0,
        'accuracy': 0.0,
        'lastUpdated': null,
      };
      
      // --- Thêm log để kiểm tra giá trị trước khi kết hợp --- 
      // -----------------------------------------------------

      // Thêm thông tin title từ topic gốc vào dữ liệu kết hợp
      combinedProgressList.add({
        ...topic, // Bao gồm id và title từ topic gốc
        ...userSummary, // Bao gồm dữ liệu tiến độ của người dùng
        'topicId': topicId, // Đảm bảo có topicId
        'topicTitle': topicTitle, // Đảm bảo có topicTitle (tiếng Việt)
      });
    }
    print('[PROFILE] Combined progress list size: ${combinedProgressList.length}');

    // Sắp xếp danh sách theo một tiêu chí nào đó (ví dụ: theo title, hoặc theo lastUpdated)
    // Tạm thời không sắp xếp

    final endTime = DateTime.now();
    final elapsed = endTime.difference(startTime).inMilliseconds;
    print('[PROFILE] getVocabularyProgress executed in ${elapsed} ms');

    final result = {
      'summary': overallSummary,
      'topicSummaries': combinedProgressList, // Trả về danh sách kết hợp
    };

    // Lưu lại cache mới với timestamp
    final cacheData = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': convertTimestamps(result),
    };
    print('[PROFILE] Cache data (before jsonEncode): ${cacheData}');
    await prefs.setString('vocabulary_progress_cache', jsonEncode(cacheData));

    // 5. Trả về kết quả
    return result;
  }

  /// Lấy tiến trình Conversation cho ProfileService, có cache local
  Future<Map<String, dynamic>> getConversationProgress({bool forceRefresh = false}) async {
    final startTime = DateTime.now();
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'conversation_progress_cache';
    final cacheString = prefs.getString(cacheKey);

    // 1. Thử đọc cache nếu không buộc làm mới
    if (!forceRefresh && cacheString != null) { // Chỉ đọc cache nếu KHÔNG buộc làm mới
       try {
         final decoded = jsonDecode(cacheString);
         print('[PROFILE] Cache data (after jsonDecode): ${decoded}');
         if (decoded is Map && decoded['timestamp'] != null && decoded['data'] != null) {
           final timestamp = DateTime.tryParse(decoded['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
           // Cache còn hạn (ví dụ: 2 tiếng)
           if (DateTime.now().difference(timestamp) < Duration(hours: 2)) {
             final elapsed = DateTime.now().difference(startTime).inMilliseconds;
             print('[PROFILE] getConversationProgress (from cache) executed in ${elapsed} ms');
             print('[PROFILE] Cache data (after jsonDecode - overallSummary): ${decoded['data']['overallSummary']}'); // Log overallSummary after decoding
             print('[PROFILE] Cache data (after jsonDecode - topicSummaries): ${decoded['data']['topicSummaries']}'); // Log topicSummaries after decoding
             return Map<String, dynamic>.from(decoded['data']);
           } else {
             // Cache hết hạn, xóa cache cũ
             await prefs.remove(cacheKey);
           }
         }
       } catch (e) {
         // Lỗi đọc cache, xóa cache cũ và bỏ qua
         print('[PROFILE] Error reading conversation cache: $e');
         await prefs.remove(cacheKey);
       }
    }

    // 2. Nếu forceRefresh hoặc không có cache hợp lệ, lấy mới từ Firestore
    try {
      // Sử dụng ConversationPronunciationService để lấy dữ liệu thô
      final conversationService = ConversationPronunciationService(); // Tạo instance service
      final rawProgressData = await conversationService.getConversationProgress(user.uid);

      // Áp dụng convertTimestamps ngay cho dữ liệu thô từ ConversationPronunciationService
      final progressData = convertTimestamps(rawProgressData);

      // Lấy dữ liệu tổng quan và topic summaries thô từ kết quả
      final overallSummary = (progressData['summary'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {};
      // userTopicSummaries should be a Map<String, Map<String, dynamic>> (topicId -> summary data)
      final userTopicSummariesDynamic = progressData['topicSummaries'] as Map<dynamic, dynamic>?;
      final userTopicSummaries = userTopicSummariesDynamic?.map((key, value) => MapEntry(key.toString(), (value as Map<dynamic, dynamic>).cast<String, dynamic>())) ?? {};

      // Lấy danh sách tất cả các chủ đề Conversation từ root để lấy tên (title)
      final allTopicsSnap = await FirebaseFirestore.instance
          .collection('conversation') // Collection gốc chứa định nghĩa các chủ đề
          .get(forceRefresh ? const GetOptions(source: Source.server) : null);
      final allTopicsData = Map.fromEntries(allTopicsSnap.docs.map((doc) => MapEntry(doc.id, doc.data())));

      // Kết hợp thông tin chủ đề gốc với tiến độ của người dùng (hoặc mặc định)
      final List<Map<String, dynamic>> combinedTopicSummaries = [];
      // Duyệt qua TẤT CẢ các topic từ cấu trúc gốc
      for (final topicEntry in allTopicsData.entries) {
         final topicId = topicEntry.key;
         final topicInfo = topicEntry.value; // Thông tin từ topic gốc

         // Kiểm tra xem user đã tương tác với topic này chưa
         final userSummary = userTopicSummaries[topicId]; // Có thể là null nếu chưa tương tác

         // Tạo map progress cho topic này
         Map<String, dynamic> topicProgressMap = {
            'topicId': topicId,
            'topicName': topicInfo['title'] ?? topicId, // Sử dụng title từ gốc, fallback là topicId
            // Thêm các trường tổng số bài/câu từ topic gốc nếu cần hiển thị
            // 'totalLessons': ..., // Có thể lấy từ cấu trúc gốc nếu cần
         };

         if (userSummary != null) {
            // Nếu user đã tương tác, thêm dữ liệu progress của user
            topicProgressMap.addAll(userSummary);
         } else {
            // Nếu chưa tương tác, thêm dữ liệu progress mặc định (0%)
            topicProgressMap.addAll({
              'completedLessons': 0,
              'bestScoreSum': 0,
              'averageScore': 0.0,
              'completionPercentage': 0.0,
              'totalSubQuestionsWithResults': 0,
              'lastUpdated': null, // Hoặc một giá trị null thích hợp
            });
         }
         combinedTopicSummaries.add(topicProgressMap);
      }

      // Áp dụng convertTimestamps cho danh sách topicSummaries (không bắt buộc nếu áp dụng cho toàn bộ result)
      final processedTopicSummaries = combinedTopicSummaries.map((topic) => convertTimestamps(topic)).toList(); // Giữ lại để đảm bảo an toàn

      // Sắp xếp danh sách ở đây (đã xử lý timestamps)
      processedTopicSummaries.sort((a, b) => (a['topicName'] as String).compareTo(b['topicName'] as String));

      final result = {
        'overallSummary': overallSummary, // Dữ liệu tổng quan
        'topicSummaries': processedTopicSummaries, // Danh sách topic đã được xử lý Timestamp
      };

      // Chúng ta đã xử lý timestamps ở bước đầu, nên không cần gọi convertTimestamps(result) ở đây nữa
      // final finalResult = convertTimestamps(result);
      print('[PROFILE] Conversation data (before caching): ${jsonEncode(result)}'); // Log data before caching

      // 3. Lưu lại cache mới với timestamp
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': result, // Dữ liệu đã được xử lý timestamps
      };
      print('[PROFILE] Conversation Cache Data (before jsonEncode - topicSummaries): ${result['topicSummaries']}'); // Log topicSummaries before encoding
      await prefs.setString(cacheKey, jsonEncode(cacheData));


      final endTime = DateTime.now();
      final elapsed = endTime.difference(startTime).inMilliseconds;
      print('[PROFILE] getConversationProgress executed in ${elapsed} ms');

      return result;

    } catch (e) {
       print('Error getting conversation progress for profile: $e');
       // Trả về cấu trúc rỗng phù hợp để UI không bị lỗi
       // Xóa cache cũ nếu có lỗi để tránh dùng dữ liệu lỗi
       await prefs.remove(cacheKey);
       return {
         'overallSummary': {},
         'topicSummaries': [],
       };
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
  }

  Map<String, dynamic>? getGrammarData() {
    // TODO: Implement getting grammar data from grammar.json
    return null;
  }

  Future<void> syncIpaSummaryWithTopics() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userId = user.uid;

    // Lấy danh sách topic IPA từ root
    final ipaTopics = await FirebaseFirestore.instance.collection('ipa_pronunciation').get();
    
    // Lấy document IPA hiện tại
    final userIpaRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('ipa');

    // Chuẩn bị dữ liệu cho document ipa
    Map<String, int> topicsQuestions = {};
    List<String> topics = [];
    int totalQuestions = 0;

    // Tạo summary cho các topic chưa có và thu thập thông tin
    for (final topicDoc in ipaTopics.docs) {
      final topicId = topicDoc.id;
      topics.add(topicId);
      
      // Lấy tổng số câu hỏi của topic từ root
      final lessonsSnap = await FirebaseFirestore.instance
          .collection('ipa_pronunciation')
          .doc(topicId)
          .collection('lessons')
          .get();
      final topicQuestions = lessonsSnap.docs.length;
      topicsQuestions[topicId] = topicQuestions;
      totalQuestions += topicQuestions;

      // Kiểm tra xem topic đã có summary chưa
      final summaryDoc = await userIpaRef.collection(topicId).doc('summary').get();
      
      if (!summaryDoc.exists) {
        // Tạo document summary cho topic chưa học
        await userIpaRef.collection(topicId).doc('summary').set({
          'ipaId': topicId,
          'totalQuestions': topicQuestions,
          'completedQuestions': 0,
          'correctQuestions': 0,
          'accuracy': 0.0,
          'completionRate': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }

    // Cập nhật document ipa chính
    await userIpaRef.set({
      'summary': {
        'totalQuestions': totalQuestions,
        'completedQuestions': 0,
        'correctQuestions': 0,
        'accuracy': 0.0,
        'completionRate': 0.0
      },
      'topics': topics,
      'topicsQuestions': topicsQuestions
    }, SetOptions(merge: true));
  }

  /// Gộp logic load toàn bộ dữ liệu profile và progress (dùng cho màn hình Profile)
  Future<Map<String, dynamic>> loadAllProfileData() async {
    final profile = await getProfile();
    final grammarProgress = await getGrammarProgress();
    final pronunciationProgress = await getPronunciationProgress();
    final vocabularyProgress = await getVocabularyProgress();
    final conversationProgress = await getConversationProgress();
    return {
      'profile': profile,
      'grammarProgress': grammarProgress,
      'pronunciationProgress': pronunciationProgress,
      'vocabularyProgress': vocabularyProgress,
      'conversationProgress': conversationProgress,
    };
  }

  /// Gộp logic sign out (dùng cho màn hình Profile)
  Future<void> signOutAndClearProfile({void Function()? onSignedOut}) async {
    await signOut();
    if (onSignedOut != null) onSignedOut();
  }

  // Chuyển Timestamp Firestore thành String để lưu cache
  dynamic convertTimestamps(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, convertTimestamps(v)));
    } else if (value is List) {
      return value.map(convertTimestamps).toList();
    } else if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else {
      return value;
    }
  }

  /// Xóa cache cho một mục cụ thể để buộc làm mới từ Firestore
  Future<void> invalidateCache(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    print('[PROFILE] Invalidated cache for key: $cacheKey');
  }

  /// Xóa cache Conversation
  Future<void> invalidateConversationCache() async {
    await invalidateCache('conversation_progress_cache');
  }

  /// Xóa cache Grammar
  Future<void> invalidateGrammarCache() async {
    await invalidateCache('grammar_progress_cache');
  }

  /// Xóa cache IPA
  Future<void> invalidateIPACache() async {
    await invalidateCache('ipa_progress_cache');
  }

  /// Xóa cache Vocabulary
  Future<void> invalidateVocabularyCache() async {
    await invalidateCache('vocabulary_progress_cache');
  }
} 