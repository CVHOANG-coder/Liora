import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_features.dart';
import '../../../core/events/video_generation_events.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/generation_history.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/cached_video_thumbnail.dart';
import '../../widgets/video_form_style.dart';
import '../../widgets/video_library_widgets.dart';
import '../image_to_video/creating_video_screen.dart';
import '../image_to_video/generated_video_screen.dart';
import '../image_to_video/image_to_video_screen.dart';
import '../in_app_purchase/all_plans_screen.dart';
import '../in_app_purchase/free_trial_screen.dart';
import '../in_app_purchase/in_app_purchase_screen.dart';
import '../settings/settings_screen.dart';

typedef ProfileHistoryPageFetcher =
    Future<GenerationHistoryPage> Function({
      required int page,
      required int limit,
    });
typedef ProfileVideoDeleter = Future<void> Function(String requestId);

final profileHistoryPageFetcherProvider = Provider<ProfileHistoryPageFetcher>(
  (ref) =>
      ({required page, required limit}) =>
          ApiClient.instance.fetchGenerationHistory(page: page, limit: limit),
);

final profileVideoHistoryProvider = FutureProvider<GenerationHistoryPage>(
  (ref) => ref.read(profileHistoryPageFetcherProvider)(page: 1, limit: 10),
);

final profileVideoDeleterProvider = Provider<ProfileVideoDeleter>(
  (ref) => ApiClient.instance.deleteGenerationRequest,
);

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version.trim();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  StreamSubscription<String>? _generationSuccessSubscription;
  final ScrollController _scrollController = ScrollController();
  GenerationHistoryPage? _firstHistoryPage;
  final List<I2VRequestStatus> _additionalRequests = [];
  int _loadedPage = 0;
  int _totalPages = 1;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _isSelectingVideos = false;
  bool _isDeletingSelectedVideos = false;
  final Set<String> _selectedRequestIds = <String>{};
  final Set<String> _deletedRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleHistoryScroll);
    _generationSuccessSubscription = VideoGenerationEvents.successes.listen(
      (_) => ref.invalidate(profileVideoHistoryProvider),
    );
  }

  @override
  void dispose() {
    _generationSuccessSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleHistoryScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) _loadMoreHistory();
  }

  void _checkHistoryAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleHistoryScroll();
    });
  }

  Future<void> _loadMoreHistory() async {
    final firstPage = _firstHistoryPage;
    if (firstPage == null ||
        ref.read(profileVideoHistoryProvider).isLoading ||
        _loadingMore ||
        _loadMoreFailed ||
        _loadedPage >= _totalPages) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final nextPageNumber = _loadedPage + 1;
      final nextPage = await ref.read(profileHistoryPageFetcherProvider)(
        page: nextPageNumber,
        limit: 10,
      );
      if (!mounted || !identical(_firstHistoryPage, firstPage)) return;
      setState(() {
        final existingIds = {
          ...firstPage.requests.map((request) => request.requestId),
          ..._additionalRequests.map((request) => request.requestId),
        };
        _additionalRequests.addAll(
          nextPage.requests.where(
            (request) => existingIds.add(request.requestId),
          ),
        );
        _loadedPage = nextPageNumber;
        _totalPages = nextPage.pagination.totalPages;
      });
      _checkHistoryAfterLayout();
    } catch (_) {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
        _checkHistoryAfterLayout();
      }
    }
  }

  Future<void> _openHistoryRequest(I2VRequestStatus request) async {
    Widget? destination;
    if (request.isCompleted && request.resultUrl.isNotEmpty) {
      destination = GeneratedVideoScreen(
        result: request,
        returnToPreviousOnBack: true,
      );
    } else if (request.isActive) {
      const repository = SharedPreferencesGenerationProgressRepository();
      GenerationProgress? progress;
      try {
        progress = await repository.load(request.requestId);
      } catch (_) {
        // The request can still open with progress rebuilt from the server.
      }
      progress ??= GenerationProgress.create(
        requestId: request.requestId,
        startedAt: request.createTime ?? DateTime.now(),
        videoDurationSeconds: request.duration > 0 ? request.duration : 5,
        isHd: request.isHd,
      );
      if (!mounted) return;
      destination = CreatingVideoScreen(
        generation: I2VGeneration.fromRequestStatus(request),
        returnToPreviousOnBack: true,
        initialProgress: progress,
        progressRepository: repository,
        openedFromHistory: true,
      );
    }
    if (destination == null || !mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination!));
    if (mounted) await _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    try {
      final refreshed = ref.refresh(profileVideoHistoryProvider.future);
      await refreshed;
    } catch (_) {
      // The provider displays its error state and offers a retry action.
    }
  }

  void _startVideoSelection(String requestId) {
    if (_isDeletingSelectedVideos) return;
    setState(() {
      _isSelectingVideos = true;
      _selectedRequestIds.add(requestId);
    });
  }

  void _toggleVideoSelection(String requestId) {
    if (_isDeletingSelectedVideos) return;
    setState(() {
      if (!_selectedRequestIds.add(requestId)) {
        _selectedRequestIds.remove(requestId);
      }
    });
  }

  void _cancelVideoSelection() {
    if (_isDeletingSelectedVideos) return;
    setState(() {
      _isSelectingVideos = false;
      _selectedRequestIds.clear();
    });
  }

  Future<void> _deleteSelectedVideos() async {
    if (_isDeletingSelectedVideos || _selectedRequestIds.isEmpty) return;
    final requestIds = _selectedRequestIds.toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (_) => _DeleteSelectedVideosDialog(count: requestIds.length),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingSelectedVideos = true);
    final deleted = <String>[];
    final deleter = ref.read(profileVideoDeleterProvider);
    for (final requestId in requestIds) {
      try {
        await deleter(requestId);
        deleted.add(requestId);
        try {
          await const SharedPreferencesGenerationProgressRepository().remove(
            requestId,
          );
        } catch (_) {
          // Server deletion succeeded; local progress cleanup is best-effort.
        }
      } catch (_) {
        // Keep failed requests selected so the user can retry them.
      }
    }
    if (!mounted) return;
    final failedCount = requestIds.length - deleted.length;
    setState(() {
      _isDeletingSelectedVideos = false;
      _deletedRequestIds.addAll(deleted);
      _selectedRequestIds.removeAll(deleted);
      _additionalRequests.removeWhere(
        (request) => _deletedRequestIds.contains(request.requestId),
      );
      if (failedCount == 0) _isSelectingVideos = false;
    });
    if (deleted.isNotEmpty && failedCount == 0) {
      ref.invalidate(profileVideoHistoryProvider);
    }
    if (Scaffold.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedCount == 0
                ? '${deleted.length} video${deleted.length == 1 ? '' : 's'} deleted.'
                : '${deleted.length} deleted, $failedCount could not be deleted. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final videoHistory = ref.watch(profileVideoHistoryProvider);
    final firstPage = videoHistory.asData?.value;
    if (firstPage != null && !identical(_firstHistoryPage, firstPage)) {
      _firstHistoryPage = firstPage;
      _additionalRequests.clear();
      _loadedPage = firstPage.pagination.page;
      _totalPages = firstPage.pagination.totalPages;
      _loadMoreFailed = false;
      _checkHistoryAfterLayout();
    }
    final requests = firstPage == null
        ? const <I2VRequestStatus>[]
        : <I2VRequestStatus>[...firstPage.requests, ..._additionalRequests]
              .where(
                (request) => !_deletedRequestIds.contains(request.requestId),
              )
              .toList();

    return ColoredBox(
      color: const Color(0xFF292431),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep the reference proportions on phones, without enlarging
            // every element indefinitely on wider screens.
            final scale = (constraints.maxWidth / 393).clamp(0.8, 1.3);
            return Column(
              children: [
                _ProfileHeader(
                  scale: scale,
                  isSelecting: _isSelectingVideos,
                  selectedCount: _selectedRequestIds.length,
                  isDeleting: _isDeletingSelectedVideos,
                  onCancelSelection: _cancelVideoSelection,
                  onDeleteSelected: _deleteSelectedVideos,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshHistory,
                    color: VideoFormStyle.accent,
                    backgroundColor: const Color(0xFF342D3E),
                    child: CustomScrollView(
                      key: const PageStorageKey('profileScroll'),
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            14 * scale,
                            8 * scale,
                            14 * scale,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              if (AppFeatures.commerceEnabled)
                                SliverToBoxAdapter(
                                  child: _UpgradeCard(
                                    profile: profile,
                                    scale: scale,
                                  ),
                                ),
                              if (AppFeatures.commerceEnabled)
                                SliverToBoxAdapter(
                                  child: SizedBox(height: 14 * scale),
                                ),
                              _ProfileVideoHistory(
                                history: videoHistory,
                                requests: requests,
                                scale: scale,
                                loadingMore: _loadingMore,
                                loadMoreFailed: _loadMoreFailed,
                                onRefresh: () =>
                                    ref.invalidate(profileVideoHistoryProvider),
                                onRetryMore: () {
                                  setState(() => _loadMoreFailed = false);
                                  _loadMoreHistory();
                                },
                                onOpen: _openHistoryRequest,
                                isSelecting: _isSelectingVideos,
                                selectedRequestIds: _selectedRequestIds,
                                onLongPress: _startVideoSelection,
                                onToggleSelection: _toggleVideoSelection,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

const _profileSurface = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF40364C), Color(0xFF342D3E)],
);

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.scale,
    required this.isSelecting,
    required this.selectedCount,
    required this.isDeleting,
    required this.onCancelSelection,
    required this.onDeleteSelected,
  });

  final double scale;
  final bool isSelecting;
  final int selectedCount;
  final bool isDeleting;
  final VoidCallback onCancelSelection;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('profileHeader'),
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        16 * scale,
        16 * scale,
        0 * scale,
      ),
      child: Row(
        crossAxisAlignment: isSelecting
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (isSelecting)
            IconButton(
              key: const Key('cancelProfileVideoSelection'),
              tooltip: 'Cancel selection',
              onPressed: isDeleting ? null : onCancelSelection,
              icon: const Icon(Icons.close_rounded, color: Color(0xFFD88AF0)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSelecting ? '$selectedCount selected' : 'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Nunito',
                    fontFamilyFallback: const ['Nunito Sans'],
                    fontSize: isSelecting ? 22 * scale : 32 * scale,
                    height: 1.1,
                    fontWeight: isSelecting ? FontWeight.w500 : FontWeight.w800,
                    letterSpacing: -0.8 * scale,
                  ),
                ),
                if (!isSelecting)
                  Container(
                    width: 26 * scale,
                    height: 2.5 * scale,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA45CF4), Color(0xFFA45CF4)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: isSelecting ? 0 : 3 * scale),
            child: isSelecting
                ? IconButton(
                    key: const Key('profileDeleteSelectedButton'),
                    tooltip: 'Delete selected videos',
                    onPressed: selectedCount == 0 || isDeleting
                        ? null
                        : onDeleteSelected,
                    icon: isDeleting
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : VideoLibraryTrashIcon(
                            color: selectedCount == 0
                                ? VideoFormStyle.muted
                                : const Color(0xFFE49AAA),
                            size: 28 * scale,
                          ),
                  )
                : IconButton(
                    key: const Key('profileSettingsButton'),
                    tooltip: 'Settings',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: SvgPicture.asset(
                      'assets/svgs/setting.svg',
                      width: 28 * scale,
                      height: 28 * scale,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFD88AF0),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.profile, required this.scale});

  final UserProfile? profile;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profileCreditCard'),
      constraints: BoxConstraints(minHeight: 152 * scale),
      padding: const EdgeInsets.all(0.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAE72B4), Color(0xFF343343), Color(0xFF1A2232)],
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * scale - 0.6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241A33), Color(0xFF342D3E), Color(0xFF342D3E)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14 * scale,
            vertical: 16 * scale,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Image.asset(
                  'assets/images/profile/balance_credit.png',
                  height: 110 * scale,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                ),
              ),
              SizedBox(width: 5 * scale),
              Container(
                key: const Key('profileCreditDivider'),
                width: 1 * scale,
                height: 92 * scale,
                decoration: BoxDecoration(
                  color: const Color(0xFF79668A),
                  borderRadius: BorderRadius.circular(scale),
                ),
              ),
              SizedBox(width: 6 * scale),
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 4 * scale),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CREDIT BALANCE',
                          style: TextStyle(
                            color: const Color(0xFFB188D1),
                            fontSize: 11.5 * scale,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5 * scale,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 14 * scale),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Text(
                            _formatCredits(profile?.totalCredit ?? 0),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32 * scale,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 7 * scale),
                          Image.asset(
                            'assets/images/profile/icon_credit_balance.png',
                            width: 40 * scale,
                            height: 28 * scale,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    _CreditActionButton(
                      scale: scale,
                      label: profile?.isSubscribed == true
                          ? 'Buy More Credits'
                          : 'Upgrade to Pro',
                      onTap: profile?.isSubscribed == true
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BuyCredits(),
                              ),
                            )
                          : () {
                              if (profile?.isVIP == false) {
                                FreeTrialScreen.open(context);
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const AllPlans(),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditActionButton extends StatelessWidget {
  const _CreditActionButton({
    required this.label,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profileCreditActionButton'),
      height: 39 * scale,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(color: const Color(0xFF8C5ACF), width: 0.5),
        gradient: const LinearGradient(
          colors: [Color(0xFFB846B9), Color(0xFF5033CB), Color(0xFF2155E6)],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10 * scale),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18 * scale,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileVideoHistory extends StatelessWidget {
  const _ProfileVideoHistory({
    required this.history,
    required this.requests,
    required this.scale,
    required this.loadingMore,
    required this.loadMoreFailed,
    required this.onRefresh,
    required this.onRetryMore,
    required this.onOpen,
    required this.isSelecting,
    required this.selectedRequestIds,
    required this.onLongPress,
    required this.onToggleSelection,
  });

  final AsyncValue<GenerationHistoryPage> history;
  final List<I2VRequestStatus> requests;
  final double scale;
  final bool loadingMore;
  final bool loadMoreFailed;
  final VoidCallback onRefresh;
  final VoidCallback onRetryMore;
  final ValueChanged<I2VRequestStatus> onOpen;
  final bool isSelecting;
  final Set<String> selectedRequestIds;
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      key: const Key('profileVideoHistory'),
      slivers: history.when(
        loading: () => [
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(
                  color: VideoFormStyle.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ],
        error: (_, _) => [
          SliverToBoxAdapter(
            child: _ProfileVideoMessage(
              message: 'Unable to load your videos.',
              actionLabel: 'Try again',
              onTap: onRefresh,
            ),
          ),
        ],
        data: (_) {
          if (requests.isEmpty) {
            return [
              SliverToBoxAdapter(
                child: _EmptyProfileVideos(
                  onCreate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImageToVideoScreen(),
                    ),
                  ),
                ),
              ),
            ];
          }
          return [
            SliverGrid.builder(
              key: const Key('profileVideoGrid'),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8 * scale,
                crossAxisSpacing: 8 * scale,
                childAspectRatio: 9 / 16,
              ),
              itemCount: requests.length,
              itemBuilder: (context, index) => _ProfileVideoCard(
                request: requests[index],
                isSelecting: isSelecting,
                isSelected: selectedRequestIds.contains(
                  requests[index].requestId,
                ),
                onTap: () => isSelecting
                    ? onToggleSelection(requests[index].requestId)
                    : onOpen(requests[index]),
                onLongPress: () => onLongPress(requests[index].requestId),
              ),
            ),
            if (loadingMore || loadMoreFailed)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16 * scale),
                  child: loadMoreFailed
                      ? _ProfileVideoMessage(
                          message: 'Unable to load more videos.',
                          actionLabel: 'Try again',
                          onTap: onRetryMore,
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: VideoFormStyle.accent,
                            strokeWidth: 2,
                          ),
                        ),
                ),
              ),
          ];
        },
      ),
    );
  }
}

