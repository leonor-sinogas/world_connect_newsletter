import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';
import 'models.dart';
import 'session_controller.dart';

const _lightBlue = Color(0xFF64B5F6);
const _purple = Color(0xFF9B6BDB);

class WorldConnectApp extends StatefulWidget {
  const WorldConnectApp({super.key});
  @override
  State<WorldConnectApp> createState() => _WorldConnectAppState();
}

class _WorldConnectAppState extends State<WorldConnectApp> {
  late final SessionController session = SessionController(ApiClient())
    ..addListener(_changed);
  void _changed() => setState(() {});
  @override
  void dispose() {
    session.removeListener(_changed);
    session.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? _purple : _lightBlue,
      brightness: brightness,
      surface: dark ? const Color(0xFF102743) : const Color(0xFFE8F4FF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xB31A3555) : const Color(0xA6B9DCF4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
        fillColor: dark ? const Color(0x663A5B7D) : const Color(0x99FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  ThemeMode get _mode => switch (session.appearance) {
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
    AppAppearance.system => ThemeMode.system,
  };
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'World Connect',
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: _mode,
    home: _Backdrop(
      child: session.user == null
          ? SignInPage(session: session)
          : HomeShell(session: session),
    ),
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF061A38)
              : const Color(0xFFB9DCF4),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.dark
                ? 'assets/dark_background.png'
                : 'assets/background.png',
            fit: BoxFit.fill,
          ),
        ),
      ),
      Positioned.fill(
        child: ColoredBox(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x33102743)
              : const Color(0x220A5A9C),
        ),
      ),
      child,
    ],
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Card(
        color: color,
        margin: EdgeInsets.zero,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.session});
  final SessionController session;
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final username = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool signup = false, hidden = true;
  @override
  void dispose() {
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? _purple : _lightBlue;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Transform.translate(
              offset: const Offset(0, -100),
              child: GlassCard(
                color: dark ? const Color(0xE0092748) : const Color(0xB8B9DCF4),
                child: Column(
                  children: [
                    Icon(Icons.public, size: 82, color: accent),
                    const SizedBox(height: 12),
                    Text(
                      'World Connect',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : null,
                      ),
                    ),
                    Text(
                      'Small newsletters. Real friendships.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Username'),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(),
                    ),
                    if (signup) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Email'),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Password'),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: password,
                      obscureText: hidden,
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidden ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => hidden = !hidden),
                        ),
                      ),
                    ),
                    if (widget.session.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          widget.session.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: accent),
                        onPressed: widget.session.busy
                            ? null
                            : () => widget.session.authenticate(
                                username: username.text,
                                password: password.text,
                                email: signup ? email.text : null,
                              ),
                        child: Text(signup ? 'Create account' : 'Sign in'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => signup = !signup),
                      child: Text(
                        signup
                            ? 'Already have an account?'
                            : 'Create a new account',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});
  final SessionController session;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    widget.session.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FeedPage(session: widget.session),
      NewslettersPage(session: widget.session),
      FriendsPage(session: widget.session),
      if (widget.session.user?.isAdmin == true)
        AdminPage(session: widget.session),
      ProfilePage(session: widget.session),
    ];
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('Home'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.mail),
        selectedIcon: Icon(Icons.mail),
        label: Text('Newsletters'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Friends'),
      ),
      if (widget.session.user?.isAdmin == true)
        const NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: Text('Admin'),
        ),
      const NavigationRailDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: Text('Profile'),
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('World Connect'),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: widget.session.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 12),
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.transparent,
              indicatorColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .18),
              destinations: destinations,
            ),
          ),
          Expanded(child: pages[index]),
        ],
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: child,
        ),
      ),
    ],
  );
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.session});
  final SessionController session;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<User>> users = widget.session.adminUsers();
  void reload() => setState(() => users = widget.session.adminUsers());
  @override
  Widget build(BuildContext context) => PageFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Account management. Passwords are never displayed; administrators can issue secure resets.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<User>>(
          future: users,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            return Column(
              children: snapshot.data!
                  .map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassCard(
                        child: Row(
                          children: [
                            user.photoUrl.isNotEmpty
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      user.photoUrl,
                                    ),
                                  )
                                : const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(user.email),
                                  Text(
                                    user.isAdmin ? 'Administrator' : 'Member',
                                  ),
                                ],
                              ),
                            ),
                            if (!user.isAdmin) ...[
                              IconButton(
                                tooltip: 'Reset password',
                                icon: const Icon(Icons.key),
                                onPressed: () => _adminResetDialog(
                                  context,
                                  widget.session,
                                  user,
                                  reload,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete account',
                                icon: const Icon(Icons.delete),
                                onPressed: () => _adminDeleteDialog(
                                  context,
                                  widget.session,
                                  user,
                                  reload,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

Future<void> _adminResetDialog(
  BuildContext context,
  SessionController session,
  User user,
  VoidCallback reload,
) async {
  final password = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Reset ${user.username} password'),
      content: TextField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'New password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (password.text.length < 12) return;
            await session.adminResetPassword(user.id, password.text);
            password.clear();
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            reload();
          },
          child: const Text('Reset'),
        ),
      ],
    ),
  );
  password.dispose();
}

