import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import 'app_web_view_screen.dart';

class SupportContactScreen extends StatelessWidget {
  const SupportContactScreen({super.key, this.errorCode, this.errorMessage});

  final String? errorCode;
  final String? errorMessage;

  Future<void> _copyDetails(BuildContext context) async {
    final details = <String>[
      'Nostalia support request',
      if (errorCode case final code?) 'Error code: $code',
      if (errorMessage case final message?) 'Message: $message',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: details));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support details copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final hasErrorDetails = errorCode != null || errorMessage != null;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xF208060B),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Contact Support',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.75),
            radius: 1.1,
            colors: [Color(0x554B123F), AppColors.background],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            children: [
              const _SupportHero(),
              const SizedBox(height: 22),
              if (hasErrorDetails) ...[
                _ErrorDetailsCard(
                  errorCode: errorCode,
                  errorMessage: errorMessage,
                ),
                const SizedBox(height: 18),
              ],
              const _SupportInfoCard(),
              const SizedBox(height: 24),
              _GradientButton(
                label: 'Open Support Center',
                icon: Icons.support_agent_rounded,
                onTap: () => AppWebViewScreen.open(context, AppWebPage.support),
              ),
              if (hasErrorDetails) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _copyDetails(context),
                  icon: const Icon(Icons.copy_rounded, size: 19),
                  label: const Text('Copy Support Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF73C0),
                    side: const BorderSide(color: Color(0xFF7A315E)),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text(
                  'Back to App',
                  style: TextStyle(
                    color: Color(0xFFC1BAC8),
                    fontWeight: FontWeight.w700,
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

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SupportIcon(),
        SizedBox(height: 18),
        Text(
          "We're Here to Help",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Share the details below with the Nostalia support team so we can investigate quickly.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF1EB3), Color(0xFFFF9A2F)],
        ),
        boxShadow: [BoxShadow(color: Color(0x88FF20AA), blurRadius: 24)],
      ),
      child: const Icon(
        Icons.support_agent_rounded,
        color: Colors.white,
        size: 47,
      ),
    );
  }
}

class _ErrorDetailsCard extends StatelessWidget {
  const _ErrorDetailsCard({this.errorCode, this.errorMessage});

  final String? errorCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      title: 'ERROR DETAILS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorCode case final code?)
            _DetailRow(label: 'Code', value: code),
          if (errorCode != null && errorMessage != null)
            const Divider(color: AppColors.divider, height: 24),
          if (errorMessage case final message?)
            _DetailRow(label: 'Message', value: message),
        ],
      ),
    );
  }
}

class _SupportInfoCard extends StatelessWidget {
  const _SupportInfoCard();

  @override
  Widget build(BuildContext context) {
    return const _SupportCard(
      title: 'WHAT TO INCLUDE',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.tag_rounded,
            text: 'The error code and message shown by the app',
          ),
          SizedBox(height: 15),
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: 'The approximate time the issue occurred',
          ),
          SizedBox(height: 15),
          _InfoRow(
            icon: Icons.description_outlined,
            text: 'A short description of what you were trying to do',
          ),
        ],
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xB316111C),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFF42253F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF65B8), size: 22),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFD0CAD5),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
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
        boxShadow: const [BoxShadow(color: Color(0x66FF1AA6), blurRadius: 15)],
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
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
