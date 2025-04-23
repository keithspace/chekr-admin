import 'dart:convert';
import 'package:http/http.dart' as http;

class MpesaService {
  Future<bool> initiateMpesaPayment({
    required String userId,
    required String cartId,
    required String phoneNumber,
    required double amount,
    required String sessionId,
  }) async {
    try {
      var url = Uri.parse("https://server-iz6n.onrender.com/initiateMpesa");

      var body = jsonEncode({
        "cartId": cartId,
        "sessionId": sessionId,
        "userId": userId,
        "phoneNumber": phoneNumber,
        "amount": amount.toInt(), // Convert to integer if M-Pesa expects it
      });

      print("Sending Request: $body"); // Debugging log

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      print("Server Response: ${response.body}"); // Debugging log

      if (response.statusCode == 200) {
        // Check if the response indicates success
        var responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return true; // STK push initiated successfully
        } else {
          return false; // STK push failed
        }
      } else {
        return false; // HTTP request failed
      }
    } catch (e) {
      print("Error: $e");
      return false; // Exception occurred
    }
  }
}

