import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/topxx_models.dart';
import '../services/topxx_client.dart';
import '../theme/cineva_theme.dart';
import '../widgets/cineva_header.dart';
import '../widgets/cineva_network_image.dart';

const List<String> kAdultGenres = [
  'Vietsub',
  'Không che',
  'Hentai',
  'Gái xinh',
  'Cặp Đôi',
  'Vụng trộm',
  'Loạn Luân',
  'Tập Thể',
  'Học sinh',
  'Bạo Dâm',
  'Old - Young',
  'LGBT+',
];

const List<String> kAdultCountries = [
  'Nhật Bản',
  'Hàn Quốc',
  'Việt Nam',
  'US - UK',
  'Trung Quốc',
];

class AdultHomeScreen extends StatefulWidget {
  const AdultHomeScreen({super.key});

  @override
  State<AdultHomeScreen> createState() => _AdultHomeScreenState();
}

class _AdultHomeScreenState extends State<AdultHomeScreen> {
  String _sort = 'newest'; // 'newest' | 'today'
  String? _selectedGenre;
  String? _selectedCountry;
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // Catalog State
  List<TopxxMovie> _items = [];
  int _page = 0;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final _scrollCtrl = ScrollController();

  bool get _hasActiveFilters =>
      _selectedGenre != null ||
      _selectedCountry != null ||
      _sort != 'newest' ||
      _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadCatalog(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_items.length >= _total && _total > 0) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      _loadCatalog(reset: false);
    }
  }

  Future<void> _loadCatalog({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
        _items = [];
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final client = context.read<TopxxClient>();
      final q = _searchCtrl.text.trim();
      final targetPage = reset ? 1 : _page + 1;

      String? query;
      if (q.isNotEmpty) {
        query = q;
      } else if (_selectedCountry != null) {
        query = _selectedCountry;
      } else if (_selectedGenre != null) {
        query = _selectedGenre;
      }

      TopxxPageResult res;
      if (query != null && query.isNotEmpty) {
        res = await client.search(query, page: targetPage, perPage: 24);
      } else if (_sort == 'today') {
        res = await client.getToday(page: targetPage, perPage: 24);
      } else {
        res = await client.getLatest(page: targetPage, perPage: 24);
      }

      if (!mounted) return;
      setState(() {
        _items = reset ? res.items : [..._items, ...res.items];
        _total = res.total;
        _page = targetPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadCatalog(reset: true);
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0x4DFFFFFF)),
      ),
      builder: (ctx) {
        String draftSort = _sort;
        String? draftGenre = _selectedGenre;
        String? draftCountry = _selectedCountry;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final hasActive =
                draftGenre != null || draftCountry != null || draftSort != 'newest';

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 4, bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const Text(
                        'Bộ lọc',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sắp xếp và lọc kho phim giống trên web.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Sắp xếp
                      const Text(
                        'Sắp xếp',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4D4D8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChoiceChip(
                            label: 'Mới nhất',
                            selected: draftSort == 'newest',
                            onTap: () =>
                                setSheetState(() => draftSort = 'newest'),
                          ),
                          _ChoiceChip(
                            label: 'Hôm nay hot',
                            selected: draftSort == 'today',
                            onTap: () => setSheetState(() => draftSort = 'today'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Thể loại (Dropdown)
                      const Text(
                        'Thể loại',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4D4D8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftGenre ?? '',
                        isExpanded: true,
                        dropdownColor: const Color(0xFF141414),
                        decoration: _dropdownDecoration('Tất cả thể loại'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              'Tất cả thể loại',
                              style: TextStyle(color: CinevaColors.muted),
                            ),
                          ),
                          ...kAdultGenres.map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setSheetState(() {
                            draftGenre = (v == null || v.isEmpty) ? null : v;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Quốc gia (Dropdown)
                      const Text(
                        'Quốc gia',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4D4D8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftCountry ?? '',
                        isExpanded: true,
                        dropdownColor: const Color(0xFF141414),
                        decoration: _dropdownDecoration('Tất cả quốc gia'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              'Tất cả quốc gia',
                              style: TextStyle(color: CinevaColors.muted),
                            ),
                          ),
                          ...kAdultCountries.map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setSheetState(() {
                            draftCountry = (v == null || v.isEmpty) ? null : v;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bottom Action Buttons
                      Row(
                        children: [
                          if (hasActive) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setSheetState(() {
                                    draftSort = 'newest';
                                    draftGenre = null;
                                    draftCountry = null;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFF3F3F46),
                                  ),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Đặt lại'),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _sort = draftSort;
                                  _selectedGenre = draftGenre;
                                  _selectedCountry = draftCountry;
                                  _searchCtrl.clear();
                                });
                                _loadCatalog(reset: true);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Áp dụng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openMovieDetail(TopxxMovie movie) {
    context.push('/phim-18/${movie.code}', extra: movie);
  }

  String _currentTitle() {
    if (_searchCtrl.text.isNotEmpty) {
      return 'Tìm kiếm: "${_searchCtrl.text}"';
    }
    if (_selectedCountry != null && _selectedGenre != null) {
      return '$_selectedCountry · $_selectedGenre';
    }
    if (_selectedCountry != null) {
      return 'Phim $_selectedCountry';
    }
    if (_selectedGenre != null) {
      return 'Phim $_selectedGenre';
    }
    if (_sort == 'today') {
      return 'Hôm nay nổi bật';
    }
    return 'Phim';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CinevaColors.bg,
      body: Column(
        children: [
          CinevaHeader(
            onSearch: () {
              setState(() {
                _searchOpen = !_searchOpen;
              });
            },
          ),

          // Search Bar if toggled
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm phim 18+…',
                        hintStyle: const TextStyle(
                          color: CinevaColors.mutedSoft,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: CinevaColors.muted,
                        ),
                        filled: true,
                        fillColor: CinevaColors.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchOpen = false);
                      _loadCatalog(reset: true);
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: CinevaColors.muted,
                    ),
                  ),
                ],
              ),
            ),

          // Exact Cineva Section Title Bar (NO CUỘN NGANG)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentTitle(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bộ lọc',
                  onPressed: _showFilterSheet,
                  icon: Badge(
                    isLabelVisible: _hasActiveFilters,
                    smallSize: 8,
                    backgroundColor: const Color(0xFFE11D48),
                    child: Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilters
                          ? const Color(0xFFE11D48)
                          : CinevaColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Film Grid (Exact Cineva Layout)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadCatalog(reset: true),
              color: const Color(0xFFE11D48),
              child: _loading && _items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFE11D48),
                      ),
                    )
                  : _error != null && _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: CinevaColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () => _loadCatalog(reset: true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFE11D48),
                                  ),
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? const Center(
                              child: Text(
                                'Chưa có phim',
                                style: TextStyle(color: CinevaColors.muted),
                              ),
                            )
                          : GridView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.94,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i >= _items.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFE11D48),
                                      ),
                                    ),
                                  );
                                }
                                final movie = _items[i];
                                return _AdultVideoCard(
                                  movie: movie,
                                  onTap: () => _openMovieDetail(movie),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFE11D48).withValues(alpha: 0.18)
          : const Color(0xFF141414),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE11D48)
                  : const Color(0xFF27272A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFFFF529D)
                  : const Color(0xFFE4E4E7),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _dropdownDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFF141414),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF27272A)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF27272A)),
    ),
  );
}

/// Clean video card with 16:9 thumbnail and refined typography (matching Cineva)
class _AdultVideoCard extends StatefulWidget {
  const _AdultVideoCard({
    required this.movie,
    required this.onTap,
  });

  final TopxxMovie movie;
  final VoidCallback onTap;

  @override
  State<_AdultVideoCard> createState() => _AdultVideoCardState();
}

class _AdultVideoCardState extends State<_AdultVideoCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _pressed ? -2 : 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: CinevaColors.surfaceElevated,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CinevaNetworkImage(
                        url: movie.effectivePoster,
                        fit: BoxFit.cover,
                      ),
                      // Top Quality Badge
                      if (movie.quality != null)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              movie.quality!,
                              style: const TextStyle(
                                color: Color(0xFFFF529D),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      // Bottom Duration Chip
                      if (movie.duration != null)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              movie.duration!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            // Title
            Text(
              movie.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _pressed ? const Color(0xFFFF529D) : const Color(0xFFF4F4F5),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            // Subtitle
            Text(
              movie.duration != null ? '${movie.duration} · FHD' : 'Video FHD',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CinevaColors.mutedSoft,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