Future<void> _adminDeleteDialog(
  BuildContext context,
  SessionController session,
  User user,
  VoidCallback reload,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Delete ${user.username}?'),
      content: const Text(
        'This removes the account and disconnects its account relationships. Newsletter content is retained without the deleted author.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await session.adminDeleteUser(user.id);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            reload();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class FeedPage extends StatelessWidget {
  const FeedPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text(
        'Your world, lately',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      const Text('The latest conversations from newsletters you follow.'),
      const SizedBox(height: 16),
    ];
    if (session.feed.isEmpty) {
      children.add(
        const GlassCard(
          child: Text('No replies to newsletters you subscribe to yet.'),
        ),
      );
    } else {
      children.addAll(
        session.feed.map(
          (issue) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IssueCard(
              issue: issue,
              session: session,
              allowNewIssue: true,
            ),
          ),
        ),
      );
      children.add(
        Center(
          child: OutlinedButton(
            onPressed: session.feedHasMore ? session.loadMoreFeed : null,
            child: Text(
              session.feedHasMore
                  ? 'Load more'
                  : 'There are no more replies to newsletters you subscribe to',
            ),
          ),
        ),
      );
    }
    if (session.error != null)
      children.add(
        Text(
          session.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.issue,
    required this.session,
    this.allowNewIssue = true,
  });
  final Issue issue;
  final SessionController session;
  final bool allowNewIssue;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.newsletter.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: dark ? _purple : _lightBlue,
                  ),
                ),
              ),
              if (allowNewIssue) ...[
                if (issue.authorId == session.user?.id)
                  IconButton(
                    tooltip: 'Edit',
                    color: dark ? Colors.white : Colors.black,
                    icon: const Icon(Icons.create),
                    onPressed: () =>
                        _confirmDeleteIssue(context, session, issue.id),
                  ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: 'Add issue',
                  icon: const Icon(Icons.add_circle),
                  onPressed: () =>
                      _issueComposer(context, session, issue.newsletterId),
                ),
              ],
            ],
          ),
          Text(
            issue.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 27,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            'by ${issue.author}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(issue.body),
          if (issue.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Gallery(urls: issue.imageUrls),
          ],
          const Divider(height: 26),
          ...issue.replies.map(
            (reply) => _ReplyTile(reply: reply, session: session),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _replyComposer(context, session, issue.id),
              icon: const Icon(Icons.reply),
              label: const Text('Write a reply'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply, required this.session});
  final Map<String, dynamic> reply;
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final name =
        reply['author_name']?.toString() ??
        reply['username']?.toString() ??
        'User';
    final rawPhoto =
        reply['author_photo_url']?.toString() ??
        reply['profile_photo_url']?.toString() ??
        '';
    final photo = rawPhoto.startsWith('/')
        ? '${session.api.baseUrl}$rawPhoto'
        : rawPhoto;
    final body = reply['body']?.toString() ?? '';
    final image = reply['image_url']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo.isEmpty
              ? const CircleAvatar(
                  radius: 16,
                  child: Icon(Icons.person, size: 18),
                )
              : CircleAvatar(radius: 16, backgroundImage: NetworkImage(photo)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (body.isNotEmpty) Text(body),
                if (image.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Image.network(image, height: 120, fit: BoxFit.cover),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.urls});
  final List<String> urls;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: urls.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(urls[i], width: 180, fit: BoxFit.cover),
      ),
    ),
  );
}

