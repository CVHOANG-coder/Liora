import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/video_form_style.dart';
import '../../widgets/video_library_widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/generation_history.dart';
import '../../../data/models/generation_progress.dart';
import '../../../data/models/i2v_generation.dart';
import '../../../data/models/i2v_request_status.dart';
import '../../../data/services/generation_progress_repository.dart';
import '../../widgets/cached_video_thumbnail.dart';
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
        deleter: widget.deleter,
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
        openedFromHistory: true,
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VideoFormStyle.background,
    appBar: AppBar(
      key: const Key('generationHistoryHeader'),
      backgroundColor: VideoFormStyle.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: _HeaderAction(
          key: const Key('generationHistoryBack'),
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      centerTitle: true,
      title: Text(
        'Video History',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: VideoFormStyle.serif(25),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _HeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh videos',
            onTap: _isFirstPageLoading ? null : _loadFirstPage,
          ),
        ),
      ],
    ),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                color: VideoFormStyle.accent,
                strokeWidth: 2,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Opening your library…',
              style: TextStyle(color: VideoFormStyle.secondary, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (_requests.isEmpty && _errorMessage != null) {
      return _ErrorState(message: _errorMessage!, onRetry: _loadFirstPage);
    }
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final columns = textScale > 1.35
        ? (width < 600 ? 1 : 2)
        : (width / 220).floor().clamp(2, 4);
    final tileWidth = (width - 32 - (columns - 1) * 12) / columns;
    return RefreshIndicator(
      color: VideoFormStyle.accent,
      backgroundColor: const Color(0xFF101525),
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
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  mainAxisExtent: tileWidth * 1.15 + 88 * textScale,
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
                      color: VideoFormStyle.accent,
                      strokeWidth: 2,
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
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0D1220),
        border: Border.all(color: VideoFormStyle.border, width: .6),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(
          icon,
          size: 21,
          color: onTap == null ? VideoFormStyle.muted : VideoFormStyle.accent,
        ),
      ),
    ),
  );
}

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({required this.total, required this.creating});
  final int total;
  final int creating;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIORA / LIBRARY',
          style: TextStyle(
            color: VideoFormStyle.accent,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('My videos', style: VideoFormStyle.serif(31))),
            const SizedBox(width: 12),
            VideoLibraryTag('$total videos'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          creating > 0
              ? '$creating in progress in this view · tap to continue'
              : 'Your ideas, brought to life.',
          style: const TextStyle(
            color: VideoFormStyle.secondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
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
    final title = request.prompt.trim().isEmpty
        ? 'Untitled video'
        : request.prompt;
    final statusLabel = _statusLabel(request.requestStatus);
    return Semantics(
      label: '$title, $statusLabel, ${_formatDate(request.createTime)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: VideoFormStyle.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF303344), width: .6),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('openHistoryRequest_${request.requestId}'),
            onTap: canOpen && !isDeleting ? onTap : null,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _GridPreview(
                        requestId: request.requestId,
                        imageUrl: previewUrl,
                        videoUrl: request.isTextToVideo
                            ? request.resultUrl
                            : '',
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x3302050C),
                              Colors.transparent,
                              Color(0x6602050C),
                            ],
                            stops: [0, .5, 1],
                          ),
                        ),
                      ),
                      if (request.isActive) const _QueuedOverlay(),
                      if (request.isFailed || request.isCancelled)
                        _TerminalOverlay(status: request.requestStatus),
                      Positioned(
                        top: 9,
                        left: 9,
                        right: 9,
                        child: Row(
                          children: [
                            Flexible(
                              child: _GridStatusBadge(status: request.status),
                            ),
                            if (request.isHd) ...[
                              const SizedBox(width: 6),
                              const VideoLibraryTag(
                                'HD',
                                color: VideoFormStyle.accent,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Row(
                          children: [
                            if (request.isCompleted &&
                                request.resultUrl.isNotEmpty)
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Color(0xCC0B101B),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            const Spacer(),
                            if (request.duration > 0)
                              VideoLibraryTag('${request.duration}s'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(request.createTime).split('  ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VideoFormStyle.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          _GridDeleteButton(
                            requestId: request.requestId,
                            isDeleting: isDeleting,
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 36,
    child: IconButton(
      key: Key('deleteHistoryRequest_$requestId'),
      tooltip: 'Delete video',
      padding: EdgeInsets.zero,
      onPressed: isDeleting ? null : onTap,
      icon: isDeleting
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                color: VideoFormStyle.accent,
                strokeWidth: 1.5,
              ),
            )
          : const Icon(
              Icons.delete_outline_rounded,
              color: VideoFormStyle.muted,
              size: 18,
            ),
    ),
  );
}

class _DeleteHistoryDialog extends StatelessWidget {
  const _DeleteHistoryDialog({required this.request});
  final I2VRequestStatus request;

  @override
  Widget build(BuildContext context) => VideoLibraryDeleteDialog(
    key: const Key('deleteHistoryVideoDialog'),
    prompt: request.prompt,
    cancelKey: const Key('cancelDeleteHistoryRequest'),
    confirmKey: const Key('confirmDeleteHistoryRequest'),
  );
}

class _GridPreview extends StatelessWidget {
  const _GridPreview({
    required this.requestId,
    required this.imageUrl,
    required this.videoUrl,
  });
  final String requestId;
  final String imageUrl;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    final needsGeneratedPreview = imageUrl.isEmpty && videoUrl.isNotEmpty;
    return CachedVideoThumbnail(
      key: needsGeneratedPreview ? Key('historyVideoPreview_$requestId') : null,
      cacheKey: 'request:$requestId',
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      fit: BoxFit.cover,
      placeholder: _previewPlaceholder,
      errorWidget: _previewPlaceholder,
    );
  }

  Widget get _previewPlaceholder => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF20203B), Color(0xFF0A1221)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.movie_creation_outlined,
        color: Color(0xFF8C81B3),
        size: 38,
      ),
    ),
  );
}

