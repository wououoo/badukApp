import 'package:flutter/material.dart';

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

  static const Color _accent = Color(0xFF5B4D9B);

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
      final type = (d['type'] ?? 'SINGLE_SELECT').toString();
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

  Map<String, dynamic> _entry(String key) =>
      _sel.putIfAbsent(key, () => {'values': <String>[], 'text': ''});

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
      final type = (d['type'] ?? 'SINGLE_SELECT').toString();
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
      payload.add({'key': k, 'values': v['values'], 'text': v['text']});
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
        final type = (d['type'] ?? 'SINGLE_SELECT').toString();
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
              if (type == 'TEXT' || type == 'NUMBER')
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: choices.map<Widget>((c) {
                    final cv = c['value']?.toString() ?? '';
                    final baseLabel = c['label']?.toString() ?? cv;
                    // 유료옵션이면 선택지 라벨에 가격 표시 (예: "1/23 밤  +70,000원")
                    final ef = c['extraFee'];
                    final hasFee = ef is num && ef > 0;
                    final cl = hasFee ? '$baseLabel  +${_formatWon(ef.toInt())}' : baseLabel;
                    final selected = vals.contains(cv);
                    // choice에 required:true면 "고르는 항목"이 아니라 "반드시 포함되는 항목"이다.
                    // (콩그레스 점심 4일) 자동 선택해 두고 탭으로 해제되지 않게 잠근다.
                    // 잠그지 않으면 화면상 해제는 되는데 제출에서만 막혀 사용자가 이유를 모른다.
                    final lockedRequired = c['required'] == true;
                    return ChoiceChip(
                      label: Text(lockedRequired ? '$cl  (필수)' : cl),
                      selected: selected,
                      onSelected: lockedRequired
                          ? null
                          : (_) {
                        if (type == 'MULTI_SELECT') {
                          _toggleMulti(key, cv);
                        } else {
                          _setSingle(key, cv, required);
                        }
                      },
                      selectedColor: _accent,
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: selected ? _accent : const Color(0xFFD8DAE0),
                          width: 1.5,
                        ),
                      ),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              if (description != null && description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(description,
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
              child: Text(
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
            color: selected ? _accent.withOpacity(0.10) : Colors.transparent,
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
