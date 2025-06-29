// main.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:view_selector_example2/Login.dart';
import 'package:view_selector_example2/SetPinScreen.dart';
import 'package:view_selector_example2/VerifyScreen.dart';
import 'package:view_selector_example2/constants.dart';
import 'dart:convert';
import 'data_table_screen.dart';
import 'dart:ui' as ui;
import 'dart:async';

// Constants

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Account Statement App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'NotoSansArabic',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: KPrimaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      locale: const Locale('ar'),
      home: const ResponsiveWrapper(child: AuthWrapper()),
    );
  }
}

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: _getSafePadding(width),
            textScaler: TextScaler.linear(_getTextScaleFactor(width)),
          ),
          child: child,
        );
      },
    );
  }

  double _getTextScaleFactor(double width) {
    if (width < 360) return 0.8;
    if (width < 600) return 1.0;
    if (width < 900) return 1.1;
    return 1.2;
  }

  EdgeInsets _getSafePadding(double width) {
    if (width < 360) return const EdgeInsets.all(8);
    if (width < 600) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KPrimaryColor, KPrimaryColorDarker],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 24),
              Text(
                'جاري التحميل...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// auth_wrapper.dart
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Timer? _backgroundTimer;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _checkConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResults);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      _isConnected =
          !(results.length == 1 && results.first == ConnectivityResult.none);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _startBackgroundTimer();
    } else if (state == AppLifecycleState.resumed) {
      _cancelBackgroundTimer();
    }
  }

  void _startBackgroundTimer() {
    _backgroundTimer = Timer(const Duration(minutes: 5), () async {
      await _clearAppData();
      _terminateApp();
    });
  }

  void _cancelBackgroundTimer() {
    _backgroundTimer?.cancel();
  }

  Future<void> _clearAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  void _terminateApp() {
    SystemNavigator.pop();
  }

  Future<bool> isPinSet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? pin = prefs.getString('userPin');
    return pin!.isNotEmpty;
  }

  Widget _buildNoConnectionScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.signal_wifi_off,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'لا يوجد اتصال بالإنترنت',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkConnectivity,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KPrimaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return _buildNoConnectionScreen();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user != null) {
            return FutureBuilder<bool>(
              future: isPinSet(),
              builder: (context, pinSnapshot) {
                if (pinSnapshot.connectionState == ConnectionState.done) {
                  return pinSnapshot.data == true
                      ? const VerifyScreen()
                      : const SetPinScreen();
                }
                return const LoadingScreen();
              },
            );
          }
          return const WelcomePage();
        }
        return const LoadingScreen();
      },
    );
  }
}