class _ProfileVideoMessage extends StatelessWidget {
  const _ProfileVideoMessage({
    required this.message,
    this.actionLabel,
    this.onTap,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    decoration: BoxDecoration(
      gradient: _profileSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF343743), width: 0.6),
    ),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: VideoFormStyle.secondary, fontSize: 13),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB982FF),
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

class _EmptyProfileVideos extends StatelessWidget {
  const _EmptyProfileVideos({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('emptyProfileVideos'),
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
    decoration: BoxDecoration(
      gradient: _profileSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF343743), width: 0.6),
    ),
    child: Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF211E36),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5B4776), width: 0.7),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/profile/video_icon.png',
              key: const Key('emptyProfileVideoIcon'),
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your generated videos will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VideoFormStyle.secondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB846B9), Color(0xFF5033CB), Color(0xFF2155E6)],
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('createImageVideoFromProfile'),
              onTap: onCreate,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Create Video Now',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
  );
}

class _ProfileVideoCard extends StatelessWidget {
  const _ProfileVideoCard({
    required this.request,
    required this.isSelecting,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final I2VRequestStatus request;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final previewUrl = request.thumbnailUrl.isNotEmpty
        ? request.thumbnailUrl
        : request.imageUrl;
    final isCompleted = request.isCompleted;
    final hasVideo = isCompleted && request.resultUrl.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('profileVideo_${request.requestId}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF40364C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedVideoThumbnail(
                cacheKey: request.requestId,
                imageUrl: previewUrl,
                fallbackImageUrl: request.imageUrl,
                videoUrl: hasVideo ? request.resultUrl : '',
                preferVideoFrame: hasVideo,
                frameTimeMs: 0,
                maxDecodeWidth: 360,
              ),
              if (isSelected) const ColoredBox(color: Color(0x66000000)),
              if (isCompleted && !isSelecting)
                const Positioned(
                  left: 8,
                  bottom: 8,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 19,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              if (isSelecting) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? VideoFormStyle.accent
                              : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    key: ValueKey('profileVideoSelection_${request.requestId}'),
                    color: isSelected ? VideoFormStyle.accent : Colors.white,
                    size: 25,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 5),
                    ],
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

class _DeleteSelectedVideosDialog extends StatelessWidget {
  const _DeleteSelectedVideosDialog({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('deleteSelectedProfileVideosDialog'),
    backgroundColor: const Color(0xFF342D3E),
    title: Text('Delete $count video${count == 1 ? '' : 's'}?'),
    content: const Text(
      'Selected videos will be permanently removed from your history.',
      style: TextStyle(color: VideoFormStyle.secondary),
    ),
    actions: [
      TextButton(
        key: const Key('cancelDeleteSelectedProfileVideos'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: const Key('confirmDeleteSelectedProfileVideos'),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Delete', style: TextStyle(color: Color(0xFFE49AAA))),
      ),
    ],
  );
}

String _formatCredits(int value) {
  final digits = value.clamp(0, 999999999).toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }

  return buffer.toString();
}
