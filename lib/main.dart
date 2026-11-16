import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyABJBNyF2_hYXQzOytAFKOsKiEO9ZjbveA',
  appId: '1:130341563883:android:408b25d8521b4c14493dae',
  messagingSenderId: '130341563883',
  projectId: 'hello-kitty-chat-c1f63',
  storageBucket: 'hello-kitty-chat-c1f63.firebasestorage.app',
);

const Color kPink = Color(0xFFFF8FB8);
const Color kDeepPink = Color(0xFFE91E78);
const Color kLightPink = Color(0xFFFFE4EE);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const HelloKittyApp());
}

/// Accepts 3225588095, 03225588095, +923225588095 and returns +923225588095
String? normalizePk(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('92') && d.length == 12) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 10 || !d.startsWith('3')) return null;
  return '+92$d';
}

String chatIdFor(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}

String clockTime(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String listTime(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return clockTime(ts);
  if (diff == 1) return 'Yesterday';
  return '${d.day}/${d.month}/${d.year % 100}';
}

class HelloKittyApp extends StatelessWidget {
  const HelloKittyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hello Kitty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPink,
          primary: kDeepPink,
          secondary: kPink,
        ),
        scaffoldBackgroundColor: kLightPink,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPink,
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kDeepPink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('🎀', style: TextStyle(fontSize: 70)),
        SizedBox(height: 8),
        Text(
          'Hello Kitty Chat',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: kDeepPink,
          ),
        ),
      ],
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const PhoneScreen();
        return ProfileGate(user: user);
      },
    );
  }
}

class ProfileGate extends StatelessWidget {
  final User user;
  const ProfileGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snap.data!.exists) return NameScreen(user: user);
        return HomeScreen(user: user, name: snap.data!.data()?['name'] ?? '');
      },
    );
  }
}

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});
  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _sendCode() async {
    final phone = normalizePk(_controller.text);
    if (phone == null) {
      showMsg(context, 'Enter a valid number, for example 3225588095');
      return;
    }
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        showMsg(context, 'Failed: ${e.code} ${e.message ?? ''}');
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OtpScreen(verificationId: verificationId, phone: phone),
        ));
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Logo(),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixText: '+92  ',
                hintText: '3225588095',
                labelText: 'Phone number',
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendCode, child: const Text('Send Code')),
          ],
        ),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  const OtpScreen({super.key, required this.verificationId, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != 6) {
      showMsg(context, 'Enter the 6 digit code');
      return;
    }
    setState(() => _loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMsg(context, 'Wrong code or error: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Logo(),
            const SizedBox(height: 24),
            Text('Enter the code for ${widget.phone}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, letterSpacing: 8),
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _verify, child: const Text('Verify')),
          ],
        ),
      ),
    );
  }
}

class NameScreen extends StatefulWidget {
  final User user;
  const NameScreen({super.key, required this.user});
  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      showMsg(context, 'Please enter your name');
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
        'name': name,
        'phone': widget.user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMsg(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Name')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Logo(),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _save, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final User user;
  final String name;
  const HomeScreen({super.key, required this.user, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hello Kitty 🎀'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Hi $name! 💕',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kDeepPink)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, chatSnap) {
                final chatByUser = <String, Map<String, dynamic>>{};
                for (final c in chatSnap.data?.docs ?? []) {
                  final data = c.data();
                  final parts = List<String>.from(data['participants'] ?? []);
                  for (final p in parts) {
                    if (p != user.uid) chatByUser[p] = data;
                  }
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final people =
                        snap.data!.docs.where((d) => d.id != user.uid).toList();
                    int millis(String id) {
                      final t = chatByUser[id]?['lastTime'];
                      return t is Timestamp ? t.millisecondsSinceEpoch : 0;
                    }

                    people.sort((a, b) => millis(b.id).compareTo(millis(a.id)));
                    if (people.isEmpty) {
                      return const Center(
                          child: Text('No friends have joined yet'));
                    }
                    return ListView(
                      children: people.map((d) {
                        final data = d.data();
                        final n = (data['name'] ?? '?').toString();
                        final chat = chatByUser[d.id];
                        final unreadMap = chat?['unread'];
                        final unread = (unreadMap is Map
                                ? (unreadMap[user.uid] ?? 0)
                                : 0) as num;
                        final last = chat?['lastMessage']?.toString();
                        final time = chat?['lastTime'];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: kPink,
                            foregroundColor: Colors.white,
                            child: Text(n.isEmpty ? '?' : n[0].toUpperCase(),
                                style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(n,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            last ?? (data['phone'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread > 0 ? Colors.black87 : Colors.black54,
                              fontWeight:
                                  unread > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                time is Timestamp ? listTime(time) : '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unread > 0 ? kDeepPink : Colors.black45,
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kDeepPink,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${unread.toInt()}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                myUid: user.uid,
                                otherUid: d.id,
                                otherName: n,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String myUid;
  final String otherUid;
  final String otherName;
  const ChatScreen({
    super.key,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  late final String _chatId;
  String? _lastMarked;

  @override
  void initState() {
    super.initState();
    _chatId = chatIdFor(widget.myUid, widget.otherUid);
  }

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(_chatId);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _chatRef.collection('messages');

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_messages.doc(), {
      'text': text,
      'senderId': widget.myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _chatRef,
      {
        'participants': [widget.myUid, widget.otherUid],
        'lastMessage': text,
        'lastTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.myUid,
        'unread': {widget.otherUid: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  void _markRead(String latestId) {
    if (_lastMarked == latestId) return;
    _lastMarked = latestId;
    _chatRef.set({
      'unread': {widget.myUid: 0}
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('Say hi! \u{1F495}'));
                }
                if (docs.first.data()['senderId'] != widget.myUid) {
                  final id = docs.first.id;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _markRead(id));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final mine = m['senderId'] == widget.myUid;
                    final ts = m['createdAt'];
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.fromLTRB(14, 8, 12, 6),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine ? kDeepPink : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (m['text'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 16,
                                color: mine ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ts is Timestamp ? clockTime(ts) : '',
                              style: TextStyle(
                                fontSize: 11,
                                color: mine ? Colors.white70 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Type a message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: kDeepPink,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
