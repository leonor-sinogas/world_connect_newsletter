import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';

enum AppAppearance { system, light, dark }

class SessionController extends ChangeNotifier {
  SessionController(this.api);
  final ApiClient api;
  User? user;
  List<Issue> feed = const [];
  bool feedHasMore = false;
  bool feedLoading = false;
  static const int feedPageSize = 5;
  List<Newsletter> newsletters = const [];
  Map<String, dynamic> friends = const {};
  bool busy = false;
  String? error;
  AppAppearance appearance = AppAppearance.system;

  Future<void> setAppearance(AppAppearance value) async {
    if (appearance == value) return;
    final current = user;
    appearance = value;
    notifyListeners();
    if (current == null) return;
    await _run(() async {
      final data =
          await api.request(
                '/users/${current.id}',
                method: 'PATCH',
                body: {
                  'profile_photo_url': current.photoUrl,
                  'time_zone': current.timeZone,
                  'appearance': _appearanceName(value),
                },
              )
              as Map<String, dynamic>;
      user = User.fromJson(data);
    });
  }

  String _appearanceName(AppAppearance value) => switch (value) {
    AppAppearance.system => 'system',
    AppAppearance.light => 'light',
    AppAppearance.dark => 'dark',
  };

  AppAppearance _parseAppearance(String value) => switch (value) {
    'light' => AppAppearance.light,
    'dark' => AppAppearance.dark,
    _ => AppAppearance.system,
  };

  Future<void> authenticate({
    required String username,
    required String password,
    String? email,
  }) async {
    await _run(() async {
      final signup = email != null;
      final data =
          await api.request(
                signup ? '/auth/signup' : '/auth/login',
                method: 'POST',
                body: {
                  'username': username.trim(),
                  'password': password,
                  if (signup) 'email': email.trim(),
                  if (signup) 'time_zone': 'GMT',
                },
              )
              as Map<String, dynamic>;
      api.setToken(data['access_token'] as String);
      user = User.fromJson(data['user'] as Map<String, dynamic>);
      appearance = _parseAppearance(user!.appearance);
      await refresh();
    });
  }

  Future<void> refresh() async {
    final current = user;
    if (current == null) return;
    final results = await Future.wait([
      api.request('/users/${current.id}/feed?limit=$feedPageSize&offset=0'),
      api.request('/newsletters?user_id=${current.id}'),
      api.request('/users/${current.id}/friends'),
    ]);
    _setFeedPage(results[0], append: false);
    newsletters = (results[1] as List)
        .map((e) => Newsletter.fromJson(e))
        .toList();
    friends = results[2] as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> loadMoreFeed() async {
    final current = user;
    if (current == null || feedLoading || !feedHasMore) return;
    feedLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await api.request(
        '/users/${current.id}/feed?limit=$feedPageSize&offset=${feed.length}',
      );
      _setFeedPage(result, append: true);
    } catch (exception) {
      error = exception.toString();
    } finally {
      feedLoading = false;
      notifyListeners();
    }
  }

