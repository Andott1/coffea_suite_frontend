import 'package:bcrypt/bcrypt.dart';

class HashingUtils {
  static String hashPassword(String password) =>
      BCrypt.hashpw(password, BCrypt.gensalt());

  static bool verifyPassword(String password, String hash) =>
      BCrypt.checkpw(password, hash);

  static String hashPin(String pin) =>
      BCrypt.hashpw(pin, BCrypt.gensalt());

  static bool verifyPin(String pin, String hash) =>
      BCrypt.checkpw(pin, hash);
}
