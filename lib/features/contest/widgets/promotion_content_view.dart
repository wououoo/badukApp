import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_colors.dart';

/// 공문형(promotion) 대회 본문 — 서버가 내려준 contentSections(JSON)를 웹 PromotionTemplate과 같은 구조로 그린다.
///
/// 형식(웹과 동일)
///  { intro, sections: [ {no, title, type: info|table|text, rows, head, mobile:'cards', tabs, text, note} ], signature }
///  칸(cell): t=글자(\n 줄바꿈, **굵게**, [[빨강]]), cs=가로 합치기, rs=세로 합치기, h=머리칸, c=가운데
///  행(row): 칸 배열, 또는 {g:'부문명', cells:[...]} — g가 있으면 부문별로 걸러 볼 수 있다.
///
/// 형식이 깨졌으면 아무것도 그리지 않는다(정보 탭의 기본 안내는 그대로 보임).
class PromotionContentView extends StatelessWidget {
  final String? raw;
  const PromotionContentView({super.key, required this.raw});

  static Map<String, dynamic>? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic> && v['sections'] is List) return v;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = parse(raw);
    if (c == null) return const SizedBox.shrink();
    final sections = (c['sections'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c['intro'] is String && (c['intro'] as String).trim().isNotEmpty) ...[
            RichLine(text: c['intro'] as String, style: TextStyle(fontSize: 14, height: 1.65, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
          ],
          for (final s in sections) ...[
            _Section(section: s),
            const SizedBox(height: 22),
          ],
          if (c['signature'] is String && (c['signature'] as String).trim().isNotEmpty)
            Align(
              alignment: Alignment.center,
              child: RichLine(
                text: c['signature'] as String,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

/// 줄바꿈 + **굵게** + [[빨강]]
class RichLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  const RichLine({super.key, required this.text, required this.style, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'(\*\*[^*]+\*\*|\[\[[^\]]+\]\])');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tok = m.group(0)!;
      final inner = tok.substring(2, tok.length - 2);
      if (tok.startsWith('**')) {
        spans.add(TextSpan(text: inner, style: const TextStyle(fontWeight: FontWeight.w800)));
      } else {
        spans.add(TextSpan(text: inner, style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w700)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans), textAlign: textAlign);
  }
}

class _Section extends StatelessWidget {
  final Map<String, dynamic> section;
  const _Section({required this.section});

  @override
  Widget build(BuildContext context) {
    final type = section['type'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (section['no'] != null && section['no'].toString().isNotEmpty) ...[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                child: Text(section['no'].toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: RichLine(
                text: (section['title'] ?? '').toString(),
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (type == 'info') _InfoBlock(section: section),
        if (type == 'table') _TableBlock(section: section),
        if (type == 'text')
          RichLine(
            text: (section['text'] ?? '').toString(),
            style: TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.textPrimary),
          ),
        if (section['note'] is String && (section['note'] as String).trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          RichLine(
            text: section['note'] as String,
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

Color get _headBg => AppColors.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F5);

/// 개요형 — 라벨·값 쌍을 한 줄씩 세로로 (휴대폰 폭에서 2쌍 가로 배치는 너무 좁다)
class _InfoBlock extends StatelessWidget {
  final Map<String, dynamic> section;
  const _InfoBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    final pairs = <List<String>>[];
    for (final row in (section['rows'] as List? ?? const [])) {
      if (row is! List) continue;
      for (final p in row) {
        if (p is List && p.length >= 2) pairs.add([p[0].toString(), p[1].toString()]);
      }
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < pairs.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: AppColors.border)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 86,
                      color: _headBg,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: RichLine(
                        text: pairs[i][0],
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.4, color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: RichLine(
                          text: pairs[i][1],
                          style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _cellsOf(dynamic row) {
  final list = row is List ? row : (row is Map && row['cells'] is List ? row['cells'] as List : const []);
  return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String? _groupOf(dynamic row) => row is Map && row['g'] != null ? row['g'].toString() : null;

int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 1);

/// 합친 칸을 펼쳐 grid[r][c] = 그 자리를 덮는 칸
List<List<Map<String, dynamic>?>> _expand(List<dynamic> rows) {
  final grid = <List<Map<String, dynamic>?>>[];
  List<Map<String, dynamic>?> rowAt(int r) {
    while (grid.length <= r) {
      grid.add(<Map<String, dynamic>?>[]);
    }
    return grid[r];
  }

  for (var r = 0; r < rows.length; r++) {
    var c = 0;
    for (final cell in _cellsOf(rows[r])) {
      final row = rowAt(r);
      while (c < row.length && row[c] != null) {
        c++;
      }
      final rs = math.max(1, _int(cell['rs']));
      final cs = math.max(1, _int(cell['cs']));
      for (var i = 0; i < rs; i++) {
        final target = rowAt(r + i);
        for (var j = 0; j < cs; j++) {
          while (target.length <= c + j) {
            target.add(null);
          }
          target[c + j] = cell;
        }
      }
      c += cs;
    }
  }
  return grid;
}

class _TableBlock extends StatefulWidget {
  final Map<String, dynamic> section;
  const _TableBlock({required this.section});

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  String _tab = 'ALL';

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final head = (s['head'] as List?) ?? const [];
    final rows = (s['rows'] as List?) ?? const [];

    // 모바일 카드(웹 mobile:'cards'와 같음): 머리줄 2번째 칸부터 = 카드 제목, 각 줄 첫 칸 = 항목명
    if (s['mobile'] == 'cards' && head.isNotEmpty) {
      return _buildCards(head, rows);
    }

    final groups = <String>[];
    for (final r in rows) {
      final g = _groupOf(r);
      if (g != null && !groups.contains(g)) groups.add(g);
    }
    final showTabs = s['tabs'] == true && groups.length > 1;
    final shown = (!showTabs || _tab == 'ALL') ? rows : rows.where((r) => _groupOf(r) == _tab).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTabs) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in ['ALL', ...groups])
                ChoiceChip(
                  label: Text(t == 'ALL' ? '전체' : t),
                  selected: _tab == t,
                  onSelected: (_) => setState(() => _tab = t),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _tab == t ? AppColors.primary : AppColors.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text('← 옆으로 밀어서 보기', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _SpanTable(head: head, rows: shown),
        ),
      ],
    );
  }

  Widget _buildCards(List<dynamic> head, List<dynamic> rows) {
    final titles = _cellsOf(head.first);
    final grid = _expand(rows);
    final cards = <Widget>[];
    for (var col = 1; col < titles.length; col++) {
      final items = <List<String>>[];
      for (final g in grid) {
        if (g.isEmpty || g[0] == null || col >= g.length || g[col] == null) continue;
        items.add([(g[0]!['t'] ?? '').toString(), (g[col]!['t'] ?? '').toString()]);
      }
      cards.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: AppColors.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: RichLine(
                text: (titles[col]['t'] ?? '').toString(),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ),
            for (final it in items)
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichLine(
                      text: it[0].replaceAll('\n', ' '),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 3),
                    RichLine(
                      text: it[1],
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ));
    }
    return Column(children: cards);
  }
}

/// 합친 칸(rs/cs)을 지원하는 표. 열 너비는 고정, 행 높이는 내용에 맞춘다.
class _SpanTable extends StatelessWidget {
  final List<dynamic> head;
  final List<dynamic> rows;
  const _SpanTable({required this.head, required this.rows});

  @override
  Widget build(BuildContext context) {
    // 머리줄은 모두 머리칸·가운데 정렬로
    final all = <dynamic>[
      for (final h in head) [for (final c in _cellsOf(h)) {...c, 'h': 1, 'c': 1}],
      ...rows,
    ];
    final grid = _expand(all);
    var colCount = 0;
    for (final g in grid) {
      colCount = math.max(colCount, g.length);
    }
    if (colCount == 0) return const SizedBox.shrink();

    // 앞쪽 머리칸 열(시간·구분)은 좁게, 나머지는 넉넉하게
    final widths = <double>[];
    for (var c = 0; c < colCount; c++) {
      var allHead = true;
      for (var r = head.length; r < grid.length; r++) {
        final cell = c < grid[r].length ? grid[r][c] : null;
        if (cell != null && cell['h'] == null) {
          allHead = false;
          break;
        }
      }
      widths.add(allHead ? 64 : 112);
    }

    final children = <Widget>[];
    final seen = <Map<String, dynamic>>{};
    for (var r = 0; r < grid.length; r++) {
      for (var c = 0; c < grid[r].length; c++) {
        final cell = grid[r][c];
        if (cell == null || seen.contains(cell)) continue;
        seen.add(cell);
        final rs = math.max(1, _int(cell['rs']));
        final cs = math.max(1, _int(cell['cs']));
        final isHead = cell['h'] != null;
        children.add(_SpanCell(
          row: r,
          col: c,
          rowSpan: math.min(rs, grid.length - r),
          colSpan: math.min(cs, colCount - c),
          child: Container(
            decoration: BoxDecoration(
              color: isHead ? _headBg : AppColors.surface,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            alignment: (isHead || cell['c'] != null) ? Alignment.center : Alignment.centerLeft,
            child: RichLine(
              text: (cell['t'] ?? '').toString(),
              textAlign: (isHead || cell['c'] != null) ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: isHead ? FontWeight.w700 : FontWeight.w400,
                color: isHead ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
        ));
      }
    }
    return _SpanGrid(columnWidths: widths, rowCount: grid.length, children: children);
  }
}

class _SpanCell extends ParentDataWidget<_SpanParentData> {
  final int row, col, rowSpan, colSpan;
  const _SpanCell({
    required this.row,
    required this.col,
    required this.rowSpan,
    required this.colSpan,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData as _SpanParentData;
    if (pd.row != row || pd.col != col || pd.rowSpan != rowSpan || pd.colSpan != colSpan) {
      pd
        ..row = row
        ..col = col
        ..rowSpan = rowSpan
        ..colSpan = colSpan;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _SpanGrid;
}

class _SpanParentData extends ContainerBoxParentData<RenderBox> {
  int row = 0, col = 0, rowSpan = 1, colSpan = 1;
}

class _SpanGrid extends MultiChildRenderObjectWidget {
  final List<double> columnWidths;
  final int rowCount;
  const _SpanGrid({required this.columnWidths, required this.rowCount, required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpanGrid(columnWidths, rowCount);

  @override
  void updateRenderObject(BuildContext context, _RenderSpanGrid renderObject) {
    renderObject
      ..columnWidths = columnWidths
      ..rowCount = rowCount;
  }
}

/// 1) 한 줄짜리 칸으로 행 높이를 정하고 2) 여러 줄을 합친 칸이 더 높으면 마지막 행을 늘린 뒤
/// 3) 모든 칸을 차지하는 자리 크기에 꽉 맞춰 다시 배치한다.
class _RenderSpanGrid extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _SpanParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _SpanParentData> {
  _RenderSpanGrid(this._columnWidths, this._rowCount);

  List<double> _columnWidths;
  set columnWidths(List<double> v) {
    _columnWidths = v;
    markNeedsLayout();
  }

  int _rowCount;
  set rowCount(int v) {
    _rowCount = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SpanParentData) child.parentData = _SpanParentData();
  }

  double _spanWidth(int col, int span) {
    var w = 0.0;
    for (var i = col; i < col + span && i < _columnWidths.length; i++) {
      w += _columnWidths[i];
    }
    return w;
  }

  @override
  void performLayout() {
    final heights = List<double>.filled(_rowCount, 0);
    // 1) 한 줄짜리
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData as _SpanParentData;
      if (pd.rowSpan == 1) {
        final h = child.getMaxIntrinsicHeight(_spanWidth(pd.col, pd.colSpan));
        if (pd.row < _rowCount) heights[pd.row] = math.max(heights[pd.row], h);
      }
      child = pd.nextSibling;
    }
    // 2) 여러 줄 합친 칸
    child = firstChild;
    while (child != null) {
      final pd = child.parentData as _SpanParentData;
      if (pd.rowSpan > 1) {
        final need = child.getMaxIntrinsicHeight(_spanWidth(pd.col, pd.colSpan));
        var have = 0.0;
        final last = math.min(pd.row + pd.rowSpan, _rowCount) - 1;
        for (var r = pd.row; r <= last; r++) {
          have += heights[r];
        }
        if (need > have && last >= 0) heights[last] += need - have;
      }
      child = pd.nextSibling;
    }
    // 3) 배치
    final rowTop = <double>[0];
    for (final h in heights) {
      rowTop.add(rowTop.last + h);
    }
    final colLeft = <double>[0];
    for (final w in _columnWidths) {
      colLeft.add(colLeft.last + w);
    }
    child = firstChild;
    while (child != null) {
      final pd = child.parentData as _SpanParentData;
      final w = _spanWidth(pd.col, pd.colSpan);
      final endRow = math.min(pd.row + pd.rowSpan, _rowCount);
      final h = rowTop[endRow] - rowTop[math.min(pd.row, _rowCount)];
      child.layout(BoxConstraints.tight(Size(w, h)));
      pd.offset = Offset(colLeft[math.min(pd.col, _columnWidths.length)], rowTop[math.min(pd.row, _rowCount)]);
      child = pd.nextSibling;
    }
    size = constraints.constrain(Size(colLeft.last, rowTop.last));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
