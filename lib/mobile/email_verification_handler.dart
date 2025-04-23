import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationHandler {
  static Future<void> handleEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if email was recently verified
      await user.reload();
      if (user.emailVerified) {
        // Update Firestore to mark email as verified
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}