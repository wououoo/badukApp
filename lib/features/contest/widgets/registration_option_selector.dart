import 'package:flutter/material.dart';

/// 신청 추가 옵션(티셔츠 사이즈 등) 선택 위젯.
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

  bool _computeValid() {
    for (final d in widget.definitions) {
      if (d['required'] != true) continue;
      final key = d['key']?.toString() ?? '';
      final type = (d['type'] ?? 'SINGLE_SELECT').toString();
      final e = _sel[key];
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

  @override
  Widget build(BuildContext context) {
    if (widget.definitions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.definitions.map((d) {
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
                    final cl = c['label']?.toString() ?? cv;
                    final selected = vals.contains(cv);
                    return ChoiceChip(
                      label: Text(cl),
                      selected: selected,
                      onSelected: (_) {
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
      }).toList(),
    );
  }
}
