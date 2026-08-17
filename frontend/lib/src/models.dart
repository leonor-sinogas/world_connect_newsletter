class User {
  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.timeZone,
    required this.appearance,
    required this.isAdmin,
  });
  final int id;
  final String username;
  final String email;
  final String photoUrl;
  final String timeZone;
  final String appearance;
  final bool isAdmin;
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    photoUrl: json['profile_photo_url'] as String? ?? '',
    timeZone: json['time_zone'] as String? ?? 'GMT',
    appearance: json['appearance'] as String? ?? 'system',
    isAdmin: json['is_admin'] as bool? ?? false,
  );
}

class Newsletter {
  const Newsletter({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.category,
    required this.visibility,
    required this.subscribed,
    required this.canJoin,
    required this.imageUrl,
    this.joinStatus,
    this.shareUrl,
  });
  final int id;
  final int? ownerId;
  final String title;
  final String description;
  final String category;
  final String visibility;
  final bool subscribed;
  final bool canJoin;
  final String imageUrl;
  final String? joinStatus;
  final String? shareUrl;
  factory Newsletter.fromJson(Map<String, dynamic> json) => Newsletter(
    id: json['id'] as int,
    ownerId: json['owner_id'] as int?,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'friends',
    visibility: json['visibility'] as String? ?? 'public',
    subscribed: json['is_subscribed'] as bool? ?? false,
    canJoin: json['can_join'] as bool? ?? false,
    imageUrl: json['image_url'] as String? ?? '',
    joinStatus: json['join_status'] as String?,
    shareUrl: json['share_url'] as String?,
  );
}

class AdminNewsletter {
  const AdminNewsletter({
    required this.id,
    required this.ownerId,
    required this.ownerUsername,
    required this.title,
    required this.description,
    required this.visibility,
    required this.category,
  });
  final int id;
  final int? ownerId;
  final String ownerUsername;
  final String title;
  final String description;
  final String visibility;
  final String category;

  factory AdminNewsletter.fromJson(Map<String, dynamic> json) =>
      AdminNewsletter(
        id: json['id'] as int,
        ownerId: json['owner_id'] as int?,
        ownerUsername: json['owner_username'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        visibility: json['visibility'] as String? ?? 'public',
        category: json['category'] as String? ?? 'friends',
      );
}

class Issue {
  const Issue({
    required this.id,
    required this.newsletterId,
    required this.authorId,
    required this.title,
    required this.body,
    required this.author,
    required this.newsletter,
    required this.imageUrls,
    required this.replies,
  });
  final int id;
  final int newsletterId;
  final int? authorId;
  final String title;
  final String body;
  final String author;
  final String newsletter;
  final List<String> imageUrls;
  String get photoUrl => imageUrls.isEmpty ? '' : imageUrls.first;
  final List<Map<String, dynamic>> replies;
  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
    id: json['id'] as int,
    newsletterId: json['newsletter_id'] as int? ?? 0,
    authorId: json['author_id'] as int?,
    title: json['title'] as String,
    body: json['body'] as String,
    author: json['author_name'] as String? ?? '',
    newsletter: json['newsletter_title'] as String? ?? '',
    imageUrls: _imageUrls(json),
    replies: List<Map<String, dynamic>>.from(
      json['replies'] as List? ?? const [],
    ),
  );

  static List<String> _imageUrls(Map<String, dynamic> json) {
    final images = json['image_urls'];
    if (images is List) {
      return images
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false);
    }
    final legacy = json['photo_url'];
    return legacy is String && legacy.trim().isNotEmpty
        ? <String>[legacy]
        : const <String>[];
  }
}
