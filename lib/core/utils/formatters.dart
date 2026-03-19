import 'package:intl/intl.dart';

String formatDateTime(DateTime value) {
  return DateFormat('M月d日 HH:mm').format(value.toLocal());
}

String formatDate(DateTime value) {
  return DateFormat('yyyy年M月d日').format(value.toLocal());
}

String formatIngredientAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toInt().toString();
  }
  return amount.toStringAsFixed(1);
}
