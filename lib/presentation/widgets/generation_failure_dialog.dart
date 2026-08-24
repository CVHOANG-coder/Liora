import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';

enum GenerationFailureAction { retry, buyCredits }

bool isInsufficientCreditError(Object error) {
  if (error is ApiException && error.statusCode == 402) return true;

  final message = error is ApiException ? error.message : error.toString();
  final normalized = message.toLowerCase();
  final explicitMatch =
      normalized.contains('insufficient credit') ||
      normalized.contains('not enough credit') ||
      normalized.contains('no credit') ||
      normalized.contains('no more credit') ||
      normalized.contains('out of credit') ||
      normalized.contains('credit exhausted') ||
      normalized.contains('insufficient balance') ||
      normalized.contains('not enough balance') ||
      normalized.contains('insufficient coin') ||
      normalized.contains('not enough coin') ||
      normalized.contains('out of coin') ||
      normalized.contains('hết credit') ||
      normalized.contains('không đủ credit') ||
      normalized.contains('hết coin') ||
      normalized.contains('không đủ coin') ||
      normalized.contains('cần thêm coin') ||
      normalized.contains('mua thêm coin') ||
      normalized.contains('không đủ số dư');
  if (explicitMatch) return true;

  final mentionsCredit =
      normalized.contains('credit') ||
      normalized.contains('coin') ||
      normalized.contains('balance') ||
      normalized.contains('số dư');
  final indicatesShortage =
      normalized.contains('required') ||
      normalized.contains('requires') ||
      normalized.contains('need ') ||
      normalized.contains('needed') ||
      normalized.contains('add more') ||
      normalized.contains('too low') ||
      normalized.contains('not sufficient') ||
      normalized.contains('không đủ') ||
      normalized.contains('cần thêm');
  return mentionsCredit && indicatesShortage;
}

class GenerationFailureDialog extends StatelessWidget {
  const GenerationFailureDialog({
    super.key,
    required this.message,
    required this.outOfCredits,
  });

  final String message;
  final bool outOfCredits;

  static Future<GenerationFailureAction?> show(
    BuildContext context, {
    required String message,
    required bool outOfCredits,
  }) {
    return showDialog<GenerationFailureAction>(
      context: context,
      barrierColor: const Color(0xD9000000),
      builder: (_) =>
          GenerationFailureDialog(message: message, outOfCredits: outOfCredits),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.all(1.3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF24B5), Color(0xFFFF4E68), Color(0xFFFF9F2B)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x77FF1BAB), blurRadius: 25),
            BoxShadow(color: Color(0x44FF8C2A), blurRadius: 20),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 25, 22, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              center: Alignment(0, -0.65),
              radius: 1.05,
              colors: [Color(0xFF251027), Color(0xFF0B060F)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FailureIcon(outOfCredits: outOfCredits),
              const SizedBox(height: 18),
              Text(
                outOfCredits ? 'Not Enough Credits' : 'Video Generation Failed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                outOfCredits
                    ? "You don't have enough credits to generate this video. "
                          'Add more credits and try again.'
                    : message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC4BDC8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryDialogButton(
                label: outOfCredits ? 'Buy Credits' : 'Try Again',
                icon: outOfCredits
                    ? Icons.arrow_forward_rounded
                    : Icons.refresh_rounded,
                onTap: () => Navigator.pop(
                  context,
                  outOfCredits
                      ? GenerationFailureAction.buyCredits
                      : GenerationFailureAction.retry,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFAAA2AF),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: Text(
                  outOfCredits ? 'Maybe Later' : 'Close',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureIcon extends StatelessWidget {
  const _FailureIcon({required this.outOfCredits});

  final bool outOfCredits;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(1.3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF24B7), Color(0xFFFF9A2E)],
        ),
        boxShadow: [BoxShadow(color: Color(0x88FF20AA), blurRadius: 20)],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF170919),
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(outOfCredits ? 13 : 18),
        child: outOfCredits
            ? Image.asset(
                'assets/images/in_app_purchase/coin3.png',
                fit: BoxFit.contain,
              )
            : const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF58AD),
                size: 43,
              ),
      ),
    );
  }
}

class _PrimaryDialogButton extends StatelessWidget {
  const _PrimaryDialogButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF16A8), Color(0xFFFF4E5C), Color(0xFFFFA42B)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x77FF1AA6), blurRadius: 15)],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(27),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
