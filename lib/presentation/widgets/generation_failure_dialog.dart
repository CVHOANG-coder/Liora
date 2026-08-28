import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';

enum GenerationFailureAction {
  retry,
  buyCredits,
  renewSubscription,
  contactSupport,
  chooseImage,
  editInput,
  chooseTheme,
  close,
}

enum AppErrorVisual { credits, warning, image, account, purchase, system }

class AppErrorPresentation {
  const AppErrorPresentation({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryAction,
    required this.primaryIcon,
    required this.visual,
    this.secondaryLabel = 'Close',
    this.secondaryAction = GenerationFailureAction.close,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final GenerationFailureAction primaryAction;
  final IconData primaryIcon;
  final AppErrorVisual visual;
  final String? secondaryLabel;
  final GenerationFailureAction? secondaryAction;
}

bool isInsufficientCreditError(Object error) {
  if (error is ApiException) {
    if (error.hasCode(ApiErrorCode.insufficientCredit)) return true;
    if (error.statusCode == 402 && error.errorCode == null) return true;
  }

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
      normalized.contains('out of coin');
  if (explicitMatch) return true;

  final mentionsCredit =
      normalized.contains('credit') ||
      normalized.contains('coin') ||
      normalized.contains('balance');
  final indicatesShortage =
      normalized.contains('required') ||
      normalized.contains('requires') ||
      normalized.contains('need ') ||
      normalized.contains('needed') ||
      normalized.contains('add more') ||
      normalized.contains('too low') ||
      normalized.contains('not sufficient');
  return mentionsCredit && indicatesShortage;
}

AppErrorPresentation resolveApiErrorPresentation(
  Object error, {
  required String fallbackMessage,
}) {
  final exception = error is ApiException ? error : null;
  final code = exception?.errorCode;
  final message = apiErrorDisplayMessage(
    exception?.message,
    fallbackMessage: fallbackMessage,
  );

  switch (code) {
    case ApiErrorCode.insufficientCredit:
      return AppErrorPresentation(
        title: 'Not Enough Credits',
        message: message,
        primaryLabel: 'Buy Credits',
        primaryAction: GenerationFailureAction.buyCredits,
        primaryIcon: Icons.arrow_forward_rounded,
        visual: AppErrorVisual.credits,
        secondaryLabel: 'Maybe Later',
      );
    case ApiErrorCode.subscriptionExpired:
      return AppErrorPresentation(
        title: 'Subscription Expired',
        message: message == fallbackMessage
            ? 'Your subscription has expired. Renew it to continue creating.'
            : message,
        primaryLabel: 'Renew Plan',
        primaryAction: GenerationFailureAction.renewSubscription,
        primaryIcon: Icons.workspace_premium_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Maybe Later',
      );
    case ApiErrorCode.accountBanned:
      return AppErrorPresentation(
        title: 'Account Access Restricted',
        message: message == fallbackMessage
            ? 'This account is currently restricted. Contact support for help.'
            : message,
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.account,
      );
    case ApiErrorCode.contentPolicy:
      return AppErrorPresentation(
        title: 'Content Not Allowed',
        message: message == fallbackMessage
            ? 'This request may violate our content policy. Edit the content and try again.'
            : message,
        primaryLabel: 'Edit Content',
        primaryAction: GenerationFailureAction.editInput,
        primaryIcon: Icons.edit_rounded,
        visual: AppErrorVisual.warning,
      );
    case ApiErrorCode.fileTooLarge:
      return const AppErrorPresentation(
        title: 'Image Too Large',
        message: 'Choose another image with a maximum size of 20 MB.',
        primaryLabel: 'Choose Another Image',
        primaryAction: GenerationFailureAction.chooseImage,
        primaryIcon: Icons.photo_library_outlined,
        visual: AppErrorVisual.image,
      );
    case ApiErrorCode.unsupportedFormat:
      return const AppErrorPresentation(
        title: 'Unsupported Image Format',
        message: 'Choose a JPEG, PNG, or WebP image and try again.',
        primaryLabel: 'Choose Another Image',
        primaryAction: GenerationFailureAction.chooseImage,
        primaryIcon: Icons.photo_library_outlined,
        visual: AppErrorVisual.image,
      );
    case ApiErrorCode.promptRequired:
      return const AppErrorPresentation(
        title: 'Prompt Required',
        message: 'Enter a prompt describing the video you want to create.',
        primaryLabel: 'Add Prompt',
        primaryAction: GenerationFailureAction.editInput,
        primaryIcon: Icons.edit_rounded,
        visual: AppErrorVisual.warning,
      );
    case ApiErrorCode.imageRequired:
      return const AppErrorPresentation(
        title: 'Image Required',
        message: 'Choose a source image before creating the video.',
        primaryLabel: 'Choose Image',
        primaryAction: GenerationFailureAction.chooseImage,
        primaryIcon: Icons.add_photo_alternate_outlined,
        visual: AppErrorVisual.image,
      );
    case ApiErrorCode.imageUrlRequired:
    case ApiErrorCode.imageUrlInvalid:
      return AppErrorPresentation(
        title: code == ApiErrorCode.imageUrlRequired
            ? 'Image URL Required'
            : 'Invalid Image URL',
        message: message,
        primaryLabel: 'Review Image',
        primaryAction: GenerationFailureAction.editInput,
        primaryIcon: Icons.edit_rounded,
        visual: AppErrorVisual.image,
      );
    case ApiErrorCode.invalidAspectRatio:
      return AppErrorPresentation(
        title: 'Invalid Aspect Ratio',
        message: message,
        primaryLabel: 'Review Settings',
        primaryAction: GenerationFailureAction.editInput,
        primaryIcon: Icons.aspect_ratio_rounded,
        visual: AppErrorVisual.warning,
      );
    case ApiErrorCode.invalidPagination:
      return AppErrorPresentation(
        title: 'Unable to Load This Page',
        message: message,
        primaryLabel: 'Refresh',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.system,
      );
    case ApiErrorCode.themeRequired:
    case ApiErrorCode.themeNotFound:
      return AppErrorPresentation(
        title: code == ApiErrorCode.themeRequired
            ? 'Theme Required'
            : 'Theme Unavailable',
        message: message == fallbackMessage
            ? 'Choose another available theme and try again.'
            : message,
        primaryLabel: 'Choose Another Theme',
        primaryAction: GenerationFailureAction.chooseTheme,
        primaryIcon: Icons.auto_awesome_rounded,
        visual: AppErrorVisual.warning,
      );
    case ApiErrorCode.requestNotFound:
      return AppErrorPresentation(
        title: 'Request Not Found',
        message: message,
        primaryLabel: 'Got It',
        primaryAction: GenerationFailureAction.close,
        primaryIcon: Icons.check_rounded,
        visual: AppErrorVisual.warning,
        secondaryLabel: null,
        secondaryAction: null,
      );
    case ApiErrorCode.alreadyFinished:
      return AppErrorPresentation(
        title: 'Request Already Finished',
        message: message,
        primaryLabel: 'Got It',
        primaryAction: GenerationFailureAction.close,
        primaryIcon: Icons.check_rounded,
        visual: AppErrorVisual.warning,
        secondaryLabel: null,
        secondaryAction: null,
      );
    case ApiErrorCode.receiptInvalid:
      return AppErrorPresentation(
        title: 'Purchase Could Not Be Verified',
        message: message,
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.purchase,
      );
    case ApiErrorCode.productNotFound:
      return AppErrorPresentation(
        title: 'Product Unavailable',
        message: message,
        primaryLabel: 'Got It',
        primaryAction: GenerationFailureAction.close,
        primaryIcon: Icons.check_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: null,
        secondaryAction: null,
      );
    case ApiErrorCode.purchaseFailed:
    case ApiErrorCode.creditDeductionFailed:
      return AppErrorPresentation(
        title: code == ApiErrorCode.purchaseFailed
            ? 'Purchase Failed'
            : 'Credit Update Failed',
        message: message,
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.purchase,
      );
    case ApiErrorCode.iapDisabled:
    case ApiErrorCode.iapNotConfigured:
      return AppErrorPresentation(
        title: 'Purchases Temporarily Unavailable',
        message: message == fallbackMessage
            ? 'Purchases are not available right now. Contact support if the problem continues.'
            : message,
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.purchase,
      );
    case ApiErrorCode.uploadFailed:
    case ApiErrorCode.requestCreateFailed:
      return AppErrorPresentation(
        title: code == ApiErrorCode.uploadFailed
            ? 'Upload Failed'
            : 'Could Not Start Generation',
        message: '$message\nNo credits were deducted. It is safe to try again.',
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.system,
      );
    case ApiErrorCode.submitFailed:
      return AppErrorPresentation(
        title: 'Submission Failed',
        message:
            '$message\nYour credits were automatically refunded. It is safe to try again.',
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.system,
      );
    case ApiErrorCode.userNotFound:
    case ApiErrorCode.internalError:
      return AppErrorPresentation(
        title: code == ApiErrorCode.userNotFound
            ? 'Account Not Found'
            : 'Something Went Wrong',
        message: message,
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.system,
        secondaryLabel: 'Contact Support',
        secondaryAction: GenerationFailureAction.contactSupport,
      );
  }

  if (isInsufficientCreditError(error)) {
    return AppErrorPresentation(
      title: 'Not Enough Credits',
      message: message,
      primaryLabel: 'Buy Credits',
      primaryAction: GenerationFailureAction.buyCredits,
      primaryIcon: Icons.arrow_forward_rounded,
      visual: AppErrorVisual.credits,
      secondaryLabel: 'Maybe Later',
    );
  }

  if (exception != null &&
      exception.isUploadRequest &&
      exception.isNetworkFailure) {
    return AppErrorPresentation(
      title: 'Request Not Confirmed',
      message:
          '$message\nCheck History before generating again to avoid duplicate requests.',
      primaryLabel: 'Close',
      primaryAction: GenerationFailureAction.close,
      primaryIcon: Icons.close_rounded,
      visual: AppErrorVisual.system,
      secondaryLabel: null,
      secondaryAction: null,
    );
  }

  return AppErrorPresentation(
    title: 'Video Generation Failed',
    message: message,
    primaryLabel: 'Try Again',
    primaryAction: GenerationFailureAction.retry,
    primaryIcon: Icons.refresh_rounded,
    visual: AppErrorVisual.system,
  );
}

AppErrorPresentation resolvePurchaseErrorPresentation(
  Object error, {
  required String fallbackMessage,
}) {
  final exception = error is ApiException ? error : null;
  final code = exception?.errorCode;
  final message = apiErrorDisplayMessage(
    exception?.message,
    fallbackMessage: fallbackMessage,
  );

  switch (code) {
    case ApiErrorCode.receiptInvalid:
      return AppErrorPresentation(
        title: 'Purchase Could Not Be Verified',
        message: message == fallbackMessage
            ? 'Google Play could not verify this purchase. Please contact support before trying to buy it again.'
            : '$message\nPlease contact support before trying to buy it again.',
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Close',
      );
    case ApiErrorCode.productNotFound:
      return AppErrorPresentation(
        title: 'Purchase Option Unavailable',
        message: message == fallbackMessage
            ? 'This purchase option is not available right now. Please contact support for help.'
            : message,
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Close',
      );
    case ApiErrorCode.purchaseFailed:
      return AppErrorPresentation(
        title: 'Purchase Did Not Go Through',
        message: message == fallbackMessage
            ? 'Google Play could not complete the purchase. Please try again.'
            : message,
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Close',
      );
    case ApiErrorCode.creditDeductionFailed:
      return AppErrorPresentation(
        title: 'Credits Could Not Be Updated',
        message: message == fallbackMessage
            ? 'We could not update your credits. Try again, or contact support if Google Play already charged you.'
            : '$message\nContact support if Google Play already charged you.',
        primaryLabel: 'Try Again',
        primaryAction: GenerationFailureAction.retry,
        primaryIcon: Icons.refresh_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Contact Support',
        secondaryAction: GenerationFailureAction.contactSupport,
      );
    case ApiErrorCode.iapDisabled:
    case ApiErrorCode.iapNotConfigured:
      return const AppErrorPresentation(
        title: 'Purchases Are Unavailable',
        message:
            'Purchases are not available right now. Please contact support for help.',
        primaryLabel: 'Contact Support',
        primaryAction: GenerationFailureAction.contactSupport,
        primaryIcon: Icons.support_agent_rounded,
        visual: AppErrorVisual.purchase,
        secondaryLabel: 'Close',
      );
  }

  final normalized = message.toLowerCase();
  if (normalized.contains('product') &&
      (normalized.contains('not found') ||
          normalized.contains('unavailable') ||
          normalized.contains('not configured'))) {
    return AppErrorPresentation(
      title: 'Purchase Option Unavailable',
      message: message,
      primaryLabel: 'Contact Support',
      primaryAction: GenerationFailureAction.contactSupport,
      primaryIcon: Icons.support_agent_rounded,
      visual: AppErrorVisual.purchase,
      secondaryLabel: 'Close',
    );
  }
  if (normalized.contains('purchase token') ||
      normalized.contains('receipt') ||
      normalized.contains('could not be verified')) {
    return AppErrorPresentation(
      title: 'Purchase Could Not Be Verified',
      message:
          '$message\nPlease contact support before trying to buy it again.',
      primaryLabel: 'Contact Support',
      primaryAction: GenerationFailureAction.contactSupport,
      primaryIcon: Icons.support_agent_rounded,
      visual: AppErrorVisual.purchase,
      secondaryLabel: 'Close',
    );
  }
  if (normalized.contains('billing') && normalized.contains('unavailable')) {
    return const AppErrorPresentation(
      title: 'Google Play Is Unavailable',
      message:
          'Google Play Billing is unavailable on this device right now. Please try again later.',
      primaryLabel: 'Got It',
      primaryAction: GenerationFailureAction.close,
      primaryIcon: Icons.check_rounded,
      visual: AppErrorVisual.purchase,
      secondaryLabel: null,
      secondaryAction: null,
    );
  }
  if (normalized.contains('timed out') ||
      normalized.contains('connect') ||
      normalized.contains('network')) {
    return AppErrorPresentation(
      title: 'Connection Problem',
      message: message,
      primaryLabel: 'Try Again',
      primaryAction: GenerationFailureAction.retry,
      primaryIcon: Icons.refresh_rounded,
      visual: AppErrorVisual.purchase,
      secondaryLabel: 'Close',
    );
  }

  return AppErrorPresentation(
    title: 'Purchase Failed',
    message: message,
    primaryLabel: 'Try Again',
    primaryAction: GenerationFailureAction.retry,
    primaryIcon: Icons.refresh_rounded,
    visual: AppErrorVisual.purchase,
    secondaryLabel: 'Close',
  );
}

class GenerationFailureDialog extends StatelessWidget {
  const GenerationFailureDialog({super.key, required this.presentation});

  final AppErrorPresentation presentation;

  static Future<GenerationFailureAction?> show(
    BuildContext context, {
    required String message,
    required bool outOfCredits,
  }) {
    final presentation = outOfCredits
        ? AppErrorPresentation(
            title: 'Not Enough Credits',
            message: message,
            primaryLabel: 'Buy Credits',
            primaryAction: GenerationFailureAction.buyCredits,
            primaryIcon: Icons.arrow_forward_rounded,
            visual: AppErrorVisual.credits,
            secondaryLabel: 'Maybe Later',
          )
        : AppErrorPresentation(
            title: 'Video Generation Failed',
            message: message,
            primaryLabel: 'Try Again',
            primaryAction: GenerationFailureAction.retry,
            primaryIcon: Icons.refresh_rounded,
            visual: AppErrorVisual.system,
          );
    return showPresentation(context, presentation);
  }

  static Future<GenerationFailureAction?> showForError(
    BuildContext context, {
    required Object error,
    required String fallbackMessage,
  }) {
    return showPresentation(
      context,
      resolveApiErrorPresentation(error, fallbackMessage: fallbackMessage),
    );
  }

  static Future<GenerationFailureAction?> showForPurchaseError(
    BuildContext context, {
    required Object error,
    required String fallbackMessage,
  }) {
    return showPresentation(
      context,
      resolvePurchaseErrorPresentation(error, fallbackMessage: fallbackMessage),
    );
  }

  static Future<GenerationFailureAction?> showPresentation(
    BuildContext context,
    AppErrorPresentation presentation,
  ) {
    return showDialog<GenerationFailureAction>(
      context: context,
      barrierColor: const Color(0xD9000000),
      builder: (_) => GenerationFailureDialog(presentation: presentation),
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
              _FailureIcon(visual: presentation.visual),
              const SizedBox(height: 18),
              Text(
                presentation.title,
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
                presentation.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC4BDC8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryDialogButton(
                label: presentation.primaryLabel,
                icon: presentation.primaryIcon,
                onTap: () => Navigator.pop(context, presentation.primaryAction),
              ),
              if (presentation.secondaryLabel case final label?) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, presentation.secondaryAction),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFAAA2AF),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FailureIcon extends StatelessWidget {
  const _FailureIcon({required this.visual});

  final AppErrorVisual visual;

  @override
  Widget build(BuildContext context) {
    final icon = switch (visual) {
      AppErrorVisual.warning => Icons.gpp_maybe_outlined,
      AppErrorVisual.image => Icons.image_not_supported_outlined,
      AppErrorVisual.account => Icons.person_off_outlined,
      AppErrorVisual.purchase => Icons.receipt_long_outlined,
      AppErrorVisual.system => Icons.error_outline_rounded,
      AppErrorVisual.credits => null,
    };
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
        padding: EdgeInsets.all(visual == AppErrorVisual.credits ? 13 : 18),
        child: visual == AppErrorVisual.credits
            ? Image.asset(
                'assets/images/in_app_purchase/coin3.png',
                fit: BoxFit.contain,
              )
            : Icon(icon, color: const Color(0xFFFF58AD), size: 43),
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
