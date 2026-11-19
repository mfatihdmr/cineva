import 'package:flutter/material.dart' hide ImageInfo;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/widgets/common.dart';
import '../../data/models/tmdb_models.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  final MediaType type;
  final int id;
  final List<ImageInfo>? images;
  const GalleryScreen({
    super.key,
    required this.type,
    required this.id,
    this.images,
  });

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    if (widget.images != null) {
      return _scaffold(
        ImageCollection(backdrops: widget.images!, posters: const []),
        l,
      );
    }
    final key = (widget.type, widget.id);
    final async = ref.watch(imagesProvider(key));
    return async.when(
      loading:
          () => Scaffold(
            appBar: AppBar(title: Text(l.gallery)),
            body: const _GalleryShimmer(),
          ),
      error:
          (e, st) => Scaffold(
            appBar: AppBar(title: Text(l.gallery)),
            body: ErrorView(
              error: e,
              onRetry: () => ref.invalidate(imagesProvider(key)),
            ),
          ),
      data: (c) => _scaffold(c, l),
    );
  }

  Widget _scaffold(ImageCollection c, L10n l) {
    final tabs = <(String, List<ImageInfo>, double)>[
      (l.t('Arkalar', 'Backdrops'), c.backdrops, 16 / 9),
      (l.t('Posterler', 'Posters'), c.posters, 2 / 3),
      (l.t('Logolar', 'Logos'), c.logos, 16 / 9),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.gallery),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: '${t.$1} (${t.$2.length})')],
          ),
        ),
        body: TabBarView(
          children: [
            for (final t in tabs) _ImageGrid(images: t.$2, ratio: t.$3),
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends ConsumerWidget {
  final List<ImageInfo> images;
  final double ratio;
  const _ImageGrid({required this.images, required this.ratio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    if (images.isEmpty) {
      return EmptyView(
        icon: Icons.photo_library_outlined,
        title: l.emptyTitle,
        subtitle: l.emptySub,
      );
    }
    final repo = ref.watch(repoProvider);
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ratio > 1.2 ? 2 : 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: ratio * 0.94,
      ),
      itemCount: images.length,
      itemBuilder: (_, i) {
        final img = images[i];
        return GestureDetector(
          onTap:
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _Viewer(images: images, initial: i),
                ),
              ),
          child: Hero(
            tag: 'gallery_${img.filePath}',
            child: _GridTile(
              image: img,
              url: repo.image(img.filePath, size: 'w500'),
            ),
          ),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  final ImageInfo image;
  final String url;
  const _GridTile({required this.image, required this.url});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (image.width > 0 && image.height > 0) '${image.width}×${image.height}',
      if (image.language.isNotEmpty) image.language.toUpperCase(),
    ].join('  ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RemoteImage(url: url),
          if (meta.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Viewer extends ConsumerStatefulWidget {
  final List<ImageInfo> images;
  final int initial;
  const _Viewer({required this.images, required this.initial});

  @override
  ConsumerState<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends ConsumerState<_Viewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initial,
  );
  late int _page = widget.initial;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    super.dispose();
  }

  void _copyUrl(String url) {
    final l = ref.read(l10nProvider);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.t('Bağlantı kopyalandı', 'Link copied to clipboard')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repoProvider);
    final l = ref.watch(l10nProvider);
    final current = widget.images[_page];
    final fullUrl = repo.image(current.filePath, size: 'original');
    final meta = <String>[
      if (current.width > 0 && current.height > 0)
        '${current.width}×${current.height}',
      if (current.language.isNotEmpty) current.language.toUpperCase(),
    ].join('  ');
    return Dismissible(
      key: const Key('gallery_viewer'),
      direction: DismissDirection.up,
      confirmDismiss: (_) async {
        if (context.mounted) Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final img = widget.images[i];
                return Hero(
                  tag: 'gallery_${img.filePath}',
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: RemoteImage(
                        url: repo.image(img.filePath, size: 'original'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      tooltip: l.close,
                    ),
                    const Spacer(),
                    Text(
                      '${_page + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    IconButton(
                      onPressed: () => _copyUrl(fullUrl),
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      tooltip: l.share,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          meta.isEmpty ? l.photos : meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _copyUrl(fullUrl),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: Text(
                          l.share,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
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

class _GalleryShimmer extends StatelessWidget {
  const _GalleryShimmer();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => const ShimmerBox(height: 100),
    );
  }
}
