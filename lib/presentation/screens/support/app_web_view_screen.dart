import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_features.dart';

enum AppWebPage {
  privacy(
    title: 'Privacy Policy',
    url: 'https://ai-video.giddychat.com/privacy-policy.html',
  ),
  terms(
    title: 'Terms of Service',
    url: 'https://ai-video.giddychat.com/terms-of-use',
  ),
  support(title: 'Support', url: 'https://ai-video.giddychat.com/support.html');

  const AppWebPage({required this.title, required this.url});

  final String title;
  final String url;
}

class AppWebViewScreen extends StatefulWidget {
  const AppWebViewScreen({super.key, required this.page});

  final AppWebPage page;

  static Future<void> open(BuildContext context, AppWebPage page) {
    if (!AppFeatures.externalLinksEnabled) return Future<void>.value();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => AppWebViewScreen(page: page)),
    );
  }

  @override
  State<AppWebViewScreen> createState() => _AppWebViewScreenState();
}

class _AppWebViewScreenState extends State<AppWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _hasPageError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _progress = 0;
                _hasPageError = false;
              });
            }
          },
          onPageFinished: (_) => unawaited(_refreshNavigationState()),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() => _hasPageError = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.page.url));
  }

  Future<void> _refreshNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    if (!mounted) return;
    setState(() {
      _canGoBack = canGoBack;
      _progress = 100;
    });
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _refreshNavigationState();
      return;
    }
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _reload() async {
    setState(() {
      _progress = 0;
      _hasPageError = false;
    });
    await _controller.loadRequest(Uri.parse(widget.page.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: const Color(0xF208060B),
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            key: const Key('webViewBackButton'),
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: Text(
            widget.page.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(
                key: const Key('appWebView'),
                controller: _controller,
              ),
            ),
            if (_progress < 100 && !_hasPageError)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  key: const Key('webViewProgress'),
                  value: _progress == 0 ? null : _progress / 100,
                  minHeight: 3,
                  backgroundColor: const Color(0xFF2A1024),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF35AA)),
                ),
              ),
            if (_hasPageError)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.background,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: Color(0xFFFF4CAF),
                            size: 54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to load this page',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('reloadWebViewButton'),
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try Again'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF38A8),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
