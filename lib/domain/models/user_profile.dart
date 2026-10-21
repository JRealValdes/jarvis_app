/// Local user profile used for prompts (personal app, single user).
class UserProfile {
  const UserProfile({
    required this.jarvisName,
    required this.isFemale,
  });

  final String jarvisName;
  final bool isFemale;

  String get honorific => isFemale ? "ma'am" : 'sir';

  Map<String, dynamic> toJson() => {
        'jarvis_name': jarvisName,
        'is_female': isFemale,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      jarvisName: (json['jarvis_name'] as String?)?.trim().isNotEmpty == true
          ? (json['jarvis_name'] as String).trim()
          : 'sir',
      isFemale: json['is_female'] == true,
    );
  }
}
