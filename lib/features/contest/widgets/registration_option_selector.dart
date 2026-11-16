import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/homepage_service.dart';

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
  final HomepageService _homepageService = HomepageService();
  // agreementCode -> 서류(본문·플래그). 한 번 불러오면 캐시.
  final Map<String, Map<String, dynamic>> _agreementDocs = {};

  /// 앱 전체 강조색(코랄)과 같은 값. 여기만 다른 색이면 고른 것이 튀어 보인다.
  static const Color _accent = Color(0xFFD4603C);

  @override
  void initState() {
    super.initState();
    // 수정 프리필
    if (widget.initial != null) {
      widget.initial!.forEach((k, v) {
        // 수량 프리필 — 유료옵션(숙박 등)을 그대로 되돌려 보내야 금액가드에 안 걸린다.
        final q = <String, int>{};
        final rawQ = v['quantities'];
        if (rawQ is Map) {
          rawQ.forEach((key, val) {
            final n = (val is num)
                ? val.toInt()
                : (int.tryParse(val.toString()) ?? 1);
            if (n > 1) q[key.toString()] = n;
          });
        }
        _sel[k] = {
          'values':
              List<String>.from((v['values'] ?? []).map((e) => e.toString())),
          'text': (v['text'] ?? '').toString(),
          'quantities': q,
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
    'AGREEMENT',
    'CONSENT',
  };

  // 커스텀 약관(CONSENT) 전문 펼침 상태 (옵션 key별)
  final Set<String> _consentExpanded = <String>{};

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

  /// 조건부 노출(showWhen): 다른 옵션의 현재 선택값에 따라 이 옵션을 보일지 결정.
  /// def['showWhen'] = {key:'shuttle', values:['yes']} → shuttle 응답이 yes일 때만 노출/필수.
  /// showWhen 없으면 항상 노출(기존 옵션 무영향). 웹 OptionFields.isShown과 동일 규칙.
  bool _isShown(Map<String, dynamic> d) {
    final cond = d['showWhen'];
    if (cond is! Map) return true;
    final depKey = cond['key']?.toString();
    if (depKey == null || depKey.isEmpty) return true;
    final want = ((cond['values'] as List?) ?? const [])
        .map((e) => e.toString())
        .toSet();
    final depVals = ((_sel[depKey]?['values'] as List?) ?? const [])
        .map((e) => e.toString());
    for (final v in depVals) {
      if (want.contains(v)) return true;
    }
    return false;
  }

  bool _computeValid() {
    for (final d in widget.definitions) {
      if (!_isShown(d)) continue; // 조건부 숨김 → 필수 검증 제외
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
    // 조건부(showWhen) 숨김 옵션의 값은 제출에서 제외 — 숨겨지면 비운다(웹과 동일).
    for (final d in widget.definitions) {
      if (_isShown(d)) continue;
      final key = d['key']?.toString() ?? '';
      final e = _sel[key];
      if (e != null) {
        e['values'] = <String>[];
        e['text'] = '';
      }
    }
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
      final m = <String, dynamic>{
        'key': k,
        'values': v['values'],
        'text': v['text'],
        'quantities': q,
      };
      // 서약서(AGREEMENT) 전용 — 백엔드 saveAnswers가 decl/guardian/agreed를 읽어 증빙 생성
      if (v['decl'] != null) m['decl'] = v['decl'];
      if (v['guardian'] != null) m['guardian'] = v['guardian'];
      if (v['agreed'] != null) m['agreed'] = v['agreed'];
      // 서약서 작성내용(JSON) — 서버 validateAgreementContent가 필수 검증, saveAnswers가 그대로 보관
      if (v['form'] != null) m['form'] = v['form'];
      payload.add(m);
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
        ...singles.where(_isShown).map((d) {
        final key = d['key']?.toString() ?? '';
        final label = d['label']?.toString() ?? key;
        final type = _effType(d);
        final required = d['required'] == true;
        final description = d['description']?.toString();
        final choices = (d['choices'] as List?) ?? [];
        final vals = List<String>.from(_sel[key]?['values'] ?? []);

        // 서약/동의 서류 — 전용 버튼+다이얼로그로 렌더
        if (type == 'AGREEMENT') return _buildAgreement(d);
        if (type == 'CONSENT') return _buildConsent(d);

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

  /// 서약/동의 서류(type=AGREEMENT) — 버튼(상태) + 탭 시 전체화면 동의 다이얼로그.
  Widget _buildAgreement(Map<String, dynamic> d) {
    final key = d['key']?.toString() ?? '';
    final label = d['label']?.toString() ?? '서약서';
    final required = d['required'] == true;
    final description = d['description']?.toString();
    final agreed = (_sel[key]?['values'] as List?)?.isNotEmpty ?? false;
    final decl = _sel[key]?['decl']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (required) const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _openAgreement(d),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
              decoration: BoxDecoration(
                color: agreed ? const Color(0x1416A34A) : const Color(0x14D4603C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: agreed ? const Color(0xFF16A34A) : _accent,
                  width: agreed ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(agreed ? Icons.check_circle : Icons.description_outlined,
                      size: 20, color: agreed ? const Color(0xFF15803D) : _accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      agreed
                          ? '동의 완료${decl != null ? ' (처분이력 $decl)' : ''}'
                          : '서약서 보기 및 동의하기',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: agreed ? const Color(0xFF15803D) : _accent,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
          if (!agreed && required)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('신청하려면 동의가 필요합니다',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
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
  }

  /// 커스텀 약관 동의(type=CONSENT) — 제목 + 약관 전문(body) 펼침 + 필수 동의 체크(인라인).
  ///  서류코드 없이 관리자가 적은 전문을 그 자리에서 보여주고 체크로 동의받는다. 웹 ConsentField와 동일 동작.
  Widget _buildConsent(Map<String, dynamic> d) {
    final key = d['key']?.toString() ?? '';
    final label = d['label']?.toString() ?? '약관 동의';
    final required = d['required'] == true;
    final body = d['body']?.toString() ?? '';
    final description = d['description']?.toString();
    final agreed = _sel[key]?['agreed'] == true;
    final expanded = _consentExpanded.contains(key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              if (required) const Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _linkifiedText(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() {
                if (expanded) {
                  _consentExpanded.remove(key);
                } else {
                  _consentExpanded.add(key);
                }
              }),
              child: Text(
                expanded ? '약관 전문 닫기 ▲' : '약관 전문 보기 ▼',
                style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
              ),
            ),
            if (expanded)
              Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxHeight: 240),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: _linkifiedText(body, style: const TextStyle(fontSize: 13, height: 1.6)),
                ),
              ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _setConsent(key, !agreed),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: agreed ? const Color(0x1416A34A) : const Color(0x14D4603C),
                border: Border.all(color: agreed ? const Color(0xFF16A34A) : _accent, width: agreed ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: agreed,
                      onChanged: (v) => _setConsent(key, v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('위 약관에 동의합니다',
                        style: TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          if (!agreed && required)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('신청하려면 동의가 필요합니다', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  /// CONSENT 동의/해제 — values:['AGREED']+agreed 마커를 세팅(서약서와 동일, 백엔드가 그대로 저장·검증).
  void _setConsent(String key, bool agreed) {
    setState(() {
      final e = _entry(key);
      e['values'] = agreed ? <String>['AGREED'] : <String>[];
      e['agreed'] = agreed;
    });
    _report();
  }

  /// 서약 서류를 받아 전체화면 다이얼로그로 보여주고 동의를 받는다.
  Future<void> _openAgreement(Map<String, dynamic> d) async {
    final key = d['key']?.toString() ?? '';
    final code = d['agreementCode']?.toString() ?? '';
    if (code.isEmpty) return;

    // 서류 로드(캐시)
    Map<String, dynamic>? doc = _agreementDocs[code];
    if (doc == null) {
      doc = await _homepageService.getAgreementDocument(code);
      if (doc != null) _agreementDocs[code] = doc;
    }
    if (!mounted) return;
    if (doc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서약서를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    final title = doc['title']?.toString() ?? d['label']?.toString() ?? '서약서';
    final body = doc['body']?.toString() ?? '';
    final downloadUrl = doc['downloadUrl']?.toString();
    final requireDecl = doc['requireDecl'] == true;
    final requireGuardian = doc['requireGuardian'] == true;
    final blockOnYes = doc['blockOnYes'] == true;

    final version = doc['version']?.toString();

    // 기존 작성내용 프리필 — 이 세션의 form(Map) 우선, 없으면 저장된 text(formJSON)를 파싱
    Map<String, dynamic>? initialForm;
    final existingForm = _sel[key]?['form'];
    if (existingForm is Map) {
      initialForm = Map<String, dynamic>.from(existingForm);
    } else {
      final t = _sel[key]?['text']?.toString() ?? '';
      if (t.trimLeft().startsWith('{')) {
        try {
          initialForm = Map<String, dynamic>.from(jsonDecode(t) as Map);
        } catch (_) {/* text가 서약서 JSON이 아니면 무시 */}
      }
    }

    // overlay(showDialog)는 Flutter Web에서 '첫 레이아웃 전 히트테스트'로 no-size assert가 난다.
    //  → 전체화면 라우트로 띄운다. 화면을 꽉 채워 항상 사이즈가 잡히고, 긴 양식 입력에도 적합하다.
    //  웹(AgreementConsent)과 동일한 form(성명·소속·처분이력 상세·확인자·개인정보동의)을 받아 보낸다.
    final form = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        fullscreenDialog: true,
        builder: (_) => _AgreementFormPage(
          title: title,
          body: body,
          downloadUrl: downloadUrl,
          requireDecl: requireDecl,
          requireGuardian: requireGuardian,
          blockOnYes: blockOnYes,
          documentVersion: version,
          accent: _accent,
          initialForm: initialForm,
        ),
      ),
    );
    if (!mounted || form == null) return;

    setState(() {
      final e = _entry(key);
      e['form'] = form;
      e['values'] = <String>['AGREED'];
      e['agreed'] = true;
      final decl = form['decl']?.toString();
      e['decl'] = requireDecl ? decl : null;
      e['guardian'] = requireGuardian ? (form['confirmerSigned'] == true) : null;
      // 사람이 읽는 요약(명단/표시용) — 실제 검증 데이터는 form(JSON)에 담겨 서버로 간다.
      final parts = <String>[];
      final an = form['applicantName']?.toString();
      if (an != null && an.isNotEmpty) parts.add(an);
      if (requireDecl && decl != null && decl.isNotEmpty) parts.add('처분이력 $decl');
      if (requireGuardian && form['confirmerSigned'] == true) {
        final cn = form['confirmerName']?.toString() ?? '';
        final cr = form['confirmerRelation']?.toString() ?? '';
        parts.add('확인자 $cn($cr)');
      }
      e['text'] = parts.isEmpty ? '동의' : '동의 · ${parts.join(' · ')}';
    });
    _report();
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

// 공식 양식 — 처분결과(조치)와 제한기간. 웹 AgreementConsent.MEASURES와 동일.
const List<String> _kMeasures = [
  '1호(서면사과)·2호(접촉·보복금지) — 3개월',
  '3호(교내봉사) — 5개월',
  '4호(사회봉사)·5호(특별교육) — 8개월',
  '6호(출석정지)·7호(학급교체) — 10개월',
  '8호(전학) — 12개월',
  '9호(퇴학) — 성폭력 10년 / 그 외 5년',
];

// 확인자 관계 — 웹 RELATIONS와 동일(바둑 도장 특성상 지도자/사범 포함).
const List<String> _kRelations = ['부', '모', '조부', '조모', '지도자', '사범', '기타'];

/// 서약/동의 서류(type=AGREEMENT) 작성 전체화면 — 웹 AgreementConsent와 동일한 양식.
///  성명·소속팀·학교, 처분이력(무/유 + "유"면 처분결과·처분일·중복일수 다건),
///  본인서약, (requireGuardian)확인자 성명/구분/동의, 개인정보 제3자제공 동의.
///  작성 완료 시 Navigator.pop(form)으로 form(Map) 반환, 취소 시 null.
///  overlay(showDialog)가 아니라 전체화면 라우트라 Flutter Web의 'no size' 히트테스트 레이스가 없다.
class _AgreementFormPage extends StatefulWidget {
  final String title;
  final String body;
  final String? downloadUrl;
  final bool requireDecl;
  final bool requireGuardian;
  final bool blockOnYes;
  final String? documentVersion;
  final Color accent;
  final Map<String, dynamic>? initialForm;

  const _AgreementFormPage({
    required this.title,
    required this.body,
    required this.downloadUrl,
    required this.requireDecl,
    required this.requireGuardian,
    required this.blockOnYes,
    required this.documentVersion,
    required this.accent,
    required this.initialForm,
  });

  @override
  State<_AgreementFormPage> createState() => _AgreementFormPageState();
}

class _AgreementFormPageState extends State<_AgreementFormPage> {
  final _applicant = TextEditingController();
  final _school = TextEditingController();
  final _team = TextEditingController();
  final _guardianName = TextEditingController();
  final _guardianEtc = TextEditingController();

  String _decl = '';
  // 처분 목록 — 각 {measure, punishedAt(yyyy-MM-dd), overlapDays}
  final List<Map<String, String>> _declItems = [];
  bool _selfAgree = false;
  String _guardianRelation = '';
  bool _guardianAgree = false;
  bool _privacyAgree = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialForm;
    if (f != null) {
      _applicant.text = (f['applicantName'] ?? '').toString();
      _school.text = (f['school'] ?? '').toString();
      _team.text = (f['teamName'] ?? '').toString();
      _decl = (f['decl'] ?? '').toString();
      final items = f['declItems'];
      if (items is List) {
        for (final it in items) {
          if (it is Map) {
            _declItems.add({
              'measure': (it['measure'] ?? '').toString(),
              'punishedAt': (it['punishedAt'] ?? '').toString(),
              'overlapDays': (it['overlapDays'] ?? '').toString(),
            });
          }
        }
      }
      _selfAgree = f['selfSigned'] == true;
      _guardianName.text = (f['confirmerName'] ?? '').toString();
      final rel = (f['confirmerRelation'] ?? '').toString();
      if (rel.isNotEmpty && !_kRelations.contains(rel)) {
        _guardianRelation = '기타';
        _guardianEtc.text = rel;
      } else {
        _guardianRelation = rel;
      }
      _guardianAgree = f['confirmerSigned'] == true;
      _privacyAgree = f['privacyAgree'] == true;
    }
    if (_declItems.isEmpty) {
      _declItems.add({'measure': '', 'punishedAt': '', 'overlapDays': ''});
    }
  }

  @override
  void dispose() {
    _applicant.dispose();
    _school.dispose();
    _team.dispose();
    _guardianName.dispose();
    _guardianEtc.dispose();
    super.dispose();
  }

  bool get _isBlocked => widget.requireDecl && widget.blockOnYes && _decl == '유';

  bool get _canConfirm {
    if (_applicant.text.trim().isEmpty) return false;
    if (_school.text.trim().isEmpty) return false;
    if (widget.requireDecl && _decl != '무' && _decl != '유') return false;
    if (_decl == '유' && !_isBlocked) {
      if (_declItems.isEmpty) return false;
      for (final it in _declItems) {
        if ((it['measure'] ?? '').isEmpty || (it['punishedAt'] ?? '').trim().isEmpty) {
          return false;
        }
      }
    }
    if (!_selfAgree) return false;
    if (!_privacyAgree) return false;
    if (widget.requireGuardian) {
      if (_guardianName.text.trim().isEmpty) return false;
      if (_guardianRelation.isEmpty) return false;
      if (_guardianRelation == '기타' && _guardianEtc.text.trim().isEmpty) return false;
      if (!_guardianAgree) return false;
    }
    if (_isBlocked) return false;
    return true;
  }

  void _submit() {
    if (!_canConfirm) return;
    final rd = widget.requireDecl;
    final rg = widget.requireGuardian;
    final form = <String, dynamic>{
      'applicantName': _applicant.text.trim(),
      'school': _school.text.trim(),
      'teamName': _team.text.trim().isEmpty ? null : _team.text.trim(),
      'decl': rd ? _decl : null,
      'declItems': (rd && _decl == '유')
          ? _declItems
              .map((it) => {
                    'measure': (it['measure'] ?? '').isEmpty ? null : it['measure'],
                    'punishedAt': (it['punishedAt'] ?? '').trim().isEmpty ? null : it['punishedAt']!.trim(),
                    'overlapDays': (it['overlapDays'] ?? '').trim().isEmpty ? null : it['overlapDays']!.trim(),
                  })
              .toList()
          : null,
      'confirmerName': rg ? _guardianName.text.trim() : null,
      'confirmerRelation': rg ? (_guardianRelation == '기타' ? _guardianEtc.text.trim() : _guardianRelation) : null,
      'selfSigned': true,
      'confirmerSigned': rg ? _guardianAgree : null,
      'privacyAgree': true,
      'signedAt': DateTime.now().toUtc().toIso8601String(),
      'documentVersion': widget.documentVersion,
    };
    Navigator.of(context).pop(form);
  }

  Future<void> _pickDate(int i) async {
    final now = DateTime.now();
    DateTime initial = now;
    final cur = _declItems[i]['punishedAt'] ?? '';
    if (cur.isNotEmpty) {
      final p = DateTime.tryParse(cur);
      if (p != null) initial = p;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      final s = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() => _declItems[i]['punishedAt'] = s);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        border: const OutlineInputBorder(),
      );

  Widget _label(String text, {bool req = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 5, top: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF374151)),
            children: [
              TextSpan(text: text),
              if (req) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFD32F2F))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rd = widget.requireDecl;
    final rg = widget.requireGuardian;
    final accent = widget.accent;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '아래 서약 내용을 확인하신 뒤 양식을 작성해 주세요. 작성 후 “서약하고 제출”을 누르면 전자서명으로 제출되며, 별도 우편·서면 제출은 필요 없습니다.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF1E40AF), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(widget.body, style: const TextStyle(fontSize: 14, height: 1.7, color: Color(0xFF222222))),
                  if (widget.downloadUrl != null && widget.downloadUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: () => launchUrl(Uri.parse(widget.downloadUrl!), mode: LaunchMode.externalApplication),
                        child: const Text('📎 서약서 양식 내려받기',
                            style: TextStyle(color: Color(0xFF2563EB), decoration: TextDecoration.underline)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 14),
                  const Text('▣ 서약서 작성',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF111111))),
                  const SizedBox(height: 12),
                  _label('선수 성명', req: true),
                  TextField(controller: _applicant, decoration: _dec('예: 홍길동'), onChanged: (_) => setState(() {})),
                  const SizedBox(height: 12),
                  _label('소속팀명 (바둑도장·클럽 등)'),
                  TextField(controller: _team, decoration: _dec('예: ○○바둑도장 (없으면 비움)')),
                  const SizedBox(height: 12),
                  _label('학교명 / 소속', req: true),
                  TextField(controller: _school, decoration: _dec('예: 서울 ○○초 3학년'), onChanged: (_) => setState(() {})),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('재학생이 아니면(홈스쿨링·학교밖청소년·검정고시 등) 해당 내용을 적어주세요.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ),
                  if (rd) ...[
                    const SizedBox(height: 14),
                    _label('학교폭력 처분이력', req: true),
                    Row(
                      children: [
                        _declRadio('무', '없음(무)'),
                        const SizedBox(width: 10),
                        _declRadio('유', '있음(유)'),
                      ],
                    ),
                    if (_isBlocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                            '“있음(유)”은 제한기간과 대회기간이 겹쳐 참가가 제한되는 경우입니다. 온라인 접수가 불가하니 주최 측에 문의해 주세요.',
                            style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    if (!_isBlocked && _decl == '유') _buildDeclItems(),
                  ],
                  const SizedBox(height: 14),
                  _consentTile(
                    value: _selfAgree,
                    onChanged: (v) => setState(() => _selfAgree = v),
                    bg: const Color(0xFFF8FAFC),
                    border: const Color(0xFFE2E8F0),
                    text: '[선수 본인 서약] 위 서약 내용을 모두 확인하였으며, 기재한 내용이 사실임을 서약합니다.',
                  ),
                  if (rg) ...[
                    const SizedBox(height: 12),
                    _label('확인자 성명', req: true),
                    TextField(controller: _guardianName, decoration: _dec('학부모 또는 지도자'), onChanged: (_) => setState(() {})),
                    const SizedBox(height: 10),
                    _label('구분', req: true),
                    DropdownButtonFormField<String>(
                      value: _guardianRelation.isEmpty ? null : _guardianRelation,
                      isDense: true,
                      decoration: _dec('선택'),
                      items: _kRelations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _guardianRelation = v ?? ''),
                    ),
                    if (_guardianRelation == '기타')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextField(
                            controller: _guardianEtc,
                            decoration: _dec('관계 직접 입력 (예: 삼촌, 코치)'),
                            onChanged: (_) => setState(() {})),
                      ),
                    const SizedBox(height: 12),
                    _consentTile(
                      value: _guardianAgree,
                      onChanged: (v) => setState(() => _guardianAgree = v),
                      bg: const Color(0xFFF8FAFC),
                      border: const Color(0xFFE2E8F0),
                      text: '[확인자 동의] 학부모(법정대리인) 또는 지도자로서 위 서약 내용에 동의합니다.',
                    ),
                  ],
                  const SizedBox(height: 12),
                  _consentTile(
                    value: _privacyAgree,
                    onChanged: (v) => setState(() => _privacyAgree = v),
                    bg: const Color(0xFFFFF7ED),
                    border: const Color(0xFFFED7AA),
                    text: '[개인정보 수집·이용 및 제3자 제공 동의] 위 서약 내용(학교폭력 처분이력 포함)을 대회 참가자격 확인 목적으로 수집·이용하고, 주최·주관 단체(대한바둑협회 등)에 제출하는 데 동의합니다. (미성년자는 보호자 동의 포함)',
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
                      onPressed: _canConfirm ? _submit : null,
                      child: const Text('서약하고 제출'),
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

  Widget _declRadio(String val, String label) {
    return InkWell(
      onTap: () => setState(() => _decl = val),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: val,
            groupValue: _decl,
            onChanged: (v) => setState(() => _decl = v ?? ''),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDeclItems() {
    final rows = <Widget>[];
    rows.add(const Padding(
      padding: EdgeInsets.only(top: 10, bottom: 4),
      child: Text('※ “있음(유)”는 아래를 기재하고, 서명한 서약서 원본을 대회 당일 지참·제출해 주세요.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C), height: 1.5)),
    ));
    for (int i = 0; i < _declItems.length; i++) {
      final it = _declItems[i];
      rows.add(Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFECACA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('처분 ${i + 1}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                if (_declItems.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _declItems.removeAt(i)),
                    child: const Text('삭제', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _label('처분결과', req: true),
            DropdownButtonFormField<String>(
              value: (it['measure'] ?? '').isEmpty ? null : it['measure'],
              isDense: true,
              isExpanded: true,
              decoration: _dec('선택'),
              items: _kMeasures
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => it['measure'] = v ?? ''),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('처분일', req: true),
                      OutlinedButton(
                        onPressed: () => _pickDate(i),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text((it['punishedAt'] ?? '').isEmpty ? '날짜 선택' : it['punishedAt']!,
                              style: TextStyle(color: (it['punishedAt'] ?? '').isEmpty ? Colors.grey : Colors.black87)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('중복 일수'),
                      TextFormField(
                        initialValue: it['overlapDays'] ?? '',
                        decoration: _dec('예: 30일'),
                        onChanged: (v) => it['overlapDays'] = v,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
    }
    rows.add(Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: () => setState(() => _declItems.add({'measure': '', 'punishedAt': '', 'overlapDays': ''})),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('처분 추가'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
      ),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _consentTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color bg,
    required Color border,
    required String text,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5))),
          ],
        ),
      ),
    );
  }
}