class _GridStatusBadge extends StatelessWidget {
  const _GridStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final requestStatus = GenerationRequestStatus.fromValue(status);
    final color = switch (requestStatus) {
      GenerationRequestStatus.completed => const Color(0xFFA9D2C2),
      GenerationRequestStatus.failed ||
      GenerationRequestStatus.error => const Color(0xFFE49AAA),
      GenerationRequestStatus.inQueue ||
      GenerationRequestStatus.pending => VideoFormStyle.accent,
      _ => VideoFormStyle.secondary,
    };
    return VideoLibraryTag(_statusLabel(requestStatus), color: color);
  }
}

class _QueuedOverlay extends StatelessWidget {
  const _QueuedOverlay();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0x3302050C),
    child: Center(
      child: SizedBox.square(
        dimension: 25,
        child: CircularProgressIndicator(
          color: VideoFormStyle.accent,
          strokeWidth: 2,
        ),
      ),
    ),
  );
}

class _TerminalOverlay extends StatelessWidget {
  const _TerminalOverlay({required this.status});
  final GenerationRequestStatus status;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x7702050C),
    child: Center(
      child: Icon(
        status == GenerationRequestStatus.cancelled
            ? Icons.cancel_outlined
            : Icons.error_outline_rounded,
        color: status == GenerationRequestStatus.cancelled
            ? VideoFormStyle.secondary
            : const Color(0xFFE49AAA),
        size: 30,
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/profile/video_icon.png',
          width: 112,
          height: 112,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 24),
        Text(
          'No videos yet',
          textAlign: TextAlign.center,
          style: VideoFormStyle.serif(30),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your generated videos will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VideoFormStyle.secondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: VideoFormStyle.accent,
                size: 48,
              ),
              const SizedBox(height: 22),
              Text(
                'Could not load video history',
                textAlign: TextAlign.center,
                style: VideoFormStyle.serif(27),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VideoFormStyle.secondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              VideoLibraryAction(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onTap: onRetry,
                primary: true,
              ),
            ],
          ),
        ),
      ),
    ],
  );
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
