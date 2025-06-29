import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityAwareApp extends StatefulWidget {
  const ConnectivityAwareApp({super.key});

  @override
  _ConnectivityAwareAppState createState() => _ConnectivityAwareAppState();
}

class _ConnectivityAwareAppState extends State<ConnectivityAwareApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    // Subscribe to the connectivity stream
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      setState(() {
        // Check if there's at least one non-none result
        _hasInternet =
            results.any((result) => result != ConnectivityResult.none);
      });

      if (!_hasInternet) {
        _showNoInternetDialog();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("No Internet Connection"),
        content: const Text(
            "You cannot use the app without an internet connection."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Connectivity Aware App")),
        body: Center(
          child: Text(
            _hasInternet
                ? "Internet connection is active."
                : "No internet connection.",
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

void main() => runApp(const ConnectivityAwareApp());
