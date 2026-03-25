import 'package:flutter/material.dart';

/// 기력 레벨 선택 위젯 (동호인용)
///
/// level 10-36 을 표시명으로 변환:
/// - 아마 9단(10) ~ 아마 1단(18)
/// - 1급(19) ~ 18급(36)
///
/// 9단~18급 선택 가능 (동호인 대회용)
class LevelSelector extends StatefulWidget {
  final int? initialLevel;
  final ValueChanged<int> onLevelChanged;

  const LevelSelector({
    super.key,
    this.initialLevel,
    required this.onLevelChanged,
  });

  @override
  State<LevelSelector> createState() => _LevelSelectorState();
}

class _LevelSelectorState extends State<LevelSelector> {
  String? _category; // null이면 미선택 상태
  String? _rank;

  static const List<String> _categories = ['아마', '급'];

  static const List<String> _amaRanks = ['9단', '8단', '7단', '6단', '5단', '4단', '3단', '2단', '1단'];
  static const List<String> _gupRanks = [
    '1급', '2급', '3급', '4급', '5급', '6급', '7급', '8급', '9급', '10급',
    '11급', '12급', '13급', '14급', '15급', '16급', '17급', '18급',
  ]; // 18급까지만 (동호인용)

  bool get _isSelected => _category != null && _rank != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialLevel != null) {
      _initFromLevel(widget.initialLevel!);
    }
    // initialLevel이 null이면 미선택 상태 유지
  }

  void _initFromLevel(int level) {
    if (level >= 10 && level <= 18) {
      _category = '아마';
      _rank = _amaRanks[level - 10];
    } else if (level >= 19 && level <= 36) {
      _category = '급';
      _rank = _gupRanks[level - 19];
    }
    // 범위 밖이면 미선택 상태 유지
  }

  int _calculateLevel() {
    if (_category == '아마' && _rank != null) {
      return _amaRanks.indexOf(_rank!) + 10;
    } else if (_category == '급' && _rank != null) {
      return _gupRanks.indexOf(_rank!) + 19;
    }
    return -1;
  }

  List<String> _getCurrentRanks() {
    switch (_category) {
      case '아마':
        return _amaRanks;
      case '급':
        return _gupRanks;
      default:
        return _amaRanks;
    }
  }

  void _onCategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _category = value;
      final ranks = _getCurrentRanks();
      _rank = ranks[0];
    });
    widget.onLevelChanged(_calculateLevel());
  }

  void _onRankChanged(String? value) {
    if (value == null) return;
    setState(() {
      _rank = value;
    });
    widget.onLevelChanged(_calculateLevel());
  }

  @override
  Widget build(BuildContext context) {
    final ranks = _category != null ? _getCurrentRanks() : _amaRanks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기력을 선택해주세요',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _category,
                items: _categories,
                onChanged: _onCategoryChanged,
                hint: '구분',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                value: _rank,
                items: ranks,
                onChanged: _onRankChanged,
                hint: '단/급',
                enabled: _category != null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _isSelected ? _getLevelDescription() : '기력을 선택하면 대진표 배정에 반영됩니다',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    bool enabled = true,
  }) {
    final effectiveValue = (value != null && items.contains(value)) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? Colors.grey[300]! : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
        color: enabled ? null : Colors.grey[50],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(color: Colors.grey[500])),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  String _getLevelDescription() {
    final level = _calculateLevel();
    if (_category == '아마') {
      return '아마추어 $_rank (레벨: $level)';
    } else {
      return '$_rank (레벨: $level)';
    }
  }
}

/// 기력 레벨을 표시명으로 변환 (동호인용: 아마단~18급)
String levelToDisplayName(int level) {
  if (level >= 10 && level <= 18) {
    return '아마 ${19 - level}단';
  } else if (level >= 19 && level <= 36) {
    return '${level - 18}급';
  }
  return '알 수 없음';
}

/// 표시명을 기력 레벨로 변환 (동호인용: 아마단~18급)
int? displayNameToLevel(String displayName) {
  final amaMatch = RegExp(r'아마\s*(\d)단').firstMatch(displayName);
  if (amaMatch != null) {
    final dan = int.parse(amaMatch.group(1)!);
    return 19 - dan;
  }

  final gupMatch = RegExp(r'(\d+)급').firstMatch(displayName);
  if (gupMatch != null) {
    final gup = int.parse(gupMatch.group(1)!);
    if (gup >= 1 && gup <= 18) {
      return gup + 18;
    }
  }

  return null;
}
