class IpaPronunciation {
  final String id;
  final String word;
  final String ipa;
  final String exampleWord;
  final String exampleWordIpa;
  final String ipaAudio;
  final String group;
  final String translatedGroup;
  final String type;
  final String translatedType;
  final String description;
  final String? ipaDescriptionImage;

  IpaPronunciation({
    required this.id,
    required this.word,
    required this.ipa,
    required this.exampleWord,
    required this.exampleWordIpa,
    required this.ipaAudio,
    required this.group,
    required this.translatedGroup,
    required this.type,
    required this.translatedType,
    required this.description,
    this.ipaDescriptionImage,
  });

  factory IpaPronunciation.fromMap(String id, Map<String, dynamic> data) {
    return IpaPronunciation(
      id: id,
      word: data['word'] ?? '',
      ipa: data['ipa'] ?? '',
      exampleWord: data['example_word'] ?? '',
      exampleWordIpa: data['example_word_ipa'] ?? '',
      ipaAudio: data['ipa_audio'] ?? '',
      group: data['group'] ?? 'unknown',
      translatedGroup: data['translated_group'] ?? 'unknown',
      type: data['type'] ?? 'unknown',
      translatedType: data['translated_type'] ?? 'unknown',
      description: data['describe'] ?? 'No description available',
      ipaDescriptionImage: data['ipa_description_image'],
    );
  }
}