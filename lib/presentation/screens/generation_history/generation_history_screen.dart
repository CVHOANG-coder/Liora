import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/generation_history.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../image_to_video/creating_video_screen.dart';
import '../image_to_video/generated_video_screen.dart';

typedef GenerationHistoryFetcher =
    Future<GenerationHistoryPage> Function({
      required int page,
      required int limit,
    });
typedef GenerationHistoryDeleter = Future<void> Function(String requestId);

class GenerationHistoryScreen extends StatefulWidget {
  const GenerationHistoryScreen({
    super.key,
    this.fetcher,
    this.statusFetcher,
    this.progressRepository,
    this.deleter,
  });

  final GenerationHistoryFetcher? fetcher;
  final I2VStatusFetcher? statusFetcher;
  final GenerationProgressRepository? progressRepository;
  final GenerationHistoryDeleter? deleter;

  @override
  State<GenerationHistoryScreen> createState() =>
      _GenerationHistoryScreenState();
}

class _GenerationHistoryScreenState extends State<GenerationHistoryScreen> {
  static const _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  final List<I2VRequestStatus> _requests = <I2VRequestStatus>[];
  final Set<String> _deletingRequestIds = <String>{};

  bool _isInitialLoading = true;
  bool _isFirstPageLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalItems = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  Future<GenerationHistoryPage> _fetch(int page) {
    final fetcher = widget.fetcher;
    if (fetcher != null) return fetcher(page: page, limit: _pageSize);
    return ApiClient.instance.fetchGenerationHistory(
      page: page,
      limit: _pageSize,
    );
  }

