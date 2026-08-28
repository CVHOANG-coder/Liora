import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import 'all_plans_screen.dart';
import 'free_trial_screen.dart';
import 'in_app_purchase_screen.dart';

Future<bool> openCreditPurchaseDestination(
  BuildContext context, {
  required bool isSubscribed,
  required bool isVIP,
  required Object error,
}) async {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          apiErrorDisplayMessage(
            error,
            fallbackMessage: 'Not enough credits to generate this video.',
          ),
        ),
      ),
    );
  if (!isSubscribed && !isVIP) {
    return await FreeTrialScreen.open(context, returnPurchaseResult: true) ??
        false;
  }
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => isSubscribed
              ? const BuyCredits(returnPurchaseResult: true)
              : const AllPlans(returnPurchaseResult: true),
        ),
      ) ??
      false;
}
