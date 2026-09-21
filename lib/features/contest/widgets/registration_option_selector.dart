import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

// 설명 텍스트 속 http(s) URL을 탭 가능한 링크로 렌더 (단급증 조회 링크 등). URL 없으면 일반 텍스트.
Widget _linkifiedText(String text, {required TextStyle style}) {
  final re = RegExp(r'(https?:\/\/[^\s)]+)');
  if (!re.hasMatch(text)) return Text(text, style: style);
  final linkStyle = style.copyWith(color: const Color(0xFF2563EB), decoration: TextDecoration.underline);
  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    final url = m.group(0)!;
    spans.add(TextSpan(
      text: url,
      style: linkStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    ));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return Text.rich(TextSpan(style: style, children: spans));
}

/// 신청 추가 항목 위젯 — 대회가 정의한 옵션(숙박·식사·기념품 등)을 렌더한다.
/// definitions: [{key,label,type,required,choices:[{value,label}],description}]
/// onChanged(payload, valid): payload=[{key,values:[...],text}], valid=필수 충족 여부
class RegistrationOptionSelector extends StatefulWidget {
  final List<Map<String, dynamic>> definitions;
  final void Function(List<Map<String, dynamic>> payload, bool valid) onChanged;
  final Map<String, dynamic>? initial; // 수정 시 프리필: key -> {values:[...], text}

  const RegistrationOptionSelector({
    super.key,
    required this.definitions,
    required this.onChanged,
    this.initial,
  });

  @override
  State<RegistrationOptionSelector> createState() =>
      _RegistrationOptionSelectorState();
}

