import 'package:flutter/material.dart';

import 'free_trial_screen.dart';
import 'in_app_purchase_screen.dart';

Future<void> openCreditPurchaseDestination(
  BuildContext context, {
  required bool isVIP,
}) {
  if (!isVIP) return FreeTrialScreen.open(context);
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const BuyCredits()));
}
