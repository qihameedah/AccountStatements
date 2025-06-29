import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:view_selector_example2/SetPinScreen.dart';
import 'package:view_selector_example2/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isInitialized = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isConnected = true;
  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _checkConnectivity();
    // Subscribe to the connectivity change stream
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _checkConnectivity() async {
    // Check the current connectivity status
    final connectivityResults = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResults);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    setState(() {
      // Check if the results list contains only 'none' (i.e., no connectivity)
      _isConnected =
          !(results.length == 1 && results.first == ConnectivityResult.none);
    });

    if (!_isConnected) {
      _showNoInternetDialog();
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('No Internet Connection'),
          content: const Text(
              'Please check your internet connection to use the app.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _checkConnectivity(); // Retry the connectivity check
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Firebase initialization failed: ${e.toString()}')),
      );
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
          'تم تسجيل الدخول بنجاح',
          style: TextStyle(fontFamily: 'NotoSansArabic'),
        )),
      );

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const SetPinScreen()));

      // Navigate to the next screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double viewInset = MediaQuery.of(context).viewInsets.bottom;
    double defaultLoginSize = size.height - (size.height * 0.2);

    return Scaffold(
      body: _isInitialized
          ? Stack(
              children: [
                Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                        child: SizedBox(
                      width: size.width,
                      height: defaultLoginSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'مرحباً بك',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          SvgPicture.asset(
                            'assets/image.svg',
                            width: 200, // Set your desired width
                            height: 200, // Set your desired height
                          ),
                          const SizedBox(
                            height: 40,
                          ),
                          Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 5),
                                      width: size.width * 0.8,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          color: KPrimaryColor.withAlpha(50)),
                                      child: TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        cursorColor: KPrimaryColor,
                                        decoration: const InputDecoration(
                                            icon: Icon(
                                              Icons.email,
                                              color: KPrimaryColor,
                                            ),
                                            hintText: 'البريد الالكتروني',
                                            border: InputBorder.none),
                                        validator: (value) {
                                          const TextStyle(
                                            fontFamily: 'NotoSansArabic',
                                          );
                                          if (value == null || value.isEmpty) {
                                            return 'أرجوك أدخل بريدك الالكتروني';
                                          }
                                          if (!RegExp(
                                                  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                                              .hasMatch(value)) {
                                            return 'أدخل بريداً الكترونياً صالحاً';
                                          }
                                          return null;
                                        },
                                      )),
                                  Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 5),
                                      width: size.width * 0.8,
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          color: KPrimaryColor.withAlpha(50)),
                                      child: TextFormField(
                                        controller: _passwordController,
                                        cursorColor: KPrimaryColor,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                            icon: Icon(
                                              Icons.lock,
                                              color: KPrimaryColor,
                                            ),
                                            hintText: 'كلمة السر',
                                            border: InputBorder.none),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'أرجوك أدخل كلمة السر الخاصة بك';
                                          }
                                          return null;
                                        },
                                      )),
                                  _isLoading
                                      ? const CircularProgressIndicator(
                                          color: KPrimaryColor)
                                      : InkWell(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          onTap: _login,
                                          child: Container(
                                            width: size.width * 0.8,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              color: KPrimaryColor,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 20),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'تسجيل الدخول',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        )
                                ],
                              )),
                        ],
                      ),
                    ))),
              ],
            )
          // ? Container(
          //     decoration: BoxDecoration(
          //       gradient: LinearGradient(
          //         colors: [
          //           Color.fromARGB(255, 90, 65, 220),
          //           Color.fromARGB(255, 49, 24, 161),
          //         ],
          //         begin: Alignment.topLeft,
          //         end: Alignment.bottomRight,
          //       ),
          //     ),
          //     child: Center(
          //       child: SingleChildScrollView(
          //         child: Padding(
          //           padding: const EdgeInsets.symmetric(horizontal: 24.0),
          //           child: Form(
          //             key: _formKey,
          //             child: Column(
          //               mainAxisAlignment: MainAxisAlignment.center,
          //               children: [
          //                 Text(
          //                   'تسجيل الدخول',
          //                   style: TextStyle(
          //                     fontFamily: 'NotoSansArabic',
          //                     fontSize: 32,
          //                     fontWeight: FontWeight.bold,
          //                     color: Colors.white,
          //                   ),
          //                 ),
          //                 SizedBox(height: 20),
          //                 TextFormField(
          //                   controller: _emailController,
          //                   keyboardType: TextInputType.emailAddress,
          //                   decoration: InputDecoration(
          //                     hintText: 'البريد الالكتروني',
          //                     filled: true,
          //                     fillColor: Colors.white,
          //                     hintStyle:
          //                         TextStyle(fontFamily: 'NotoSansArabic'),
          //                     border: OutlineInputBorder(
          //                       borderRadius: BorderRadius.circular(12),
          //                       borderSide: BorderSide.none,
          //                     ),
          //                   ),
          //                   validator: (value) {
          //                     TextStyle(
          //                       fontFamily: 'NotoSansArabic',
          //                     );
          //                     if (value == null || value.isEmpty) {
          //                       return 'أرجوك أدخل بريدك الالكتروني';
          //                     }
          //                     if (!RegExp(
          //                             r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
          //                         .hasMatch(value)) {
          //                       return 'أدخل بريداً الكترونياً صالحاً';
          //                     }
          //                     return null;
          //                   },
          //                 ),
          //                 SizedBox(height: 20),
          //                 TextFormField(
          //                   controller: _passwordController,
          //                   obscureText: true,
          //                   decoration: InputDecoration(
          //                     hintText: 'كلمة السر',
          //                     hintStyle:
          //                         TextStyle(fontFamily: 'NotoSansArabic'),
          //                     filled: true,
          //                     fillColor: Colors.white,
          //                     border: OutlineInputBorder(
          //                       borderRadius: BorderRadius.circular(12),
          //                       borderSide: BorderSide.none,
          //                     ),
          //                   ),
          //                   validator: (value) {
          //                     if (value == null || value.isEmpty) {
          //                       return 'أرجوك أدخل كلمة السر الخاصة بك';
          //                     }
          //                     return null;
          //                   },
          //                 ),
          //                 SizedBox(height: 20),
          //                 const TextField(
          //                   cursorColor: KPrimaryColor,
          //                 ),
          //                 _isLoading
          //                     ? CircularProgressIndicator(color: Colors.white)
          //                     : ElevatedButton(
          //                         onPressed: _login,
          //                         style: ElevatedButton.styleFrom(
          //                           backgroundColor: Colors.white,
          //                           foregroundColor:
          //                               Color.fromARGB(255, 49, 24, 161),
          //                           padding: EdgeInsets.symmetric(
          //                             horizontal: 50,
          //                             vertical: 15,
          //                           ),
          //                           shape: RoundedRectangleBorder(
          //                             borderRadius: BorderRadius.circular(12),
          //                           ),
          //                         ),
          //                         child: Text(
          //                           'تسجيل الدخول',
          //                           style: TextStyle(
          //                               fontSize: 18,
          //                               fontWeight: FontWeight.bold,
          //                               fontFamily: 'NotoSansArabic'),
          //                         ),
          //                       ),
          //                 SizedBox(height: 10),
          //               ],
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
