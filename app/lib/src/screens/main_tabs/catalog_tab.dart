import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/cineva_theme.dart';
import '../../widgets/film_card_tile.dart';
import 'shared_components.dart';

int _catalogCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return ((w - 32) / 148).floor().clamp(3, 8);
}

class CatalogTab extends StatefulWidget {
  const CatalogTab({
    super.key,
    required this.title,
    required this.items,
    required this.loading,
    required this.loadingMore,
    required this.error,
    required this.hasMore,
    required this.searchOpen,
    required this.searchCtrl,
    required this.filtersActive,
    required this.onOpenFilters,
    required this.onCloseSearch,
    required this.onSearch,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpenFilm,
  });

  final String title;
  final List<FilmCard> items;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final bool filtersActive;
  final VoidCallback onOpenFilters;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onOpenFilm;

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: widget.searchCtrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                hintText: 'Tìm phim…',
                prefixIcon: const Icon(Icons.search, color: CinevaColors.muted),
                suffixIcon: IconButton(
                  tooltip: 'Đóng tìm kiếm',
                  icon: const Icon(Icons.close, color: CinevaColors.muted),
                  onPressed: widget.onCloseSearch,
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bộ lọc',
                  onPressed: widget.onOpenFilters,
                  icon: Badge(
                    isLabelVisible: widget.filtersActive,
                    smallSize: 8,
                    backgroundColor: CinevaColors.accent,
                    child: Icon(
                      Icons.tune_rounded,
                      color: widget.filtersActive
                          ? CinevaColors.accent
                          : CinevaColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: widget.loading && widget.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : widget.error != null && widget.items.isEmpty
              ? ErrorPane(
                  message: widget.error!,
                  onRetry: () => widget.onRefresh(),
                )
              : widget.items.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có phim',
                    style: TextStyle(color: CinevaColors.muted),
                  ),
                )
              : Column(
                  children: [
                    if (widget.loadingMore)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: RefreshIndicator(
                        color: CinevaColors.accent,
                        onRefresh: widget.onRefresh,
                        child: GridView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _catalogCrossAxisCount(context),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.48,
                          ),
                          itemCount: widget.items.length,
                          itemBuilder: (context, i) {
                            final film = widget.items[i];
                            return FilmCardTile(
                              film: film,
                              onTap: () => widget.onOpenFilm(film.slug),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
