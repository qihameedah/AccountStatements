import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:view_selector_example2/constants.dart';
import 'package:view_selector_example2/main.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  _VerifyScreenState createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController pinController = TextEditingController();
  bool _isLoading = false; // To handle loading state

  Future<bool> verifyPin(String enteredPin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPin = prefs.getString('userPin');
    return savedPin == enteredPin;
  }

  void handlePinVerification() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    String enteredPin = pinController.text;
    if (enteredPin.isEmpty) {
      setState(() {
        _isLoading = false; // Stop loading when PIN is empty
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رمز ال Pin')),
      );
      return;
    }

    bool isPinCorrect = await verifyPin(enteredPin);

    setState(() {
      _isLoading = false; // Stop loading after verification
    });

    if (isPinCorrect) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AccountStatementPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رمز Pin خاطئ ، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من رمز الPin')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 250.0, // Set the size of the icon
              color: KPrimaryColor, // You can change the color as well
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              width: size.width * 0.8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: KPrimaryColor.withAlpha(50),
              ),
              child: TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                cursorColor: KPrimaryColor,
                decoration: const InputDecoration(
                  icon: Icon(
                    Icons.numbers,
                    color: KPrimaryColor,
                  ),
                  hintText: 'أدخل رمز ال Pin الخاص بك',
                  border: InputBorder.none,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'أدخل الرمز';
                  }
                  return null;
                },
              ),
            ),
            // Check if the loading state is true or false
            _isLoading
                ? Container(
                    width: size.width * 0.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: KPrimaryColor,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: handlePinVerification,
                    child: Container(
                      width: size.width * 0.8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: KPrimaryColor,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: const Text(
                        'التحقق من رمز ال Pin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