// welcome_page.dart
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _checkConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResults);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      _isConnected =
          !(results.length == 1 && results.first == ConnectivityResult.none);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return _buildNoConnectionScreen();
    }

    return Scaffold(
      backgroundColor: KPrimaryColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              _buildBackground(),
              _buildContent(constraints),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            KPrimaryColor,
            KPrimaryColorDarker.withOpacity(0.8),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BoxConstraints constraints) {
    final size = MediaQuery.of(context).size;
    final defaultLoginSize = size.height - (size.height * 0.2);

    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          width: size.width,
          height: defaultLoginSize,
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(constraints),
              const SizedBox(height: 40),
              _buildWelcomeText(constraints),
              const SizedBox(height: 40),
              _buildLoginButton(constraints),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BoxConstraints constraints) {
    final logoSize = constraints.maxWidth * 0.4;
    return SvgPicture.asset(
      'assets/logo2.svg',
      width: logoSize,
      height: logoSize,
    );
  }

  Widget _buildWelcomeText(BoxConstraints constraints) {
    final fontSize = constraints.maxWidth * 0.08;
    return Text(
      'مرحباً بك',
      style: TextStyle(
        fontSize: fontSize.clamp(24, 40),
        color: Colors.white,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BoxConstraints constraints) {
    final buttonSize = (constraints.maxWidth * 0.2).clamp(60.0, 80.0);
    return InkWell(
      borderRadius: BorderRadius.circular(buttonSize / 2),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KPrimaryColorDarker,
          boxShadow: [
            BoxShadow(
              color: KPrimaryColorDarker.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_forward,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildNoConnectionScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.signal_wifi_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد اتصال بالإنترنت',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkConnectivity,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({super.key});

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  final TextEditingController _guideNumberController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _dataRows = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _item = {};
  bool _isLoading = false;
  String? _bsnToken;
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  String? userEmail;
  bool isFirstSelected = true;
  bool searched = false;
  bool isChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    getCurrentUserEmail();
    _checkConnectivity();
    _setupConnectivity();
    _initializeDates();
  }

  void _initializeDates() {
    _fromDateController.text = DateFormat('yyyy-MM-dd')
        .format(DateTime(DateTime.now().year, DateTime.now().month, 1));
    _toDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void _setupConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _guideNumberController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchToken() async {
    const tokenUrl =
        'https://script.google.com/macros/s/AKfycby7q0QHLM9YZ8zCOGpgQGXtSPSTdtWrXJe_v5Nls1tYG2NZAws-ezDZ1U9Q1XA-sa25/exec';

    try {
      final response = await http.get(Uri.parse(tokenUrl));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['data'] != null &&
            responseData['data'] is List &&
            responseData['data'].isNotEmpty) {
          setState(() {
            _bsnToken = responseData['data'][1]['token'];
          });
        }
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء جلب رمز التوثيق');
    }
  }

  void _checkConnectivity() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResults);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      _isConnected =
          !(results.length == 1 && results.first == ConnectivityResult.none);

      if (!_isConnected) {
        _showNoInternetSnackBar();
      }
    });
  }

  void _showNoInternetSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'لا يوجد اتصال بالإنترنت',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          textColor: Colors.white,
          onPressed: _checkConnectivity,
        ),
      ),
    );
  }

  Widget _buildNoConnectionScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              KPrimaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.signal_wifi_off,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'لا يوجد اتصال بالإنترنت',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkConnectivity,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'إعادة المحاولة',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KPrimaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchContact(String number) async {
    if (_bsnToken == null) {
      await _fetchToken();
      if (_bsnToken == null) return;
    }

    final contactUrl =
        'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,salesman,salesman.name,streetAddress,taxId,phone&search=code:$number AND salesman:${userEmail?.replaceAll("@jala.ps", "")}';

    try {
      final response = await http.get(
        Uri.parse(contactUrl),
        headers: {'BSN-token': _bsnToken!},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['rows'] != null &&
            responseData['rows'] is List &&
            responseData['rows'].isNotEmpty) {
          setState(() {
            _item = responseData['rows'][0];
          });
        } else {
          _showErrorDialog('لم يتم العثور على بيانات');
        }
      } else {
        _showErrorDialog('خطأ في جلب البيانات: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء جلب البيانات');
    }
  }

  Future<void> _fetchContacts(String name) async {
    if (_bsnToken == null) {
      await _fetchToken();
      if (_bsnToken == null) return;
    }

    final contactUrl =
        'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,salesman,salesman.name&search=nameAR~$name AND salesman:${userEmail?.replaceAll("@jala.ps", "")}';

    try {
      final response = await http.get(
        Uri.parse(contactUrl),
        headers: {'BSN-token': _bsnToken!},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['rows'] != null &&
            responseData['rows'] is List &&
            responseData['rows'].isNotEmpty) {
          setState(() {
            _items = List<Map<String, dynamic>>.from(responseData['rows']);
            searched = true;
            _isLoading = false;
          });
        } else {
          _showErrorDialog('لا توجد نتائج للبحث');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء البحث');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleSubmit() async {
    if (isFirstSelected || isChecked) {
      final guideNumber = _guideNumberController.text;
      final fromDate = _fromDateController.text;
      final toDate = _toDateController.text;

      if (guideNumber.isEmpty || fromDate.isEmpty || toDate.isEmpty) {
        _showErrorDialog('يرجى تعبئة جميع الحقول');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await _fetchToken();

      // First fetch contact details
      ContactModel? contact;
      try {
        final contactUrl =
            'https://gw.bisan.com/api/v2/jalaf/contact?fields=code,nameAR,salesman,salesman.name,streetAddress,taxId,phone&search=code:$guideNumber AND salesman:${userEmail?.replaceAll("@jala.ps", "")}';

        final contactResponse = await http.get(
          Uri.parse(contactUrl),
          headers: {'BSN-token': _bsnToken!},
        );

        if (contactResponse.statusCode == 200) {
          final contactData = json.decode(contactResponse.body);
          if (contactData['rows'] != null && contactData['rows'].isNotEmpty) {
            contact = ContactModel.fromJson(contactData['rows'][0]);
          }
        }
      } catch (e) {
        _showErrorDialog('حدث خطأ أثناء جلب بيانات العميل');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (_bsnToken == null || contact == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Then fetch statement data
      final url =
          'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatement.json?search=fromDate:$fromDate,toDate:$toDate,reference:$guideNumber,currency:01,branch:00,showTotalPerAct:true,includeCashMov:true,showSettledAmounts:false,lg_status:مرحل';

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'BSN-token': _bsnToken!},
        );

        if (response.statusCode == 200) {
          final responseData = utf8.decode(response.bodyBytes);
          final jsonData = json.decode(responseData);
          if (jsonData['rows'] != null) {
            setState(() {
              _dataRows = List<Map<String, dynamic>>.from(jsonData['rows']);
              _isLoading = false;
            });

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DataTableScreen(
                  dataRows: _dataRows,
                  firstItem: contact, // Pass the contact model
                  FromDate: fromDate,
                  ToDate: toDate,
                ),
              ),
            );

            setState(() {
              searched = false;
              isChecked = false;
              isFirstSelected = true;
            });
          }
        } else {
          _showErrorDialog('خطأ في الاتصال بالخادم: ${response.statusCode}');
          setState(() {
            _isLoading = false;
          });
        }
      } catch (e) {
        _showErrorDialog('حدث خطأ أثناء الاتصال بالخادم');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSearch() async {
    final name = _nameController.text;

    if (name.isEmpty) {
      _showErrorDialog('يرجى إدخال اسم للبحث');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _fetchContacts(name);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool isDatePicker,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: KPrimaryColor.withAlpha(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: KPrimaryColor,
        ),
        child: TextField(
          controller: controller,
          textDirection: ui.TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontFamily: 'NotoSansArabic',
            fontSize: 16,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: InputBorder.none,
            labelStyle: const TextStyle(color: KPrimaryColor),
            prefixIcon: icon != null ? Icon(icon, color: KPrimaryColor) : null,
          ),
          readOnly: isDatePicker,
          onTap: isDatePicker ? () => _selectDate(context, controller) : null,
        ),
      ),
    );
  }

  void _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: KPrimaryColor,
            colorScheme: const ColorScheme.light(
              primary: KPrimaryColor,
              onPrimary: Colors.white,
            ),
            textTheme: Theme.of(context).textTheme.apply(
                  fontFamily: 'NotoSansArabic',
                ),
            primaryTextTheme: Theme.of(context).primaryTextTheme.apply(
                  fontFamily: 'NotoSansArabic',
                ),
            // This specifically targets the date picker
            datePickerTheme: const DatePickerThemeData(
              headerBackgroundColor: KPrimaryColor,
              headerForegroundColor: Colors.white, // Text color in the header
            ),
          ),
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'خطأ',
          textAlign: TextAlign.right,
          style: TextStyle(color: KPrimaryColor),
        ),
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(color: KPrimaryColor),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return _buildNoConnectionScreen();
    }

    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'كشف حساب',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: KPrimaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white, // Set the drawer icon color to white
        ),
      ),
      drawer: _buildDrawer(),
      body: _buildBody(size),
    );
  }

  // Continuing from previous AccountStatementPage class

  Widget _buildBody(Size size) {
    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(size),
            Expanded(
              child: _buildContent(size),
            ),
          ],
        ),
        if (_isLoading) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildHeader(Size size) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: KPrimaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          SvgPicture.asset(
            'assets/logo2.svg',
            width: size.width * 0.25,
            height: size.width * 0.25,
          ),
          const SizedBox(height: 16),
          Text(
            'كشف حساب الزبائن',
            style: TextStyle(
              fontSize: size.width * 0.06,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildContent(Size size) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          children: [
            _buildSearchTypeToggle(size),
            const SizedBox(height: 20),
            _buildSearchFields(size),
            const SizedBox(height: 20),
            _buildActionButton(size),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTypeToggle(Size size) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: size.height * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToggleButton(
            text: 'من خلال رقم الدليل',
            isSelected: isFirstSelected,
            onTap: () => _handleButtonClick(true),
            size: size,
          ),
          _buildToggleButton(
            text: 'من خلال الاسم',
            isSelected: !isFirstSelected,
            onTap: () => _handleButtonClick(false),
            size: size,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    required Size size,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: size.width * 0.4,
        padding: EdgeInsets.symmetric(
          vertical: size.height * 0.015,
          horizontal: size.width * 0.03,
        ),
        decoration: BoxDecoration(
          color: isSelected ? KPrimaryColor : KPrimaryColor.withAlpha(50),
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: KPrimaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : KPrimaryColor,
            fontSize: size.width * 0.035,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFields(Size size) {
    if (!isFirstSelected && !searched) {
      return _buildInputField(
        controller: _nameController,
        label: 'اسم الدليل',
        hintText: 'أدخل اسم الدليل الذي تبحث عنه',
        isDatePicker: false,
        icon: Icons.person,
      );
    }

    if (isFirstSelected || isChecked) {
      return Column(
        children: [
          // If it's a result from the search by name, add a back button header
          if (isChecked && !isFirstSelected)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.person,
                    color: KPrimaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'البحث بالاسم',
                    style: TextStyle(
                      color: KPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: size.width * 0.04,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        isChecked = false;
                        _guideNumberController.clear();
                        searched = true; // Keep showing the search results
                      });
                    },
                    icon: Icon(
                      Icons.arrow_forward,
                      color: KPrimaryColor,
                      size: size.width * 0.04,
                    ),
                    label: Text(
                      'الرجوع',
                      style: TextStyle(
                        color: KPrimaryColor,
                        fontSize: size.width * 0.035,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildInputField(
            controller: _guideNumberController,
            label: 'رقم الدليل',
            hintText: 'أدخل رقم الدليل',
            isDatePicker: false,
            icon: Icons.numbers,
          ),
          _buildInputField(
            controller: _fromDateController,
            label: 'من تاريخ',
            hintText: 'اختر التاريخ',
            isDatePicker: true,
            icon: Icons.calendar_today,
          ),
          _buildInputField(
            controller: _toDateController,
            label: 'إلى تاريخ',
            hintText: 'اختر التاريخ',
            isDatePicker: true,
            icon: Icons.calendar_today,
          ),
        ],
      );
    }

    if (!isFirstSelected && searched && !isChecked) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.05,
                vertical: 8,
              ),
              child: Row(
                textDirection: ui.TextDirection.rtl,
                children: [
                  Text(
                    'نتائج البحث (${_items.length})',
                    textDirection: ui.TextDirection.rtl,
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.bold,
                      color: KPrimaryColor,
                      fontFamily: 'NotoSansArabic',
                    ),
                  ),
                  const Spacer(),
                  // Back button to reset search
                  IconButton(
                    icon: Icon(
                      Icons.arrow_forward,
                      color: KPrimaryColor,
                      size: size.width * 0.05,
                    ),
                    onPressed: () {
                      setState(() {
                        searched = false;
                        _nameController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            const Divider(thickness: 1),
            ..._items.map((row) => _buildSearchResultItem(row, size)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSearchResultItem(Map<String, dynamic> row, Size size) {
    // Decode the Arabic text properly
    String nameAR = _decodeArabicText(row['nameAR'] ?? '');
    String code = row['code']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Material(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              isChecked = true;
              _guideNumberController.text = code;
            });
          },
          splashColor: KPrimaryColor.withOpacity(0.1),
          highlightColor: KPrimaryColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              textDirection: ui.TextDirection.rtl,
              children: [
                // Left side with primary indicator
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: KPrimaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 16),

                // Contact icon with circle background
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: KPrimaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // Content - name and code
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: ui.TextDirection.rtl,
                    children: [
                      Row(
                        textDirection: ui.TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Text(
                              nameAR,
                              textDirection: ui.TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'NotoSansArabic',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: KPrimaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          code,
                          style: const TextStyle(
                            fontSize: 13,
                            color: KPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action indicator
                Icon(
                  Icons.chevron_left,
                  color: Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Add this helper method to your class
  String _decodeArabicText(String text) {
    try {
      // First try to decode if it's a UTF-8 encoded string
      return utf8.decode(text.runes.toList());
    } catch (e) {
      try {
        // If that fails, try to decode from JSON string if it's escaped
        return json.decode('"$text"');
      } catch (e) {
        // If both fail, return the original text
        return text;
      }
    }
  }

  Widget _buildActionButton(Size size) {
    if (!isFirstSelected && !searched) {
      return _buildCustomButton(
        text: 'بحث',
        onTap: _handleSearch,
        size: size,
      );
    }

    if (isFirstSelected || isChecked) {
      return _buildCustomButton(
        text: 'موافق',
        onTap: _handleSubmit,
        size: size,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCustomButton({
    required String text,
    required VoidCallback onTap,
    required Size size,
  }) {
    return Container(
      margin: EdgeInsets.only(top: size.height * 0.02),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(30),
        color: KPrimaryColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Container(
            width: size.width * 0.8,
            padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: size.width * 0.045,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(KPrimaryColor),
                ),
                SizedBox(height: 16),
                Text(
                  'جاري التحميل...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: KPrimaryColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userEmail ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: KPrimaryColor),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(fontSize: 16),
              ),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('userPin');
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء تسجيل الخروج');
    }
  }

  void getCurrentUserEmail() {
    User? user = FirebaseAuth.instance.currentUser;
    setState(() {
      userEmail = user?.email;
    });
  }

  void _handleButtonClick(bool isFirst) {
    setState(() {
      isFirstSelected = isFirst;
      if (isFirst) {
        searched = false;
        isChecked = false;
      }
    });
  }
}

class ContactModel {
  final String code;
  final String nameAR;
  final String salesman;
  final String salesmanName;
  final String streetAddress;
  final String taxId;
  final String phone;

  ContactModel({
    required this.code,
    required this.nameAR,
    required this.salesman,
    required this.salesmanName,
    required this.streetAddress,
    required this.taxId,
    required this.phone,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    // Helper function to decode Arabic text
    String decodeText(dynamic text) {
      if (text == null) return '';
      try {
        // First try UTF-8 decoding
        return utf8.decode(text.toString().codeUnits);
      } catch (e) {
        return text.toString();
      }
    }

    return ContactModel(
      code: json['code']?.toString() ?? '',
      nameAR: decodeText(json['nameAR']),
      salesman: json['salesman']?.toString() ?? '',
      salesmanName: decodeText(json['salesman.name']),
      streetAddress: decodeText(json['streetAddress']),
      taxId: json['taxId']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}
