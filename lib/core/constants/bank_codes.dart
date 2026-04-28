/// 토스페이먼츠 은행 코드 목록 (환불계좌 선택용)
/// 백엔드 BankCodeMapper와 코드 일치.
class BankCode {
  final String code;
  final String name;
  const BankCode(this.code, this.name);
}

const List<BankCode> kBankCodes = [
  BankCode('88', '신한은행'),
  BankCode('04', '국민은행'),
  BankCode('20', '우리은행'),
  BankCode('81', '하나은행'),
  BankCode('11', '농협은행'),
  BankCode('03', '기업은행'),
  BankCode('23', 'SC제일은행'),
  BankCode('27', '한국씨티은행'),
  BankCode('31', '대구은행'),
  BankCode('32', '부산은행'),
  BankCode('34', '광주은행'),
  BankCode('35', '제주은행'),
  BankCode('37', '전북은행'),
  BankCode('39', '경남은행'),
  BankCode('45', '새마을금고'),
  BankCode('48', '신협'),
  BankCode('50', '저축은행'),
  BankCode('64', '산림조합'),
  BankCode('71', '우체국'),
  BankCode('89', '케이뱅크'),
  BankCode('90', '카카오뱅크'),
  BankCode('92', '토스뱅크'),
  BankCode('02', '산업은행'),
];
