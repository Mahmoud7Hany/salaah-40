// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';

class PrayerChallenge extends StatefulWidget {
  const PrayerChallenge({super.key});

  @override
  _PrayerChallengeState createState() => _PrayerChallengeState();
}

class _PrayerChallengeState extends State<PrayerChallenge> {
  late SharedPreferences _prefs;
  DateTime? _startDate;
  int _currentStreak = 0;
  List<bool> _todayPrayers = List.generate(5, (_) => false);
  final List<String> _prayerNames = [
    'الفجر',
    'الظهر',
    'العصر',
    'المغرب',
    'العشاء'
  ];
  bool _hasStarted = false;
  bool _dailyCompleted = false;
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  bool _showCelebration = false;
  String _celebrationMessage = '';
  final List<int> _celebrationDays = [7, 14, 21, 28, 35, 40];

  // المتغيرات الخاصة بالعد التنازلي
  late DateTime _nextResetTime;
  Duration _timeRemaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _startTimer();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // بدء المؤقت الذي يحدث كل ثانية لتحديث العد التنازلي
  void _startTimer() {
    _updateNextResetTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining = _nextResetTime.difference(DateTime.now());
        // إذا انتهى اليوم (أي الوقت سالب) يتم إعادة التعيين
        if (_timeRemaining.isNegative) {
          _dailyCompleted = false;
          _todayPrayers = List.generate(5, (_) => false);
          _prefs.remove('todayPrayers');
          _prefs.remove('lastPrayerDate');
          _updateNextResetTime();
        }
      });
    });
  }

  // تحديث الوقت الذي ينتهي فيه اليوم الحالي (عادة عند منتصف الليل)
  void _updateNextResetTime() {
    final now = DateTime.now();
    _nextResetTime =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadData();
  }

  void _loadData() {
    try {
      final startDateString = _prefs.getString('startDate');
      final lastPrayerDateString = _prefs.getString('lastPrayerDate');

      setState(() {
        _startDate =
            startDateString != null ? DateTime.parse(startDateString) : null;
        _currentStreak = _prefs.getInt('streak') ?? 0;
        _todayPrayers = _prefs
                .getStringList('todayPrayers')
                ?.map((e) => e == '1')
                .toList() ??
            List.generate(5, (_) => false);
        _hasStarted = _startDate != null;
      });

      // التحقق مما إذا كان تاريخ آخر صلوات هو نفس اليوم
      if (lastPrayerDateString != null) {
        DateTime lastPrayerDate = DateTime.parse(lastPrayerDateString);
        final now = DateTime.now();
        if (lastPrayerDate.year == now.year &&
            lastPrayerDate.month == now.month &&
            lastPrayerDate.day == now.day) {
          // إذا كانت جميع الصلوات مسجلة، نعبر عن انتهاء اليوم
          setState(() {
            _dailyCompleted = _todayPrayers.every((p) => p);
          });
        } else {
          // إذا لم يكن التاريخ هو نفسه، نعيد تعيين حالة الصلوات
          setState(() {
            _todayPrayers = List.generate(5, (_) => false);
            _dailyCompleted = false;
          });
          _prefs.remove('todayPrayers');
          _prefs.remove('lastPrayerDate');
        }
      } else {
        // في حالة عدم وجود سجل، نحفظ تاريخ اليوم كبداية
        _prefs.setString('lastPrayerDate', DateTime.now().toString());
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading data: $e');
    }
  }

  Future<void> _startChallenge() async {
    final today = DateTime.now();
    await _prefs.setString('startDate', today.toString());
    await _prefs.setInt('streak', 1);
    await _prefs.setString('lastPrayerDate', today.toString());
    await _savePrayers();

    setState(() {
      _startDate = today;
      _currentStreak = 1;
      _hasStarted = true;
    });
  }

  Future<void> _updatePrayer(int index) async {
    // إذا اليوم انتهى فلن يتم السماح بتحديث الصلوات
    if (_dailyCompleted) return;

    setState(() {
      _todayPrayers[index] = !_todayPrayers[index];
    });
    await _savePrayers();
    await _checkDayCompletion();
  }

  Future<void> _checkDayCompletion() async {
    if (_todayPrayers.every((prayed) => prayed)) {
      setState(() {
        _currentStreak++;
        _dailyCompleted = true;
      });
      await _prefs.setInt('streak', _currentStreak);
      // حفظ تاريخ اليوم عند الانتهاء من الصلوات
      await _prefs.setString('lastPrayerDate', DateTime.now().toString());
      await _checkCelebration();
      // لن نقوم بإعادة تعيين الصلوات فورًا حتى يبدأ يوم جديد
    }
  }

  Future<void> _checkCelebration() async {
    if (_celebrationDays.contains(_currentStreak)) {
      setState(() {
        _showCelebration = true;
        _celebrationMessage = _getCelebrationMessage();
      });
      _confettiController.play();

      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _showCelebration = false;
      });
    }
  }

  String _getCelebrationMessage() {
    return switch (_currentStreak) {
      7 => 'أسبوع كامل! استمر في التحدي 💪',
      14 => 'أسبوعين من الانتظام! ممتاز 🌟',
      21 => '3 أسابيع! أنت مذهل 🚀',
      28 => 'أربع أسابيع! تفوق رائع 🏆',
      35 => '35 يومًا! اقتربت من النهاية 🔥',
      40 => 'مبارك! أكملت التحدي بنجاح 🎉',
      _ => '',
    };
  }

  Future<void> _savePrayers() async {
    await _prefs.setStringList(
      'todayPrayers',
      _todayPrayers.map((p) => p ? '1' : '0').toList(),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  DateTime? get _endDate => _startDate?.add(const Duration(days: 40));

  Future<void> _resetChallenge() async {
    await _prefs.clear();
    setState(() {
      _startDate = null;
      _currentStreak = 0;
      _todayPrayers = List.generate(5, (_) => false);
      _hasStarted = false;
      _dailyCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('تحدي الـ 40 يومًا'),
            actions: [
              if (_hasStarted)
                IconButton(
                  icon: const Icon(Icons.restart_alt),
                  onPressed: _resetChallenge,
                  tooltip: 'إعادة البدء',
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDateCard(),
                const SizedBox(height: 30),
                if (!_hasStarted) _buildStartButton(),
                if (_hasStarted) ...[
                  _buildProgress(),
                  const SizedBox(height: 30),
                  // إذا انتهى أداء الصلوات في اليوم، إظهار العد التنازلي، وإلا إظهار شبكة الصلوات
                  _dailyCompleted
                      ? _buildCountdownWidget()
                      : _buildPrayersGrid(),
                ],
              ],
            ),
          ),
        ),
        if (_showCelebration)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: -1.0,
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    maxBlastForce: 20,
                    minBlastForce: 15,
                    gravity: 0.3,
                  ),
                  Text(
                    _celebrationMessage,
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Icon(Icons.celebration, size: 80, color: Colors.amber),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDateItem(
              icon: Icons.calendar_today,
              label: 'تاريخ البدء',
              date: _startDate != null ? _formatDate(_startDate!) : '--/--/--',
            ),
            Container(
              width: 1,
              height: 60,
              color: Colors.grey[300],
            ),
            _buildDateItem(
              icon: Icons.flag,
              label: 'تاريخ الانتهاء',
              date: _endDate != null ? _formatDate(_endDate!) : '--/--/--',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(
      {required IconData icon, required String label, required String date}) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blue),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 5),
        Text(date,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStartButton() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'اضغط لبدء التحدي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FloatingActionButton.large(
              onPressed: _startChallenge,
              child: const Icon(Icons.play_arrow, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      children: [
        Text(
          'اليوم $_currentStreak من 40',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: _currentStreak / 40,
          backgroundColor: Colors.grey[300],
          minHeight: 15,
          borderRadius: BorderRadius.circular(10),
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildPrayersGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.3,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        return PrayerButton(
          prayed: _todayPrayers[index],
          prayerName: _prayerNames[index],
          onPressed: () => _updatePrayer(index),
        );
      },
    );
  }

  Widget _buildCountdownWidget() {
    final hours =
        _timeRemaining.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes =
        _timeRemaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _timeRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'لقد أنهيت صلوات اليوم',
            style: GoogleFonts.tajawal(
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'الوقت المتبقي لبداية اليوم الجديد:',
            style: GoogleFonts.tajawal(
              textStyle: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$hours:$minutes:$seconds',
            style: GoogleFonts.tajawal(
              textStyle: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrayerButton extends StatelessWidget {
  final bool prayed;
  final String prayerName;
  final VoidCallback onPressed;

  const PrayerButton({
    super.key,
    required this.prayed,
    required this.prayerName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: prayed ? Colors.green : Colors.blue[100],
        foregroundColor: prayed ? Colors.white : Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        elevation: 3,
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(prayed ? Icons.check_circle : Icons.access_time, size: 30),
          const SizedBox(height: 8),
          Text(
            prayerName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: prayed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
