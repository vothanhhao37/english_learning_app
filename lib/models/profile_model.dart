class ProfileModel {
  final String id;
  final String name;
  final String email;
  final Map<String, dynamic> grammarProgress;
  final Map<String, dynamic> pronunciationProgress;
  final Map<String, dynamic> vocabularyProgress;
  final Map<String, dynamic> conversationProgress;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.grammarProgress = const {},
    this.pronunciationProgress = const {},
    this.vocabularyProgress = const {},
    this.conversationProgress = const {},
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map, String id) {
    return ProfileModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      grammarProgress: map['grammarProgress'] ?? {},
      pronunciationProgress: map['pronunciationProgress'] ?? {},
      vocabularyProgress: map['vocabularyProgress'] ?? {},
      conversationProgress: map['conversationProgress'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'grammarProgress': grammarProgress,
      'pronunciationProgress': pronunciationProgress,
      'vocabularyProgress': vocabularyProgress,
      'conversationProgress': conversationProgress,
    };
  }

  ProfileModel copyWith({
    String? name,
    String? email,
    Map<String, dynamic>? grammarProgress,
    Map<String, dynamic>? pronunciationProgress,
    Map<String, dynamic>? vocabularyProgress,
    Map<String, dynamic>? conversationProgress,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      grammarProgress: grammarProgress ?? this.grammarProgress,
      pronunciationProgress: pronunciationProgress ?? this.pronunciationProgress,
      vocabularyProgress: vocabularyProgress ?? this.vocabularyProgress,
      conversationProgress: conversationProgress ?? this.conversationProgress,
    );
  }
} 