  Future<void> _loadFirstPage({bool showInitialLoading = true}) async {
    if (_isFirstPageLoading) return;
    _isFirstPageLoading = true;
    if (_requests.isEmpty && showInitialLoading && mounted) {
      setState(() {
        _isInitialLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _fetch(1);
      unawaited(_clearTerminalProgress(result.requests));
      if (!mounted) return;
      setState(() {
        _requests
          ..clear()
          ..addAll(result.requests);
        _currentPage = result.pagination.page;
        _totalPages = result.pagination.totalPages;
        _totalItems = result.pagination.total;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      _isFirstPageLoading = false;
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isFirstPageLoading || _currentPage >= _totalPages) {
      return;
    }
    _isLoadingMore = true;
    if (mounted) setState(() {});
    try {
      final result = await _fetch(_currentPage + 1);
      unawaited(_clearTerminalProgress(result.requests));
      if (!mounted) return;
      setState(() {
        final existingIds = _requests.map((item) => item.requestId).toSet();
        _requests.addAll(
          result.requests.where((item) => existingIds.add(item.requestId)),
        );
        _currentPage = result.pagination.page;
        _totalPages = result.pagination.totalPages;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load more: $error')));
    } finally {
      _isLoadingMore = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearTerminalProgress(
    Iterable<I2VRequestStatus> requests,
  ) async {
    final terminalRequestIds = requests
        .where((request) => request.isTerminal)
        .map((request) => request.requestId)
        .where((requestId) => requestId.isNotEmpty);
    final repository =
        widget.progressRepository ??
        const SharedPreferencesGenerationProgressRepository();
    for (final requestId in terminalRequestIds) {
      try {
        await repository.remove(requestId);
      } catch (_) {
        // History can still render if local cleanup is unavailable.
      }
    }
  }

  Future<void> _openRequest(I2VRequestStatus request) async {
    Widget? destination;
    if (request.isCompleted && request.resultUrl.isNotEmpty) {
      destination = GeneratedVideoScreen(
        result: request,
        returnToPreviousOnBack: true,
      );
    } else if (request.isActive) {
      final repository =
          widget.progressRepository ??
          const SharedPreferencesGenerationProgressRepository();
      GenerationProgress? progress;
      try {
        progress = await repository.load(request.requestId);
      } catch (_) {
        // Rebuild progress from server metadata if local storage is unavailable.
      }
      progress ??= GenerationProgress.create(
        requestId: request.requestId,
        startedAt: request.createTime ?? DateTime.now(),
        videoDurationSeconds: request.duration > 0 ? request.duration : 5,
        isHd: request.isHd,
      );
      try {
        await repository.save(progress);
      } catch (_) {
        // The request can still be opened without persistent storage.
      }
      if (!mounted) return;
      destination = CreatingVideoScreen(
        generation: I2VGeneration.fromRequestStatus(request),
        statusFetcher: widget.statusFetcher,
        returnToPreviousOnBack: true,
        initialProgress: progress,
        progressRepository: repository,
      );
    }

    if (destination == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => destination!));
    if (mounted) await _loadFirstPage();
  }

  Future<void> _deleteRequest(I2VRequestStatus request) async {
    if (_deletingRequestIds.contains(request.requestId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (_) => _DeleteHistoryDialog(request: request),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingRequestIds.add(request.requestId));
    try {
      final deleter = widget.deleter;
      if (deleter != null) {
        await deleter(request.requestId);
      } else {
        await ApiClient.instance.deleteGenerationRequest(request.requestId);
      }
      try {
        await (widget.progressRepository ??
                const SharedPreferencesGenerationProgressRepository())
            .remove(request.requestId);
      } catch (_) {
        // The server deletion succeeded, so local cleanup stays best-effort.
      }
      if (!mounted) return;
      setState(() {
        _requests.removeWhere((item) => item.requestId == request.requestId);
        if (_totalItems > 0) _totalItems -= 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video removed from history.')),
      );
      await _loadFirstPage(showInitialLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete video: $error')));
    } finally {
      if (mounted) {
        setState(() => _deletingRequestIds.remove(request.requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xF208060B),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        toolbarHeight: 68,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: _HeaderAction(
            key: const Key('generationHistoryBack'),
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.maybePop(context),
          ),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Video History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Your AI creations',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _HeaderAction(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh videos',
              onTap: _isFirstPageLoading ? null : _loadFirstPage,
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.8),
            radius: 1.05,
            colors: [Color(0x4D4B123F), AppColors.background],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFF3CAE),
          strokeWidth: 2.5,
        ),
      );
    }

    if (_requests.isEmpty && _errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadFirstPage);
    }

    return RefreshIndicator(
      color: const Color(0xFFFF3CAE),
      backgroundColor: const Color(0xFF211520),
      onRefresh: _loadFirstPage,
      child: CustomScrollView(
        key: const PageStorageKey<String>('generationHistoryScroll'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (_requests.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else ...[
            SliverToBoxAdapter(
              child: _HistoryOverview(
                total: _totalItems,
                creating: _requests.where((item) => item.isActive).length,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                  childAspectRatio: 9 / 16,
                ),
                itemCount: _requests.length,
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  return _HistoryGridItem(
                    key: ValueKey<String>(request.requestId),
                    request: request,
                    onTap: () => _openRequest(request),
                    onDelete: () => _deleteRequest(request),
                    isDeleting: _deletingRequestIds.contains(request.requestId),
                  );
                },
              ),
            ),
          ],
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF3CAE),
                      strokeWidth: 2.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCC160D17),
        border: Border.all(color: const Color(0xFF6A2457)),
        boxShadow: const [BoxShadow(color: Color(0x44FF2FA8), blurRadius: 12)],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 21,
          color: onTap == null ? const Color(0xFF6F6672) : Colors.white,
        ),
      ),
    );
  }
}

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({required this.total, required this.creating});

  final int total;
  final int creating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0x99150C17),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF542047)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF35AF), Color(0xFFFF7044)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x66FF2DA9), blurRadius: 14),
                ],
              ),
              child: const Icon(
                Icons.video_library_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My videos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap a video to watch',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CountBadge(label: '$total videos'),
                if (creating > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    '$creating creating',
                    style: const TextStyle(
                      color: Color(0xFFFFAB46),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF53B6)),
        color: const Color(0x331F0B1A),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFF85C9),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HistoryGridItem extends StatelessWidget {
  const _HistoryGridItem({
    super.key,
    required this.request,
    required this.onTap,
    required this.onDelete,
    required this.isDeleting,
  });

  final I2VRequestStatus request;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final canOpen =
        (request.isCompleted && request.resultUrl.isNotEmpty) ||
        request.isActive;
    final previewUrl = request.thumbnailUrl.isNotEmpty
        ? request.thumbnailUrl
        : request.imageUrl;

    final title = request.prompt.isEmpty ? 'Untitled video' : request.prompt;
    final statusLabel = _statusLabel(request.requestStatus);

    return Semantics(
      button: canOpen,
      enabled: canOpen,
      label: '$title, $statusLabel, ${_formatDate(request.createTime)}',
      child: Material(
        color: const Color(0xFF211620),
        elevation: 4,
        shadowColor: const Color(0x66FF2FA8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF74305F)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('openHistoryRequest_${request.requestId}'),
          onTap: canOpen && !isDeleting ? onTap : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GridPreview(url: previewUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Colors.transparent,
                      Color(0xD9110613),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              if (request.isActive) const _QueuedOverlay(),
              if (request.isFailed || request.isCancelled)
                _TerminalOverlay(status: request.requestStatus),
              Positioned(
                top: 7,
                left: 7,
                child: _GridStatusBadge(status: request.status),
              ),
              if (request.isHd)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC09070B),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'HD',
                      style: TextStyle(
                        color: Color(0xFFFFA15A),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: request.isHd ? 34 : 7,
                right: 7,
                child: _GridDeleteButton(
                  requestId: request.requestId,
                  isDeleting: isDeleting,
                  onTap: onDelete,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    if (request.isCompleted) ...[
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFFFF72C4),
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                    ),
                    if (request.duration > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${request.duration}s',
                        style: const TextStyle(
                          color: Color(0xFFE4DEE6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _GridDeleteButton extends StatelessWidget {
  const _GridDeleteButton({
    required this.requestId,
    required this.isDeleting,
    required this.onTap,
  });

  final String requestId;
  final bool isDeleting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Delete video',
      child: Material(
        color: const Color(0xD9140911),
        shape: CircleBorder(
          side: BorderSide(
            color: const Color(0xFFFF607B).withValues(alpha: 0.72),
          ),
        ),
        elevation: 3,
        shadowColor: const Color(0x99FF315E),
        child: InkWell(
          key: Key('deleteHistoryRequest_$requestId'),
          onTap: isDeleting ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 29,
            child: Center(
              child: isDeleting
                  ? const SizedBox.square(
                      dimension: 13,
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7289),
                        strokeWidth: 1.8,
                      ),
                    )
                  : const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF7289),
                      size: 17,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteHistoryDialog extends StatelessWidget {
  const _DeleteHistoryDialog({required this.request});

  final I2VRequestStatus request;

  @override
  Widget build(BuildContext context) {
    final prompt = request.prompt.trim();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF25101F), Color(0xFF100B12)],
          ),
          border: Border.all(color: const Color(0xFF853052)),
          boxShadow: const [
            BoxShadow(color: Color(0x55FF315F), blurRadius: 28),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5271).withValues(alpha: 0.12),
                border: Border.all(color: const Color(0xFFFF617C)),
                boxShadow: const [
                  BoxShadow(color: Color(0x55FF315F), blurRadius: 18),
                ],
              ),
              child: const Icon(
                Icons.delete_forever_outlined,
                color: Color(0xFFFF7189),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete video?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This video will be permanently removed from your history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (prompt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x66100911),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4E293F)),
                ),
                child: Text(
                  prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD5CDD7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('cancelDeleteHistoryRequest'),
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF66415A)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('confirmDeleteHistoryRequest'),
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4E70),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      shadowColor: const Color(0xFFFF315F),
                      elevation: 6,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPreview extends StatelessWidget {
  const _GridPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF271823),
      child: url.isEmpty
          ? const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A1A34), Color(0xFF160F17)],
                ),
              ),
              child: Icon(
                Icons.movie_creation_outlined,
                color: Color(0xFFB77AA7),
                size: 32,
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF9D668E),
              ),
            ),
    );
  }
}