class NewslettersPage extends StatelessWidget {
  const NewslettersPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Newsletters',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          FloatingActionButton.small(
            heroTag: 'new-newsletter',
            onPressed: () => _newsletterComposer(context, session),
            child: const Icon(Icons.create),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    if (session.newsletters.isEmpty)
      children.add(const GlassCard(child: Text('No newsletters yet.')));
    for (final n in session.newsletters) {
      if (n.ownerId == session.user?.id && n.visibility == 'private') {
        children.insert(
          0,
          _PendingJoinRequests(session: session, newsletter: n),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF2FAF4),
                      child: Icon(
                        Icons.mail_outline,
                        size: 31,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 25,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? _purple
                                      : null,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(n.description),
                          Text('${n.category} · ${n.visibility}'),
                        ],
                      ),
                    ),
                    if (n.subscribed)
                      IconButton(
                        tooltip: 'Write a new issue',
                        icon: const Icon(Icons.add_circle),
                        onPressed: () => _issueComposer(context, session, n.id),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (n.subscribed)
                      OutlinedButton(
                        onPressed: n.ownerId == session.user?.id
                            ? () => _transferOwnerDialog(context, session, n)
                            : () => session.subscribe(n),
                        child: const Text('Leave'),
                      )
                    else if (n.visibility == 'private' &&
                        n.joinStatus == 'pending')
                      const TextButton(onPressed: null, child: Text('Pending'))
                    else if (n.visibility == 'private')
                      OutlinedButton(
                        onPressed: () => session.requestJoin(n),
                        child: const Text('Request to join'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => session.subscribe(n),
                        child: const Text('Join'),
                      ),
                    if (n.subscribed) ...[
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => _inviteDialog(context, session, n),
                        child: const Text('Invite friends'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _PendingJoinRequests extends StatelessWidget {
  const _PendingJoinRequests({required this.session, required this.newsletter});
  final SessionController session;
  final Newsletter newsletter;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: session.joinRequests(newsletter.id),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? const <Map<String, dynamic>>[];
          if (requests.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join requests · ${newsletter.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...requests.map(
                    (request) => Row(
                      children: [
                        request['requester_photo_url']?.toString().isNotEmpty ==
                                true
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage(
                                  request['requester_photo_url'].toString(),
                                ),
                              )
                            : const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person, size: 16),
                              ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['requester_username']?.toString() ?? 'User',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Approve',
                          icon: const Icon(Icons.check),
                          onPressed: () => session.reviewJoinRequest(
                            newsletter.id,
                            request['id'] as int,
                            'approve',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Deny',
                          icon: const Icon(Icons.close),
                          onPressed: () => session.reviewJoinRequest(
                            newsletter.id,
                            request['id'] as int,
                            'deny',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, required this.session});
  final SessionController session;
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  int friendLimit = 5, discoverLimit = 5;
  List<Map<String, dynamic>> _list(String key) {
    final value =
        widget.session.friends[key == 'discover' ? 'prospective' : key];
    return value is List
        ? value.whereType<Map<String, dynamic>>().toList()
        : [];
  }

  @override
  Widget build(BuildContext context) {
    final friends = _list('friends'),
        discover = _list('discover'),
        incoming = _list('incoming');
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (incoming.isNotEmpty) _incomingSection(incoming),
          _section('Friends', friends.take(friendLimit).toList(), true),
          if (friends.length > friendLimit)
            Center(
              child: TextButton(
                onPressed: () => setState(() => friendLimit += 5),
                child: const Text('Load more'),
              ),
            ),
          const SizedBox(height: 18),
          _section('Discover', discover.take(discoverLimit).toList(), false),
          if (discover.length > discoverLimit)
            Center(
              child: TextButton(
                onPressed: () => setState(() => discoverLimit += 5),
                child: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _incomingSection(List<Map<String, dynamic>> requests) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Friend requests', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      ...requests.map(
        (request) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            child: Row(
              children: [
                request['requester_photo_url']?.toString().isNotEmpty == true
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(
                          request['requester_photo_url'].toString(),
                        ),
                      )
                    : const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${request['requester_username'] ?? 'User'} wants to be your friend',
                  ),
                ),
                IconButton(
                  tooltip: 'Accept',
                  icon: const Icon(Icons.check),
                  onPressed: () => widget.session.respondToFriendRequest(
                    request['id'] as int,
                    'accepted',
                  ),
                ),
                IconButton(
                  tooltip: 'Deny',
                  icon: const Icon(Icons.close),
                  onPressed: () => widget.session.respondToFriendRequest(
                    request['id'] as int,
                    'rejected',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _section(
    String title,
    List<Map<String, dynamic>> items,
    bool isFriend,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      if (items.isEmpty)
        GlassCard(
          child: Text(
            isFriend ? 'No friends yet.' : 'No new users to discover.',
          ),
        )
      else
        ...items.map(
          (u) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              child: Row(
                children: [
                  u['profile_photo_url']?.toString().isNotEmpty == true
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(
                            u['profile_photo_url'].toString(),
                          ),
                        )
                      : const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(u['username']?.toString() ?? 'User')),
                  if (!isFriend)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add friend'),
                      onPressed: () => widget.session.addFriend(u['id'] as int),
                    ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) {
    final user = session.user!;
    return PageFrame(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: GlassCard(
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      user.photoUrl.isEmpty
                          ? const CircleAvatar(
                              radius: 48,
                              child: Icon(Icons.person, size: 45),
                            )
                          : CircleAvatar(
                              radius: 48,
                              backgroundImage: NetworkImage(user.photoUrl),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(user.email),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null)
                            await session.updateProfilePicture(
                              bytes: await picked.readAsBytes(),
                              filename: picked.name,
                            );
                        },
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Change profile picture'),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'Appearance',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AppAppearance>(
                        segments: const [
                          ButtonSegment(
                            value: AppAppearance.system,
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: AppAppearance.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: AppAppearance.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {session.appearance},
                        onSelectionChanged: (v) =>
                            session.setAppearance(v.first),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteIssue(
  BuildContext context,
  SessionController session,
  int issueId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete issue?'),
      content: const Text(
        'This issue and its replies will be permanently removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) await session.deleteIssue(issueId);
}

Future<void> _replyComposer(
  BuildContext context,
  SessionController session,
  int issueId,
) async {
  final body = TextEditingController();
  final image = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Write a reply'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Reply (under 300 words)'),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: body,
              maxLength: 300,
              maxLines: 4,
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Add image (optional)'),
            ),
            const SizedBox(height: 5),
            TextField(
              controller: image,
              decoration: const InputDecoration(hintText: 'Image URL'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (body.text.trim().isEmpty && image.text.trim().isEmpty) return;
            await session.reply(issueId, body.text, imageUrl: image.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Post'),
        ),
      ],
    ),
  );
  body.dispose();
  image.dispose();
}

Future<void> _issueComposer(
  BuildContext context,
  SessionController session,
  int newsletterId,
) async {
  final title = TextEditingController(), body = TextEditingController();
  final images = <XFile>[];
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xE01A3555)
            : const Color(0xD9B9DCF4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Write a new issue'),
        content: SizedBox(
          width: 700,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edition title'),
                const SizedBox(height: 5),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 14),
                const Text('Text'),
                const SizedBox(height: 5),
                TextField(
                  controller: body,
                  maxLength: 300,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(alignLabelWithHint: true),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add PNG or JPG images'),
                    onPressed: () async {
                      final picked = await ImagePicker().pickMultiImage(
                        imageQuality: 92,
                      );
                      if (picked.isNotEmpty)
                        setDialogState(() {
                          images.addAll(picked.take(10 - images.length));
                        });
                    },
                  ),
                ),
                if (images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${images.length} image${images.length == 1 ? '' : 's'} selected',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
              final uploadImages = <({Uint8List bytes, String filename})>[];
              for (final image in images)
                uploadImages.add((
                  bytes: await image.readAsBytes(),
                  filename: image.name,
                ));
              await session.createNewsletterPost(
                newsletterId: newsletterId,
                title: title.text,
                body: body.text,
                images: uploadImages,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  body.dispose();
}

Future<void> _newsletterComposer(
  BuildContext context,
  SessionController session,
) async {
  final title = TextEditingController(),
      desc = TextEditingController(),
      issueTitle = TextEditingController(),
      issueBody = TextEditingController();
  final images = <XFile>[];
  final selectedFriends = <int>{};
  final rawFriends = session.friends['friends'];
  final friends = rawFriends is List
      ? rawFriends.whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];
  var visibility = 'public';
  var category = 'friends';
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xE01A3555)
            : const Color(0xD9B9DCF4),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Create a newsletter'),
        content: SizedBox(
          width: 700,
          height: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Newsletter title'),
                const SizedBox(height: 5),
                TextField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                const Text('Description'),
                const SizedBox(height: 5),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  maxLength: 20000,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'friends',
                            child: Text('Friends'),
                          ),
                          DropdownMenuItem(
                            value: 'travel',
                            child: Text('Travel'),
                          ),
                          DropdownMenuItem(
                            value: 'updates',
                            child: Text('Updates'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => category = v ?? category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: visibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Public'),
                          ),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Private'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => visibility = v ?? visibility),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                const Text(
                  'First edition (optional)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('Edition title'),
                const SizedBox(height: 5),
                TextField(
                  controller: issueTitle,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 10),
                const Text('Text'),
                const SizedBox(height: 5),
                TextField(
                  controller: issueBody,
                  maxLines: 6,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add PNG or JPG images'),
                    onPressed: () async {
                      final picked = await ImagePicker().pickMultiImage(
                        imageQuality: 92,
                      );
                      if (picked.isNotEmpty)
                        setDialogState(
                          () => images.addAll(picked.take(10 - images.length)),
                        );
                    },
                  ),
                ),
                if (images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${images.length} image${images.length == 1 ? '' : 's'} selected',
                    ),
                  ),
                const Divider(height: 32),
                const Text(
                  'Invite friends',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...friends.map(
                  (friend) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selectedFriends.contains(friend['id']),
                    title: Text(friend['username']?.toString() ?? 'User'),
                    onChanged: (checked) => setDialogState(() {
                      final id = friend['id'] as int;
                      checked == true
                          ? selectedFriends.add(id)
                          : selectedFriends.remove(id);
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final imageUrls = <String>[];
              for (final image in images)
                imageUrls.add(
                  await session.api.uploadImage(
                    await image.readAsBytes(),
                    image.name,
                  ),
                );
              await session.createNewsletter(
                title: title.text,
                description: desc.text,
                visibility: visibility,
                category: category,
                issueTitle: issueTitle.text,
                issueBody: issueBody.text,
                issueImageUrls: imageUrls,
                inviteeIds: selectedFriends.toList(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Create newsletter'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  desc.dispose();
  issueTitle.dispose();
  issueBody.dispose();
}

Future<void> _inviteDialog(
  BuildContext context,
  SessionController session,
  Newsletter n,
) async {
  final raw = session.friends['friends'];
  final friends = raw is List
      ? raw.whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];
  final selected = <int>{};
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, set) {
        final rows = friends
            .map<Widget>(
              (f) => CheckboxListTile(
                value: selected.contains(f['id']),
                title: Text(f['username'].toString()),
                onChanged: (v) => set(() {
                  final id = f['id'] as int;
                  v == true ? selected.add(id) : selected.remove(id);
                }),
              ),
            )
            .toList();
        return AlertDialog(
          title: const Text('Invite friends'),
          content: SizedBox(
            width: 360,
            child: ListView(shrinkWrap: true, children: rows),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await session.inviteFriendsToNewsletter(
                  n.id,
                  selected.toList(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Invite'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _transferOwnerDialog(
  BuildContext context,
  SessionController session,
  Newsletter newsletter,
) async {
  final raw = session.friends['friends'];
  final friends = raw is List
      ? raw.whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];
  if (friends.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Transfer ownership'),
        content: Text(
          'You need an accepted friend who is subscribed before you can transfer ownership.',
        ),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Choose a new owner for ${newsletter.title}'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: friends
              .map(
                (friend) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(friend['username']?.toString() ?? 'User'),
                  onTap: () async {
                    await session.transferNewsletterOwnership(
                      newsletter.id,
                      friend['id'] as int,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<void> _reviewJoinDialog(
  BuildContext context,
  SessionController session,
  Newsletter newsletter,
) async {
  final requests = await session.joinRequests(newsletter.id);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Join requests'),
      content: requests.isEmpty
          ? const Text('No pending requests.')
          : SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: requests
                    .map(
                      (request) => ListTile(
                        title: Text('User #${request['requester_id']}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Approve',
                              icon: const Icon(Icons.check),
                              onPressed: () async {
                                await session.reviewJoinRequest(
                                  newsletter.id,
                                  request['id'] as int,
                                  'approve',
                                );
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext);
                              },
                            ),
                            IconButton(
                              tooltip: 'Deny',
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                await session.reviewJoinRequest(
                                  newsletter.id,
                                  request['id'] as int,
                                  'deny',
                                );
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext);
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