class _RegistrationOptionSelectorState
    extends State<RegistrationOptionSelector> {
  // key -> {values: List<String>, text: String}
  final Map<String, Map<String, dynamic>> _sel = {};
  final Map<String, TextEditingController> _textCtrls = {};

  /// 앱 전체 강조색(코랄)과 같은 값. 여기만 다른 색이면 고른 것이 튀어 보인다.
  static const Color _accent = Color(0xFFD4603C);

  @override
  void initState() {
    super.initState();
    // 수정 프리필
    if (widget.initial != null) {
      widget.initial!.forEach((k, v) {
        _sel[k] = {
          'values':
              List<String>.from((v['values'] ?? []).map((e) => e.toString())),
          'text': (v['text'] ?? '').toString(),
        };
      });
    }
    for (final d in widget.definitions) {
      final key = d['key']?.toString() ?? '';
      final type = _effType(d);
      if (type == 'TEXT' || type == 'NUMBER') {
        _textCtrls[key] =
            TextEditingController(text: _sel[key]?['text']?.toString() ?? '');
      }
    }
    _applyRequiredChoices();
    // 초기 유효성 보고
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void dispose() {
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _entry(String key) => _sel.putIfAbsent(
      key, () => {'values': <String>[], 'text': '', 'quantities': <String, int>{}});

  /// 이 선택지를 몇 개까지 살 수 있는가. 1이면 수량 개념 없음(± 안 보임).
  /// 정의(JSON)가 정하므로 앱을 다시 배포하지 않고 DB만 고쳐 켤 수 있다.
  int _maxQty(Map<String, dynamic> def, Map<dynamic, dynamic> choice) {
    final v = choice['maxQuantity'] ?? def['maxQuantity'];
    if (v is num && v > 1) return v.toInt();
    return 1;
  }

  /// 지금 고른 수량. 고르지 않았거나 값이 없으면 1.
  int _qtyOf(String key, String value) {
    final q = _sel[key]?['quantities'];
    if (q is Map && q[value] is int) return q[value] as int;
    return 1;
  }

  void _setQty(String key, String value, int qty, int max) {
    if (qty < 1 || qty > max) return;
    setState(() {
      final e = _entry(key);
      final q = Map<String, int>.from(
          (e['quantities'] as Map?)?.cast<String, int>() ?? <String, int>{});
      q[value] = qty;
      e['quantities'] = q;
    });
    _report();
  }

  /// 이 정의를 실제로 어떤 입력으로 그릴지.
  ///
  /// 앱이 모르는 type(나중에 서버에서 새로 만든 것)이 오면 그리지 못해 화면이 빈다.
  /// 고를 선택지도 없으면 자유 입력으로 받아 최소한 신청은 끝낼 수 있게 한다.
  /// 덕분에 새 타입을 만들어도 구버전 앱이 조용히 망가지지 않는다.
  static const Set<String> _knownTypes = {
    'SINGLE_SELECT',
    'MULTI_SELECT',
    'TEXT',
    'NUMBER',
  };

  String _effType(Map<String, dynamic> d) {
    final raw = (d['type'] ?? 'SINGLE_SELECT').toString();
    if (_knownTypes.contains(raw)) return raw;
    final choices = (d['choices'] as List?) ?? const [];
    return choices.isEmpty ? 'TEXT' : 'SINGLE_SELECT';
  }

  /// choice에 required:true가 붙은 항목은 미리 선택해 둔다.
  /// (콩그레스 점심 4일처럼 "고르는 게 아니라 반드시 포함되는" 항목 — 웹과 동일 규칙)
  void _applyRequiredChoices() {
    for (final d in widget.definitions) {
      final key = d['key']?.toString() ?? '';
      final req = _requiredValues(d);
      if (req.isEmpty) continue;
      final e = _entry(key);
      final vals = (e['values'] as List).cast<String>();
      for (final v in req) {
        if (!vals.contains(v)) vals.add(v);
      }
      e['values'] = vals;
    }
  }

  /// 해당 정의에서 반드시 포함돼야 하는 choice 값 목록.
  List<String> _requiredValues(Map<String, dynamic> d) {
    final out = <String>[];
    for (final c in (d['choices'] as List? ?? [])) {
      if (c is Map && c['required'] == true) out.add(c['value'].toString());
    }
    return out;
  }

  bool _computeValid() {
    for (final d in widget.definitions) {
      final key = d['key']?.toString() ?? '';
      final type = _effType(d);
      final e = _sel[key];

      // choice 단위 필수 — 지정된 값이 전부 들어있어야 한다.
      // (기존엔 MULTI_SELECT에서 1개만 골라도 통과해, 점심 4일 필수가 지켜지지 않았다)
      final req = _requiredValues(d);
      if (req.isNotEmpty) {
        final vals = (e?['values'] as List?)?.cast<String>() ?? const <String>[];
        for (final v in req) {
          if (!vals.contains(v)) return false;
        }
      }

      if (d['required'] != true) continue;
      if (type == 'TEXT' || type == 'NUMBER') {
        if (e == null || (e['text']?.toString().trim().isEmpty ?? true)) {
          return false;
        }
      } else {
        if (e == null || (e['values'] as List).isEmpty) return false;
      }
    }
    return true;
  }

  void _report() {
    final payload = <Map<String, dynamic>>[];
    _sel.forEach((k, v) {
      // quantities는 고른 값에 대해서만 담는다. 서버는 없으면 1로 본다.
      final q = <String, int>{};
      final picked = (v['values'] as List?)?.cast<String>() ?? const <String>[];
      final raw = v['quantities'];
      if (raw is Map) {
        for (final value in picked) {
          final n = raw[value];
          if (n is int && n > 1) q[value] = n;
        }
      }
      payload.add({
        'key': k,
        'values': v['values'],
        'text': v['text'],
        'quantities': q,
      });
    });
    widget.onChanged(payload, _computeValid());
  }

  void _setSingle(String key, String value, bool required) {
    setState(() {
      final e = _entry(key);
      final cur = List<String>.from(e['values']);
      if (cur.contains(value) && !required) {
        e['values'] = <String>[];
      } else {
        e['values'] = <String>[value];
      }
    });
    _report();
  }

  void _toggleMulti(String key, String value) {
    setState(() {
      final e = _entry(key);
      final cur = List<String>.from(e['values']);
      if (cur.contains(value)) {
        cur.remove(value);
      } else {
        cur.add(value);
      }
      e['values'] = cur;
    });
    _report();
  }

  /// 금액 천단위 콤마 포맷 (예: 70000 → "70,000원")
  /// 수량 ± 버튼. 누를 수 없는 쪽은 흐리게 두어 왜 안 눌리는지 보이게 한다.
  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      // 눌리지 않는 상태에서도 탭을 받아서 삼킨다(null이면 부모로 흘러간다)
      onTap: enabled ? onTap : () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: enabled ? const Color(0xFFC9CED6) : const Color(0xFFE8EBEF),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF161B22) : const Color(0xFFC9CED6),
        ),
      ),
    );
  }

  /// 천 단위 구분 + '원'까지 붙여서 돌려준다.
  /// (참가신청 화면에도 같은 이름의 함수가 있는데 그쪽은 '원'을 안 붙인다 —
  ///  호출부에서 '원'을 또 쓰면 "15,000원원"이 된다)
  static String _formatWon(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    b.write('원');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.definitions.isEmpty) return const SizedBox.shrink();

    // group이 지정된 정의들(예: 숙박 공유/단독)은 하나의 표로 합쳐 렌더한다.
    // 같은 밤에 공유·단독을 동시에 고르는 사고를 UI에서 원천 차단하기 위함.
    final grouped = <String, List<Map<String, dynamic>>>{};
    final singles = <Map<String, dynamic>>[];
    for (final d in widget.definitions) {
      final g = d['group']?.toString();
      if (g != null && g.isNotEmpty) {
        grouped.putIfAbsent(g, () => []).add(d);
      } else {
        singles.add(d);
      }
    }
    // 그룹이 1개짜리면 묶을 이유가 없으니 일반 렌더로 되돌린다.
    grouped.removeWhere((k, v) {
      if (v.length < 2) { singles.insertAll(0, v); return true; }
      return false;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...grouped.entries.map((e) => _buildTieredGroup(e.value)),
        ...singles.map((d) {
        final key = d['key']?.toString() ?? '';
        final label = d['label']?.toString() ?? key;
        final type = _effType(d);
        final required = d['required'] == true;
        final description = d['description']?.toString();
        final choices = (d['choices'] as List?) ?? [];
        final vals = List<String>.from(_sel[key]?['values'] ?? []);

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  if (required)
                    const Text(' *', style: TextStyle(color: Colors.red)),
                  if (type == 'MULTI_SELECT') ...[
                    const SizedBox(width: 6),
                    Text('(복수 선택 가능)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (type == 'TEXT' || type == 'NUMBER' || choices.isEmpty)
                TextField(
                  controller: _textCtrls[key],
                  keyboardType: type == 'NUMBER'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: '입력해주세요',
                  ),
                  onChanged: (v) {
                    _entry(key)['text'] = v;
                    _report();
                  },
                )
              else
                // 한 줄에 하나. 왼쪽은 무엇인지, 오른쪽은 얼마인지.
                Column(
                  children: choices.map<Widget>((c) {
                    final cv = c['value']?.toString() ?? '';
                    final baseLabel = c['label']?.toString() ?? cv;
                    final ef = c['extraFee'];
                    final hasFee = ef is num && ef > 0;
                    final selected = vals.contains(cv);
                    // choice에 required:true면 "고르는 항목"이 아니라 "반드시 포함되는 항목"이다.
                    // (콩그레스 점심 4일) 자동 선택해 두고 탭으로 해제되지 않게 잠근다.
                    // 잠그지 않으면 화면상 해제는 되는데 제출에서만 막혀 사용자가 이유를 모른다.
                    final lockedRequired = c['required'] == true;
                    final multi = type == 'MULTI_SELECT';
                    // 수량을 살 수 있는 항목인가(정의가 정한다). 1이면 ± 가 안 붙는다.
                    final maxQty = _maxQty(d, c as Map);
                    final qty = _qtyOf(key, cv);
                    final showQty = selected && maxQty > 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: lockedRequired
                            ? null
                            : () {
                                if (multi) {
                                  _toggleMulti(key, cv);
                                } else {
                                  _setSingle(key, cv, required);
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(13, 13, 14, 13),
                          decoration: BoxDecoration(
                            color: selected
                                ? _accent.withValues(alpha: 0.07)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? _accent : const Color(0xFFE2E5EA),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                            children: [
                              // 복수 선택은 네모, 하나만 고르는 것은 동그라미.
                              // 모양만 봐도 여러 개를 골라도 되는지 알 수 있다.
                              Container(
                                width: 21,
                                height: 21,
                                decoration: BoxDecoration(
                                  shape: multi
                                      ? BoxShape.rectangle
                                      : BoxShape.circle,
                                  borderRadius:
                                      multi ? BorderRadius.circular(6) : null,
                                  color: selected ? _accent : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? _accent
                                        : const Color(0xFFC9CED6),
                                    width: 2,
                                  ),
                                ),
                                child: selected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      baseLabel,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: const Color(0xFF161B22),
                                      ),
                                    ),
                                    if (lockedRequired)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Text(
                                          '모든 참가자 포함',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF788595),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (hasFee)
                                Text(
                                  // 수량이 2 이상이면 소계를 보여준다. 단가는 아래 줄에 따로 적는다.
                                  '+${_formatWon(ef.toInt() * (showQty ? qty : 1))}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: selected
                                        ? _accent
                                        : const Color(0xFF161B22),
                                  ),
                                ),
                            ],
                          ),
                              if (showQty)
                                // 수량 줄에서 일어난 탭은 여기서 삼킨다.
                                // 그러지 않으면 카드의 "고르기/해제" 탭으로 흘러가
                                // 수량을 만지려다 항목이 통째로 빠진다.
                                GestureDetector(
                                  onTap: () {},
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                  padding: const EdgeInsets.only(top: 11),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 32),
                                      Expanded(
                                        child: Text(
                                          hasFee
                                              ? '개당 ${_formatWon(ef.toInt())}'
                                              : '수량',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF788595),
                                          ),
                                        ),
                                      ),
                                      _qtyButton(
                                        icon: Icons.remove,
                                        // 1에서 더 내리면 항목 자체를 뺀 것과 같아지므로 거기서 멈춘다.
                                        enabled: qty > 1,
                                        onTap: () =>
                                            _setQty(key, cv, qty - 1, maxQty),
                                      ),
                                      Container(
                                        width: 42,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF161B22),
                                          ),
                                        ),
                                      ),
                                      _qtyButton(
                                        icon: Icons.add,
                                        enabled: qty < maxQty,
                                        onTap: () =>
                                            _setQty(key, cv, qty + 1, maxQty),
                                      ),
                                    ],
                                  ),
                                ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (description != null && description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _linkifiedText(description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
            ],
          ),
        );
        }),
      ],
    );
  }

  /// 유형이 여러 개인 옵션 그룹(예: 숙박 공유/단독)을 "항목 한 줄 × 유형 선택"으로 렌더.
  /// 체크박스 10개 나열 대신 5줄로 줄고, 한 밤에 하나의 유형만 고를 수 있다.
  Widget _buildTieredGroup(List<Map<String, dynamic>> defs) {
    final groupLabel = defs.first['groupLabel']?.toString() ??
        defs.first['group']?.toString() ?? '선택';

    // 그룹 전체 소계 — 지금 얼마인지 바로 보이게
    int subtotal = 0;
    for (final d in defs) {
      final key = d['key']?.toString() ?? '';
      final vals = List<String>.from(_sel[key]?['values'] ?? []);
      for (final c in (d['choices'] as List? ?? [])) {
        if (c is Map && vals.contains(c['value'].toString())) {
          final ef = c['extraFee'];
          if (ef is num) subtotal += ef.toInt();
        }
      }
    }

    // 행(밤) 목록 — 첫 정의의 choices 순서를 기준으로 삼는다.
    final rows = (defs.first['choices'] as List? ?? []);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(groupLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              if (subtotal > 0)
                Text('소계 ${_formatWon(subtotal)}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _accent)),
            ],
          ),
          // 그룹 안내문 — 일반 옵션과 달리 그룹 렌더러엔 빠져 있어 추가.
          // (예: 숙박에서 "일행과 같은 방을 원하면 단체 접수를 이용" 같은 안내)
          if ((defs.first['description']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: _linkifiedText(
                defs.first['description'].toString(),
                style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey[700]),
              ),
            ),
          const SizedBox(height: 8),
          ...rows.map<Widget>((r) {
            final rv = (r as Map)['value'].toString();
            final rl = r['label']?.toString() ?? rv;
            // 이 행에서 현재 선택된 유형(정의 key). 아무것도 없으면 null = '없음'
            String? activeKey;
            for (final d in defs) {
              final k = d['key']?.toString() ?? '';
              if (List<String>.from(_sel[k]?['values'] ?? []).contains(rv)) {
                activeKey = k;
                break;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(rl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _tierChip(
                          label: '없음',
                          selected: activeKey == null,
                          onTap: () => _selectTier(defs, rv, null),
                        ),
                        ...defs.map((d) {
                          final k = d['key']?.toString() ?? '';
                          // 이 유형에서 이 행의 단가
                          int fee = 0;
                          for (final c in (d['choices'] as List? ?? [])) {
                            if (c is Map && c['value'].toString() == rv) {
                              final ef = c['extraFee'];
                              if (ef is num) fee = ef.toInt();
                            }
                          }
                          return _tierChip(
                            label: d['tierLabel']?.toString() ?? k,
                            sub: fee > 0 ? _formatWon(fee) : null,
                            selected: activeKey == k,
                            onTap: () => _selectTier(defs, rv, k),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tierChip({
    required String label,
    String? sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.10) : Colors.transparent,
            border: Border.all(
              color: selected ? _accent : Colors.grey.shade300,
              width: selected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _accent : Colors.grey[700],
                  )),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? _accent : Colors.grey[500],
                    )),
            ],
          ),
        ),
      ),
    );
  }

  /// 한 행(밤)의 유형을 바꾼다. tierKey=null 이면 '없음'.
  /// 같은 행이 여러 유형에 동시에 들어가지 않도록 나머지 유형에서 값을 뺀다.
  void _selectTier(List<Map<String, dynamic>> defs, String rowValue, String? tierKey) {
    setState(() {
      for (final d in defs) {
        final k = d['key']?.toString() ?? '';
        final e = _entry(k);
        final vals = (e['values'] as List).cast<String>();
        vals.remove(rowValue);
        if (k == tierKey) vals.add(rowValue);
        e['values'] = vals;
      }
    });
    _report();
  }
}
