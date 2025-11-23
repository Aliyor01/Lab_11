import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("BG Message: ${message.notification?.title}");
}

final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initNotifications();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}


Future<void> _initNotifications() async {
  // Ask permissions (iOS + Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

 
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await flnp.initialize(initSettings);

 
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'messages_channel',
    'Messages Channel',
    description: 'Shows message notifications',
    importance: Importance.max,
  );

  await flnp
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  
  FirebaseMessaging.onMessage.listen((m) {
    flnp.show(
      0,
      m.notification?.title ?? "New Message",
      m.notification?.body ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages_channel',
          'Messages Channel',
        ),
      ),
    );
  });

 
  print("FCM Token: ${await FirebaseMessaging.instance.getToken()}");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}


class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final TextEditingController controller = TextEditingController();

  Future<void> addMsg() async {
    if (controller.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'text': controller.text,
      'createdAt': Timestamp.now(),
    });

    controller.clear();
  }

  Future<void> editMsg(String id, String old) async {
    final t = TextEditingController(text: old);

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Edit Message"),
          content: TextField(controller: t),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('messages')
                    .doc(id)
                    .update({'text': t.text});
                Navigator.pop(context);
              },
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(
        children: [
         
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Enter message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: addMsg,
                )
              ],
            ),
          ),

          
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) return const SizedBox();

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i];
                    final id = d.id;
                    final text = d['text'];

                    return ListTile(
                      title: Text(text),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => editMsg(id, text),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => FirebaseFirestore.instance
                                .collection('messages')
                                .doc(id)
                                .delete(),
                          ),
                        ],
                      ),
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
