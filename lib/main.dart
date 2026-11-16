import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
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

bool isOnlineUser(Map<String, dynamic>? u) {
  if (u == null || u['online'] != true) return false;
  final t = u['lastSeen'];
  if (t is! Timestamp) return true;
  return DateTime.now().difference(t.toDate()).inSeconds < 90;
}

String lastSeenText(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'last seen today at ${clockTime(ts)}';
  if (diff == 1) return 'last seen yesterday at ${clockTime(ts)}';
  return 'last seen ${d.day}/${d.month}/${d.year % 100}';
}

String presenceText(Map<String, dynamic>? u) {
  if (u == null) return '';
  if (isOnlineUser(u)) return 'online';
  final t = u['lastSeen'];
  return t is Timestamp ? lastSeenText(t) : '';
}

const String supabaseUrl = 'https://hjqbibvqxhurgmtrqqre.supabase.co';
const String supabaseKey = 'sb_publishable_OnPlqyYikyD117VZTM80yw_3dYFjpRQ';
const String mediaBucket = 'chat-media';

String randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(
      bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String fmtDur(int seconds) {
  final m = seconds ~/ 60;
  final sec = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

Future<String> uploadToSupabase(
    File file, String folder, String ext, String contentType) async {
  final path = '$folder/${randomHex(16)}.$ext';
  final headers = <String, String>{
    'apikey': supabaseKey,
    'Content-Type': contentType,
  };
  if (supabaseKey.startsWith('eyJ')) {
    headers['Authorization'] = 'Bearer $supabaseKey';
  }
  final res = await http.post(
    Uri.parse('$supabaseUrl/storage/v1/object/$mediaBucket/$path'),
    headers: headers,
    body: await file.readAsBytes(),
  );
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Upload failed (${res.statusCode}): ${res.body}');
  }
  return '$supabaseUrl/storage/v1/object/public/$mediaBucket/$path';
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

class HomeScreen extends StatefulWidget {
  final User user;
  final String name;
  const HomeScreen({super.key, required this.user, required this.name});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _beat;
  Timer? _tick;

  DocumentReference<Map<String, dynamic>> get _me =>
      FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _goOnline();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _beat?.cancel();
    _tick?.cancel();
    _setPresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _goOnline();
    } else if (state != AppLifecycleState.inactive) {
      _goOffline();
    }
  }

  void _goOnline() {
    _setPresence(true);
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 30), (_) => _setPresence(true));
  }

  void _goOffline() {
    _beat?.cancel();
    _setPresence(false);
  }

  Future<void> _setPresence(bool online) async {
    try {
      await _me.set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _logout() async {
    _beat?.cancel();
    await _setPresence(false);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hello Kitty 🎀'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Hi ${widget.name}! 💕',
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
                        final online = isOnlineUser(data);
                        final chat = chatByUser[d.id];
                        final unreadMap = chat?['unread'];
                        final unread = (unreadMap is Map
                                ? (unreadMap[user.uid] ?? 0)
                                : 0) as num;
                        final typingMap = chat?['typing'];
                        final isTyping =
                            typingMap is Map && typingMap[d.id] == true && online;
                        final last = chat?['lastMessage']?.toString();
                        final time = chat?['lastTime'];
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: kPink,
                                foregroundColor: Colors.white,
                                child: Text(n.isEmpty ? '?' : n[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 20)),
                              ),
                              if (online)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border:
                                          Border.all(color: kLightPink, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(n,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            isTyping
                                ? 'typing…'
                                : (last ?? (data['phone'] ?? '').toString()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isTyping
                                  ? kDeepPink
                                  : (unread > 0 ? Colors.black87 : Colors.black54),
                              fontWeight: (unread > 0 || isTyping)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
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
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  late final String _chatId;
  String? _lastMarked;
  bool _isTyping = false;
  bool _uploading = false;
  bool _recording = false;
  int _recSeconds = 0;
  String? _recPath;
  Timer? _typingStop;
  Timer? _ticker;
  Timer? _recTimer;

  @override
  void initState() {
    super.initState();
    _chatId = chatIdFor(widget.myUid, widget.otherUid);
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stopTyping();
    _typingStop?.cancel();
    _ticker?.cancel();
    _recTimer?.cancel();
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(_chatId);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _chatRef.collection('messages');

  void _onTyping(String value) {
    setState(() {});
    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_isTyping) {
      _isTyping = true;
      _chatRef.set({
        'typing': {widget.myUid: true}
      }, SetOptions(merge: true));
    }
    _typingStop?.cancel();
    _typingStop = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    _typingStop?.cancel();
    if (!_isTyping) return;
    _isTyping = false;
    _chatRef.set({
      'typing': {widget.myUid: false}
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage({
    required String type,
    required String preview,
    String text = '',
    String? url,
    int? seconds,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_messages.doc(), {
      'type': type,
      'text': text,
      if (url != null) 'url': url,
      if (seconds != null) 'seconds': seconds,
      'senderId': widget.myUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _chatRef,
      {
        'participants': [widget.myUid, widget.otherUid],
        'lastMessage': preview,
        'lastTime': FieldValue.serverTimestamp(),
        'lastSenderId': widget.myUid,
        'unread': {widget.otherUid: FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _stopTyping();
    setState(() {});
    await _sendMessage(type: 'text', text: text, preview: text);
  }

  Future<void> _uploadAndSend({
    required File file,
    required String type,
    required String ext,
    required String contentType,
    required String preview,
    int? seconds,
  }) async {
    setState(() => _uploading = true);
    try {
      final size = await file.length();
      if (size > 50 * 1024 * 1024) {
        throw Exception('File is bigger than 50 MB');
      }
      final url = await uploadToSupabase(file, widget.myUid, ext, contentType);
      await _sendMessage(
          type: type, url: url, seconds: seconds, preview: preview);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(
        source: source, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    await _uploadAndSend(
      file: File(x.path),
      type: 'image',
      ext: 'jpg',
      contentType: 'image/jpeg',
      preview: '📷 Photo',
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final x = await _picker.pickVideo(
        source: source, maxDuration: const Duration(minutes: 2));
    if (x == null) return;
    await _uploadAndSend(
      file: File(x.path),
      type: 'video',
      ext: 'mp4',
      contentType: 'video/mp4',
      preview: '🎥 Video',
    );
  }

  void _showAttach() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: kDeepPink),
              title: const Text('Photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: kDeepPink),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: kDeepPink),
              title: const Text('Video from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: kDeepPink),
              title: const Text('Record a video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickVideo(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) showMsg(context, 'Microphone permission is needed');
        return;
      }
      final path =
          '${Directory.systemTemp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recPath = path;
      _recSeconds = 0;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not record: $e');
    }
  }

  Future<void> _finishRecording({required bool send}) async {
    _recTimer?.cancel();
    final seconds = _recSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recPath;
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    if (!send || seconds < 1) {
      try {
        await File(path).delete();
      } catch (_) {}
      return;
    }
    await _uploadAndSend(
      file: File(path),
      type: 'audio',
      ext: 'm4a',
      contentType: 'audio/mp4',
      preview: '🎤 Voice message (${fmtDur(seconds)})',
      seconds: seconds,
    );
  }

  void _markRead(String latestId) {
    if (_lastMarked == latestId) return;
    _lastMarked = latestId;
    _chatRef.set({
      'unread': {widget.myUid: 0}
    }, SetOptions(merge: true));
  }

  Widget _title() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUid)
          .snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _chatRef.snapshots(),
          builder: (context, chatSnap) {
            final u = userSnap.data?.data();
            final c = chatSnap.data?.data();
            final typingMap = c?['typing'];
            final typing = typingMap is Map &&
                typingMap[widget.otherUid] == true &&
                isOnlineUser(u);
            final status = typing ? 'typing…' : presenceText(u);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.otherName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                if (status.isNotEmpty)
                  Text(status,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.white70)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _content(Map<String, dynamic> m, bool mine) {
    final type = (m['type'] ?? 'text').toString();
    final url = (m['url'] ?? '').toString();
    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ImageViewerScreen(url: url))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, p) => p == null
                  ? child
                  : const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(child: CircularProgressIndicator())),
              errorBuilder: (c, e, s) => const SizedBox(
                  width: 220,
                  height: 120,
                  child: Center(child: Text('Image failed to load'))),
            ),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => VideoScreen(url: url))),
          child: Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
            ),
          ),
        );
      case 'audio':
        return AudioBubble(
            url: url, seconds: (m['seconds'] ?? 0) as int, mine: mine);
      default:
        return Text(
          (m['text'] ?? '').toString(),
          style: TextStyle(
            fontSize: 16,
            color: mine ? Colors.white : Colors.black87,
          ),
        );
    }
  }

  Widget _inputBar() {
    if (_recording) {
      return Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _finishRecording(send: false),
          ),
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Text(fmtDur(_recSeconds),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Expanded(child: SizedBox()),
          CircleAvatar(
            backgroundColor: kDeepPink,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _finishRecording(send: true),
            ),
          ),
        ],
      );
    }
    final hasText = _controller.text.trim().isNotEmpty;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, color: kDeepPink),
          onPressed: _uploading ? null : _showAttach,
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _onTyping,
            onSubmitted: (_) => _sendText(),
            decoration: const InputDecoration(hintText: 'Type a message'),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: kDeepPink,
          child: IconButton(
            icon: Icon(hasText ? Icons.send : Icons.mic, color: Colors.white),
            onPressed: hasText
                ? _sendText
                : (_uploading ? null : _startRecording),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: _title()),
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
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: mine ? kDeepPink : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _content(m, mine),
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
          if (_uploading) const LinearProgressIndicator(color: kDeepPink),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
              child: _inputBar(),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String url;
  const ImageViewerScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  final String url;
  const VideoScreen({super.key, required this.url});
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _failed
            ? const Text('Video failed to load',
                style: TextStyle(color: Colors.white))
            : _ready
                ? AspectRatio(
                    aspectRatio: _c.value.aspectRatio,
                    child: VideoPlayer(_c),
                  )
                : const CircularProgressIndicator(),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              backgroundColor: kDeepPink,
              onPressed: () =>
                  _c.value.isPlaying ? _c.pause() : _c.play(),
              child: Icon(
                _c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            )
          : null,
    );
  }
}

class AudioBubble extends StatefulWidget {
  final String url;
  final int seconds;
  final bool mine;
  const AudioBubble(
      {super.key, required this.url, required this.seconds, required this.mine});
  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final AudioPlayer _p = AudioPlayer();
  bool _playing = false;
  bool _started = false;
  Duration _pos = Duration.zero;
  Duration? _dur;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs.add(_p.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_p.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    }));
    _subs.add(_p.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_p.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _pos = Duration.zero;
          _playing = false;
          _started = false;
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _p.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _p.pause();
    } else if (_started) {
      await _p.resume();
    } else {
      _started = true;
      await _p.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mine ? Colors.white : kDeepPink;
    final total = _dur?.inSeconds ?? widget.seconds;
    final progress = (total > 0 && _dur != null)
        ? (_pos.inMilliseconds / _dur!.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
              color: color, size: 36),
          onPressed: _toggle,
        ),
        SizedBox(
          width: 110,
          child: LinearProgressIndicator(
            value: progress,
            color: color,
            backgroundColor: color.withAlpha(70),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fmtDur(_playing || _pos > Duration.zero ? _pos.inSeconds : total),
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }
}
