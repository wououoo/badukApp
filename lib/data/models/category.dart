class Category {
  final int id;
  final String name;
  final String? description;
  final int? fee; // 참가비
  final String? feeDescription;
  final int? currentCount; // 현재 신청자 수
  final int? maxCount; // 최대 인원

  Category({
    required this.id,
    required this.name,
    this.description,
    this.fee,
    this.feeDescription,
    this.currentCount,
    this.maxCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? json['categoryId'] ?? 0,
      name: json['name'] ?? json['categoryName'] ?? '',
      description: json['description'],
      fee: json['fee'] ?? json['participationFee'],
      feeDescription: json['feeDescription'],
      currentCount: json['currentCount'],
      maxCount: json['maxCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fee': fee,
      'feeDescription': feeDescription,
      'currentCount': currentCount,
      'maxCount': maxCount,
    };
  }

  bool get isFull => maxCount != null && currentCount != null && currentCount! >= maxCount!;

  String get feeText {
    if (fee == null || fee == 0) return '무료';
    return '${_formatNumber(fee!)}원';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
