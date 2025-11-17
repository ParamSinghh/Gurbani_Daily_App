import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(MyApp());
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleDailyMorningNotification({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    var scheduledDate =
        DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_gurbani_id',
      'Daily Gurbani',
      channelDescription: 'Daily notification for Gurbani quote',
      importance: Importance.max,
      priority: Priority.high,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.schedule(
      0,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidAllowWhileIdle: true,
    );
  }
}

class Quote {
  final int id;
  final String gurmukhi;
  final String transliteration;
  final String translation;

  Quote({
    required this.id,
    required this.gurmukhi,
    required this.transliteration,
    required this.translation,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'],
      gurmukhi: json['gurmukhi'],
      transliteration: json['transliteration'],
      translation: json['translation'],
    );
  }
}

class QuoteProvider {
  List<Quote> _quotes = [];

  List<Quote> get quotes => _quotes;

  Future<void> loadQuotes() async {
    final data = await rootBundle.loadString('assets/quotes.json');
    final List parsed = jsonDecode(data) as List;
    _quotes = parsed.map((e) => Quote.fromJson(e)).toList();
  }

  Quote quoteOfTheDay() {
    if (_quotes.isEmpty) {
      return Quote(
        id: 0,
        gurmukhi: 'Loading...',
        transliteration: '',
        translation: '',
      );
    }

    final day = DateTime.now().day;
    final index = day % _quotes.length;

    return _quotes[index];
  }
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final QuoteProvider _provider = QuoteProvider();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    await _provider.loadQuotes();
    final todayQuote = _provider.quoteOfTheDay();

    await NotificationService().scheduleDailyMorningNotification(
      hour: 8,
      minute: 0,
      title: 'Gurbani of the Day',
      body: todayQuote.gurmukhi,
    );

    setState(() {
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: !_loaded
          ? Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : GurbaniScreen(provider: _provider),
    );
  }
}

class GurbaniScreen extends StatelessWidget {
  final QuoteProvider provider;

  const GurbaniScreen({required this.provider});

  @override
  Widget build(BuildContext context) {
    final quote = provider.quoteOfTheDay();
    final dateStr = DateFormat.yMMMMd().format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text("Gurbani of the Day"),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              Share.share(
                "${quote.gurmukhi}\n\n${quote.translation}",
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              dateStr,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      quote.gurmukhi,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSerifGurmukhi(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    Text(
                      quote.transliteration,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 15),
                    Text(
                      quote.translation,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
