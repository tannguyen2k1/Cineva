import 'package:flutter/material.dart';

import '../models/taxonomies.dart';
import '../theme/cineva_theme.dart';

Future<CatalogFilters?> showCatalogFilterSheet(
  BuildContext context, {
  required CatalogFilters current,
  required Taxonomies taxonomies,
}) {
  return showModalBottomSheet<CatalogFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0A0A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      side: BorderSide(color: Color(0x4DFFFFFF)),
    ),
    builder: (ctx) => _CatalogFilterSheet(
      initial: current,
      taxonomies: taxonomies,
    ),
  );
}

class _CatalogFilterSheet extends StatefulWidget {
  const _CatalogFilterSheet({
    required this.initial,
    required this.taxonomies,
  });

  final CatalogFilters initial;
  final Taxonomies taxonomies;

  @override
  State<_CatalogFilterSheet> createState() => _CatalogFilterSheetState();
}

class _CatalogFilterSheetState extends State<_CatalogFilterSheet> {
  late String _sort;
  late String? _type;
  late String? _genre;
  late String? _year;
  late String? _country;

  @override
  void initState() {
    super.initState();
    _sort = widget.initial.sort;
    _type = widget.initial.type;
    _genre = widget.initial.genre;
    _year = widget.initial.year;
    _country = widget.initial.country;
  }

  CatalogFilters get _draft => CatalogFilters(
        sort: _sort,
        type: _type,
        genre: _genre,
        year: _year,
        country: _country,
      );

  void _reset() {
    setState(() {
      _sort = 'newest';
      _type = null;
      _genre = null;
      _year = null;
      _country = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tax = widget.taxonomies;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 18),
              _FieldLabel('Sắp xếp'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ChoiceChip(
                    label: 'Mới nhất',
                    selected: _sort == 'newest',
                    onTap: () => setState(() => _sort = 'newest'),
                  ),
                  _ChoiceChip(
                    label: 'Tên A–Z',
                    selected: _sort == 'name',
                    onTap: () => setState(() => _sort = 'name'),
                  ),
                  _ChoiceChip(
                    label: 'Năm',
                    selected: _sort == 'year',
                    onTap: () => setState(() => _sort = 'year'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DropdownField(
                label: 'Loại phim',
                value: _type,
                hint: 'Tất cả loại',
                items: tax.types,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 12),
              _DropdownField(
                label: 'Thể loại',
                value: _genre,
                hint: 'Tất cả thể loại',
                items: tax.genres,
                onChanged: (v) => setState(() => _genre = v),
              ),
              const SizedBox(height: 12),
              _StringDropdownField(
                label: 'Năm',
                value: _year,
                hint: 'Tất cả năm',
                items: tax.years,
                onChanged: (v) => setState(() => _year = v),
              ),
              const SizedBox(height: 12),
              _DropdownField(
                label: 'Quốc gia',
                value: _country,
                hint: 'Tất cả quốc gia',
                items: tax.countries,
                onChanged: (v) => setState(() => _country = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_draft.hasActive) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reset,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF3F3F46)),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Đặt lại'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _draft),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Áp dụng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFFD4D4D8),
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
          ? CinevaColors.accent.withValues(alpha: 0.18)
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
              color: selected ? CinevaColors.accent : const Color(0xFF27272A),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? CinevaColors.accent : const Color(0xFFE4E4E7),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<TaxonomyItem> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = () {
      final v = value ?? '';
      if (v.isEmpty) return '';
      return items.any((e) => e.slug == v) ? v : '';
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: const Color(0xFF141414),
          decoration: _dropdownDecoration(hint),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(hint, style: const TextStyle(color: CinevaColors.muted)),
            ),
            ...items.map(
              (e) => DropdownMenuItem<String>(
                value: e.slug,
                child: Text(e.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
        ),
      ],
    );
  }
}

class _StringDropdownField extends StatelessWidget {
  const _StringDropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = () {
      final v = value ?? '';
      if (v.isEmpty) return '';
      return items.contains(v) ? v : '';
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: const Color(0xFF141414),
          decoration: _dropdownDecoration(hint),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(hint, style: const TextStyle(color: CinevaColors.muted)),
            ),
            ...items.map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e),
              ),
            ),
          ],
          onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
        ),
      ],
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
