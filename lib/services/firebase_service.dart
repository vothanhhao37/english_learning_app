import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/grammar_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Grammar-related methods
  Future<List<Exercise>> grammar_fetchExercises(String grammarId, String type) async {
    try {
      final snapshot = await _firestore
          .collection('grammar')
          .doc(grammarId)
          .collection('exercises')
          .where('type', isEqualTo: type)
          .get();

      List<Exercise> exercises = snapshot.docs.map((doc) {
        final data = doc.data();
        return Exercise(
          id: doc.id,
          type: data['type'] ?? '',
          question: data['question'] ?? '',
          answer: data['answer'] ?? '',
          explanation: data['explanation'] ?? '',
          options: data['options'] != null
              ? List<String>.from(data['options'] is List
              ? data['options']
              : (data['options'] as Map).values)
              : null,
        );
      }).toList();

      if (exercises.isEmpty) {
        final fallbackSnapshot = await _firestore
            .collection('grammar')
            .doc(grammarId)
            .collection('exercises')
            .limit(5)
            .get();
        exercises = fallbackSnapshot.docs.map((doc) {
          final data = doc.data();
          return Exercise(
            id: doc.id,
            type: data['type'] ?? '',
            question: data['question'] ?? '',
            answer: data['answer'] ?? '',
            explanation: data['explanation'] ?? '',
            options: data['options'] != null
                ? List<String>.from(data['options'] is List
                ? data['options']
                : (data['options'] as Map).values)
                : null,
          );
        }).toList();
      }

      return exercises;
    } catch (e) {
      throw Exception('Failed to load exercises: $e');
    }
  }

  Future<GrammarModel> grammar_fetchGrammarLesson(String grammarId) async {
    try {
      final docRef = _firestore.collection('grammar').doc(grammarId);
      final doc = await docRef.get();
      final data = doc.data()!;
      final exampleSnapshot = await docRef.collection('examples').get();
      final exampleDocs = exampleSnapshot.docs;

      final examples = exampleDocs.map((e) {
        final d = e.data();
        return ExampleModel(
          sentence: d['sentence'],
          translation: d['translation'],
          explanation: d['explanation'],
        );
      }).toList();

      return GrammarModel(
        title: data['title'],
        description: data['description'],
        structures: List<String>.from(data['structures']),
        theory: TheoryModel(
          explanation: List<String>.from(data['theory']['explanation']),
          tips: data['theory']['tips'],
        ),
        examples: examples,
      );
    } catch (e) {
      throw Exception('Failed to load grammar lesson: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> grammar_fetchGrammarPoints() {
    return _firestore
        .collection('grammar')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      return docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'details': [
            ...(data['structures'] as List<dynamic>?)?.map((s) => {'name': s, 'description': ''}) ?? [],
            {'name': '', 'description': data['theory']?['tips'] ?? ''},
          ],
        };
      }).toList();
    });
  }

  Future<void> grammar_saveGrammarScore({
    required String topicId,
    required String exerciseId,
    required bool isCorrect,
    required String exerciseType,
    int scorePerQuestion = 10,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final grammarRef = userDocRef
        .collection('learningProgress')
        .doc('grammar')
        .collection('grammar')
        .doc(topicId);

    try {
      final docSnapshot = await grammarRef.get();
      Map<String, dynamic> existingQuestions = docSnapshot.exists && docSnapshot.data() != null
          ? Map<String, dynamic>.from(docSnapshot.data()!['questions'] ?? {})
          : {};

      bool currentStatus = existingQuestions.containsKey(exerciseId)
          ? existingQuestions[exerciseId]['status'] ?? false
          : false;
      int currentAttempts = existingQuestions.containsKey(exerciseId)
          ? existingQuestions[exerciseId]['attempts'] ?? 0
          : 0;

      if (!currentStatus && isCorrect) {
        existingQuestions[exerciseId] = {
          'status': true,
          'type': exerciseType,
          'score': scorePerQuestion,
          'attempts': currentAttempts + 1,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));

        await grammar_updateSummary(userDocRef, topicId);
      } else if (!existingQuestions.containsKey(exerciseId)) {
        existingQuestions[exerciseId] = {
          'status': isCorrect,
          'type': exerciseType,
          'score': isCorrect ? scorePerQuestion : 0,
          'attempts': 1,
          'completedAt': isCorrect ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));

        await grammar_updateSummary(userDocRef, topicId);
      } else {
        existingQuestions[exerciseId] = {
          ...existingQuestions[exerciseId],
          'attempts': currentAttempts + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await grammarRef.set({
          'topic_id': topicId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'questions': existingQuestions,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to save score: $e');
    }
  }

  Future<void> grammar_updateSummary(DocumentReference userDocRef, String topicId) async {
    final grammarRef = userDocRef
        .collection('learningProgress')
        .doc('grammar')
        .collection('grammar')
        .doc(topicId);
    final summaryRef = userDocRef
        .collection('learningProgress')
        .doc('grammarSummary')
        .collection('grammarSummary')
        .doc(topicId);

    try {
      final docSnapshot = await grammarRef.get();
      if (!docSnapshot.exists) return;

      Map<String, dynamic> questions = docSnapshot.data()!['questions'] ?? {};
      int completedQuestions = questions.length;

      final exercisesSnapshot = await _firestore
          .collection('grammar')
          .doc(topicId)
          .collection('exercises')
          .get();
      int totalQuestions = exercisesSnapshot.docs.length;

      int totalCorrect = questions.values.where((q) => q['status'] == true).length;
      int totalScore = questions.values.fold<int>(0, (sum, q) => sum + ((q['score'] as num?)?.toInt() ?? 0));
      double progress = totalQuestions > 0 ? totalCorrect / totalQuestions : 0;

      await summaryRef.set({
        'topic_id': topicId,
        'totalQuestions': totalQuestions,
        'completedQuestions': completedQuestions,
        'totalCorrect': totalCorrect,
        'totalScore': totalScore,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update summary: $e');
    }
  }

  // Profile-related methods
  Future<DocumentSnapshot<Map<String, dynamic>>> profile_getUserDocument(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  Future<void> profile_updateUserDocument(String userId, Map<String, dynamic> data) {
    return _firestore.collection('users').doc(userId).update(data);
  }

  // Grammar-related methods for ProfileService
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> grammar_getTopics() {
    return _firestore.collection('grammar').get().then((snapshot) => snapshot.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> grammar_getSummary(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('grammarSummary')
        .collection('grammarSummary')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  // IPA (Pronunciation)-related methods for ProfileService
  Future<DocumentSnapshot<Map<String, dynamic>>> ipa_getSummary(String userId) async {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('ipa')
        .get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> ipa_getTopics() {
    return _firestore.collection('ipa_pronunciation').get().then((snapshot) => snapshot.docs);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> ipa_getIpaSummary(String userId, String ipaId) async {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('ipa')
        .collection(ipaId)
        .doc('summary')
        .get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>  ipa_getLessons(String ipaId) {
    return _firestore
        .collection('ipa_pronunciation')
        .doc(ipaId)
        .collection('lessons')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  // Vocab-related methods for ProfileService
  Future<DocumentSnapshot<Map<String, dynamic>>> vocab_getSummary(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('vocabulary')
        .get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> vocab_getTopic(String topicId) {
    return _firestore.collection('vocabs_topics').doc(topicId).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> vocab_getTopicSummary(
      String userId, String topicId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('vocabulary')
        .collection(topicId)
        .doc('summary')
        .get();
  }

  // Conversation-related methods for ProfileService
  Future<DocumentSnapshot<Map<String, dynamic>>> conversation_getSummary(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('conversation')
        .get();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> conversation_getTopics() {
    return _firestore.collection('pronunciation_topics').get().then((snapshot) => snapshot.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> conversation_getUserTopics(
      String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('conversation')
        .collection('topics')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> conversation_getLessonScores(
      String userId, String topicId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learningProgress')
        .doc('conversation')
        .collection('lessons')
        .where('topicId', isEqualTo: topicId)
        .get()
        .then((snapshot) => snapshot.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> conversation_getLessons(
      String topicId) {
    return _firestore
        .collection('pronunciation_topics')
        .doc(topicId)
        .collection('lessons')
        .get()
        .then((snapshot) => snapshot.docs);
  }
}