import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:view_selector_example2/constants.dart';
import 'package:view_selector_example2/main.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  _SetPinScreenState createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false; // To manage loading state

  Future<void> savePin(String pin) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPin', pin);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double viewInset = MediaQuery.of(context).viewInsets.bottom;
    double defaultLoginSize = size.height - (size.height * 0.2);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة رمز pin')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pin,
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
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                cursorColor: KPrimaryColor,
                decoration: const InputDecoration(
                  icon: Icon(
                    Icons.numbers,
                    color: KPrimaryColor,
                  ),
                  hintText: 'رمز ال pin',
                  border: InputBorder.none,
                ),
                validator: (value) {
                  const TextStyle(
                    fontFamily: 'NotoSansArabic',
                  );
                  if (value == null || value.isEmpty) {
                    return ' أدخل رمز ال pin';
                  }
                  return null;
                },
              ),
            ),
            _isLoading // Show loading indicator or button based on _isLoading
                ? const CircularProgressIndicator(
                    color: KPrimaryColor,
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      if (_pinController.text.isNotEmpty) {
                        setState(() {
                          _isLoading = true; // Start loading
                        });

                        // Save the pin
                        await savePin(_pinController.text);

                        // Simulate a delay for the loading indicator
                        await Future.delayed(const Duration(seconds: 2));

                        // Navigate to the next screen
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AccountStatementPage()),
                        );
                      }
                    },
                    child: Container(
                      width: size.width * 0.8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: KPrimaryColor,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      alignment: Alignment.center,
                      child: const Text(
                        'حفظ رمز ال Pin',
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