class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final requestStatus = GenerationRequestStatus.fromValue(status);
    final label = _statusLabel(requestStatus);
    final color = switch (requestStatus) {
      GenerationRequestStatus.completed => const Color(0xFF63E981),
      GenerationRequestStatus.inQueue => const Color(0xFFFFB046),
      GenerationRequestStatus.pending => const Color(0xFF54C7FC),
      GenerationRequestStatus.failed ||
      GenerationRequestStatus.error => const Color(0xFFFF6C78),
      GenerationRequestStatus.cancelled => const Color(0xFFB5ADB8),
      GenerationRequestStatus.deleted => const Color(0xFF777077),
      _ => const Color(0xFFFF62BC),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xD909070B),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedOverlay extends StatelessWidget {
  const _QueuedOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x55000000),
      child: Center(
        child: SizedBox.square(
          dimension: 25,
          child: CircularProgressIndicator(
            color: Color(0xFFFF51B4),
            strokeWidth: 2.2,
          ),
        ),
      ),
    );
  }
}

class _TerminalOverlay extends StatelessWidget {
  const _TerminalOverlay({required this.status});

  final GenerationRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == GenerationRequestStatus.cancelled;
    return ColoredBox(
      color: const Color(0x77000000),
      child: Center(
        child: Icon(
          isCancelled ? Icons.cancel_outlined : Icons.error_outline_rounded,
          color: isCancelled
              ? const Color(0xFFB5ADB8)
              : const Color(0xFFFF6877),
          size: 30,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          decoration: BoxDecoration(
            color: const Color(0xB3140D17),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF542047)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF39AF), Color(0xFFFF7940)],
                  ),
                  boxShadow: [
                    BoxShadow(color: Color(0x77FF2DA8), blurRadius: 20),
                  ],
                ),
                child: const Icon(
                  Icons.video_library_outlined,
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No videos yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your generated videos will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xB3140D17),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF61223F)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 54,
                color: Color(0xFFFF6687),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load video history',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3CAE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown date';
  final date = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}  '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

String _statusLabel(GenerationRequestStatus status) {
  return switch (status) {
    GenerationRequestStatus.inQueue => 'In queue',
    GenerationRequestStatus.pending => 'Processing',
    GenerationRequestStatus.completed => 'Completed',
    GenerationRequestStatus.failed => 'Failed',
    GenerationRequestStatus.error => 'Error',
    GenerationRequestStatus.cancelled => 'Cancelled',
    GenerationRequestStatus.deleted => 'Deleted',
    GenerationRequestStatus.unknown => 'Unknown',
  };
}