  void _setFeedPage(dynamic result, {required bool append}) {
    // Accept the former list response during rolling deployments.
    final rawItems = result is Map<String, dynamic>
        ? result['items'] as List? ?? const []
        : result as List? ?? const [];
    final page = rawItems
        .map((item) => Issue.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    feed = append ? <Issue>[...feed, ...page] : page;
    feedHasMore = result is Map<String, dynamic>
        ? result['has_more'] as bool? ?? false
        : page.length == feedPageSize;
  }

  Future<void> subscribe(Newsletter newsletter) => _run(() async {
    await api.request(
      '/newsletters/${newsletter.id}/subscribe?user_id=${user!.id}',
      method: newsletter.subscribed ? 'DELETE' : 'POST',
    );
    await refresh();
  });

  Future<void> transferNewsletterOwnership(int newsletterId, int newOwnerId) => _run(() async {
    await api.request('/newsletters/$newsletterId/transfer', method: 'POST', body: {'new_owner_id': newOwnerId});
    await refresh();
  });

  Future<void> requestJoin(Newsletter newsletter) => _run(() async {
    await api.request(
      '/newsletters/${newsletter.id}/join-request',
      method: 'POST',
    );
    await refresh();
  });

  Future<List<Map<String, dynamic>>> joinRequests(int newsletterId) async {
    final result = await api.request(
      '/newsletters/$newsletterId/join-requests',
    );
    return (result as List).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> reviewJoinRequest(
    int newsletterId,
    int requestId,
    String action,
  ) => _run(() async {
    await api.request(
      '/newsletters/$newsletterId/join-requests/$requestId?action=$action',
      method: 'PATCH',
    );
    await refresh();
  });

  Future<String?> newsletterShareLink(int newsletterId) async {
    String? link;
    await _run(() async {
      final data =
          await api.request(
                '/newsletters/$newsletterId/share-link',
                method: 'POST',
              )
              as Map<String, dynamic>;
      link = data['share_url'] as String?;
    });
    return link;
  }

  Future<bool> inviteFriendsToNewsletter(
    int newsletterId,
    List<int> friendIds,
  ) async {
    if (friendIds.isEmpty) return true;
    await _run(() async {
      for (final friendId in friendIds) {
        await api.request(
          '/newsletters/$newsletterId/invitations',
          method: 'POST',
          body: {'inviter_id': user!.id, 'invitee_id': friendId},
        );
      }
      await refresh();
    });
    return error == null;
  }

  Future<Newsletter?> createNewsletter({
    required String title,
    required String description,
    required String visibility,
    required String category,
    String issueTitle = '',
    String issueBody = '',
    String photoUrl = '',
    List<String> issueImageUrls = const [],
    List<int> inviteeIds = const [],
  }) async {
    Newsletter? created;
    await _run(() async {
      final data =
          await api.request(
                '/newsletters',
                method: 'POST',
                body: {
                  'owner_id': user!.id,
                  'title': title.trim(),
                  'description': description.trim(),
                  'visibility': visibility,
                  'category': category.trim(),
                  'image_url': photoUrl,
                  'invitee_ids': inviteeIds,
                },
              )
              as Map<String, dynamic>;
      created = Newsletter.fromJson(data);

      if (issueTitle.trim().isNotEmpty && issueBody.trim().isNotEmpty) {
        await api.request(
          '/newsletters/${created!.id}/issues',
          method: 'POST',
          body: {
            'author_id': user!.id,
            'title': issueTitle.trim(),
            'body': issueBody.trim(),
            'image_urls': issueImageUrls,
            'photo_url': issueImageUrls.isEmpty ? '' : issueImageUrls.first,
          },
        );
      }
      await refresh();
    });
    return created;
  }

  Future<bool> createNewsletterPost({
    required int newsletterId,
    required String title,
    required String body,
    required List<({Uint8List bytes, String filename})> images,
  }) async {
    var created = false;
    await _run(() async {
      // Upload first so a partially written post is never exposed when an
      // image upload fails. The API validates file type and size.
      final imageUrls = <String>[];
      for (final image in images) {
        imageUrls.add(await api.uploadImage(image.bytes, image.filename));
      }
      await api.request(
        '/newsletters/$newsletterId/issues',
        method: 'POST',
        body: {
          'author_id': user!.id,
          'title': title.trim(),
          'body': body.trim(),
          'image_urls': imageUrls,
          // Backward compatibility while older API deployments are replaced.
          'photo_url': imageUrls.isEmpty ? '' : imageUrls.first,
        },
      );
      created = true;
      await refresh();
    });
    return created;
  }

  Future<void> addFriend(int addresseeId) => _run(() async {
    await api.request(
      '/friend-requests',
      method: 'POST',
      body: {'requester_id': user!.id, 'addressee_id': addresseeId},
    );
    await refresh();
  });

  Future<void> respondToFriendRequest(int requestId, String status) =>
      _run(() async {
        await api.request(
          '/friend-requests/$requestId',
          method: 'PATCH',
          body: {'status': status},
        );
        await refresh();
      });

  Future<void> reply(int issueId, String body, {String imageUrl = ''}) =>
      _run(() async {
        await api.request(
          '/issues/$issueId/replies',
          method: 'POST',
          body: {
            'author_id': user!.id,
            'body': body.trim(),
            'image_url': imageUrl,
          },
        );
        await refresh();
      });

  Future<void> deleteIssue(int issueId) => _run(() async {
    await api.request('/issues/$issueId', method: 'DELETE');
    await refresh();
  });

  Future<void> updateProfilePicture({
    required Uint8List bytes,
    required String filename,
  }) => _run(() async {
    final current = user!;
    final photoUrl = await api.uploadImage(bytes, filename);
    final data =
        await api.request(
              '/users/${current.id}',
              method: 'PATCH',
              body: {
                'profile_photo_url': photoUrl,
                'time_zone': current.timeZone,
                'appearance': _appearanceName(appearance),
              },
            )
            as Map<String, dynamic>;
    user = User.fromJson(data);
    appearance = _parseAppearance(user!.appearance);
  });

  void signOut() {
    api.setToken(null);
    user = null;
    feed = const [];
    feedHasMore = false;
    feedLoading = false;
    newsletters = const [];
    notifyListeners();
  }

  void reportError(Object exception) {
    error = exception.toString();
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
