# Flutter/Dart 문법 가이드

## 1. 변수 선언

```dart
// 기본 타입
String name = '홍길동';
int age = 25;
double height = 175.5;
bool isActive = true;

// 타입 추론
var score = 100;          // int로 추론
var message = 'hello';    // String으로 추론

// 상수
final userId = 123;       // 런타임에 한 번만 할당
const PI = 3.14159;       // 컴파일 타임 상수

// Nullable (null 가능)
String? nickname;         // null 가능
String name = '';         // null 불가 (기본)
```

---

## 2. Null 처리 (중요!)

```dart
String? name;   // null일 수 있음

// null 체크 방법들
name!                    // null 아님 확신 (null이면 에러!)
name ?? '기본값'          // null이면 기본값 사용
name?.length             // null이면 그냥 null 반환
name?.length ?? 0        // null이면 0 반환

// 조건문에서
if (name != null) {
  print(name.length);    // 여기선 non-null로 인식
}

// 실제 예시
String? getUserName() => null;

void main() {
  String? name = getUserName();

  // 방법 1: null 체크
  if (name != null) {
    print('이름: $name');
  }

  // 방법 2: 기본값
  print('이름: ${name ?? "익명"}');

  // 방법 3: 확신 (위험!)
  // print(name!);  // null이면 에러 발생
}
```

---

## 3. 클래스

### 기본 클래스
```dart
class User {
  final int id;
  final String name;
  String? email;          // nullable

  // 생성자 (this.로 바로 할당)
  User({
    required this.id,     // 필수 파라미터
    required this.name,
    this.email,           // 선택 파라미터
  });
}

// 사용
var user = User(id: 1, name: '홍길동');
var user2 = User(id: 2, name: '김철수', email: 'kim@test.com');
```

### Getter / Setter
```dart
class Person {
  final String firstName;
  final String lastName;

  Person({required this.firstName, required this.lastName});

  // Getter (읽기 전용 계산 속성)
  String get fullName => '$firstName $lastName';

  // 축약형
  int get nameLength => fullName.length;
}

// 사용
var person = Person(firstName: '길동', lastName: '홍');
print(person.fullName);    // '길동 홍'
print(person.nameLength);  // 4
```

### Factory 생성자 (JSON 파싱)
```dart
class Contest {
  final int id;
  final String name;
  final String? venue;

  Contest({
    required this.id,
    required this.name,
    this.venue,
  });

  // JSON → 객체 변환
  factory Contest.fromJson(Map<String, dynamic> json) {
    return Contest(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      venue: json['venue'],
    );
  }

  // 객체 → JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'venue': venue,
    };
  }
}

// 사용
var json = {'id': 1, 'name': '바둑대회', 'venue': '서울'};
var contest = Contest.fromJson(json);
```

---

## 4. 컬렉션 (List, Map)

### List
```dart
// 생성
List<String> names = ['홍길동', '김철수', '이영희'];
var numbers = [1, 2, 3, 4, 5];

// 접근
print(names[0]);           // '홍길동'
print(names.first);        // '홍길동'
print(names.last);         // '이영희'
print(names.length);       // 3

// 추가/삭제
names.add('박지민');
names.remove('김철수');

// 변환 (map)
var upperNames = names.map((n) => n.toUpperCase()).toList();

// 필터 (where)
var longNames = names.where((n) => n.length > 2).toList();

// 찾기
var found = names.firstWhere((n) => n.startsWith('홍'), orElse: () => '없음');

// 존재 여부
bool hasKim = names.any((n) => n.contains('김'));
bool allLong = names.every((n) => n.length >= 2);
```

### Map
```dart
// 생성
Map<String, int> scores = {
  '홍길동': 95,
  '김철수': 87,
  '이영희': 92,
};

// 접근
print(scores['홍길동']);     // 95
print(scores['없는키']);     // null

// 추가/수정
scores['박지민'] = 88;

// 반복
scores.forEach((name, score) {
  print('$name: $score점');
});

// entries로 반복
for (var entry in scores.entries) {
  print('${entry.key}: ${entry.value}');
}
```

---

## 5. 함수

### 기본 함수
```dart
// 반환 타입 명시
int add(int a, int b) {
  return a + b;
}

// 화살표 함수 (한 줄)
int multiply(int a, int b) => a * b;

// void (반환 없음)
void printHello() {
  print('Hello');
}

// Optional 파라미터
void greet(String name, [String? title]) {
  print('안녕하세요 ${title ?? ''}$name님');
}

// Named 파라미터
void createUser({
  required String name,
  required int age,
  String? email,
}) {
  print('$name, $age, $email');
}

// 사용
createUser(name: '홍길동', age: 25);
createUser(name: '김철수', age: 30, email: 'kim@test.com');
```

---

## 6. 비동기 (async/await)

```dart
// Future = 미래에 값이 올 것을 약속
Future<String> fetchUserName() async {
  // API 호출 대기
  await Future.delayed(Duration(seconds: 1));
  return '홍길동';
}

// 사용
void main() async {
  print('로딩 시작');
  String name = await fetchUserName();
  print('이름: $name');
}

// 실제 API 호출 예시
Future<List<Contest>> getContests() async {
  final response = await _apiClient.get('/contests');

  if (response.data is List) {
    return (response.data as List)
        .map((e) => Contest.fromJson(e))
        .toList();
  }
  return [];
}

// 에러 처리
Future<void> loadData() async {
  try {
    final data = await fetchData();
    print(data);
  } catch (e) {
    print('에러 발생: $e');
  }
}
```

---

## 7. 위젯 (Flutter UI)

### StatelessWidget (상태 없음)
```dart
class GreetingCard extends StatelessWidget {
  final String name;

  const GreetingCard({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('안녕하세요 $name님'),
      ),
    );
  }
}

// 사용
GreetingCard(name: '홍길동')
```

### StatefulWidget (상태 있음)
```dart
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  void _increment() {
    setState(() {
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('카운트: $_count'),
        ElevatedButton(
          onPressed: _increment,
          child: const Text('증가'),
        ),
      ],
    );
  }
}
```

### 조건부 렌더링
```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // if 조건
      if (isLoading)
        const CircularProgressIndicator(),

      // if-else는 삼항 연산자
      isLoggedIn
          ? Text('환영합니다')
          : ElevatedButton(
              onPressed: login,
              child: Text('로그인'),
            ),

      // null 체크
      if (error != null)
        Text(error!, style: TextStyle(color: Colors.red)),

      // 리스트 펼치기 (스프레드)
      ...items.map((item) => ListTile(title: Text(item))),
    ],
  );
}
```

---

## 8. Riverpod (상태 관리)

### Provider 정의
```dart
// 단순 값
final greetingProvider = Provider<String>((ref) => '안녕하세요');

// Future (API 호출)
final contestsProvider = FutureProvider<List<Contest>>((ref) async {
  final service = ref.watch(contestServiceProvider);
  return service.getContests();
});

// StateNotifier (상태 변경 가능)
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state++;
  void decrement() => state--;
}

final counterProvider = StateNotifierProvider<CounterNotifier, int>(
  (ref) => CounterNotifier(),
);
```

### Consumer에서 사용
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 값 읽기 (변경 시 리빌드)
    final greeting = ref.watch(greetingProvider);

    // Future 처리
    final contestsAsync = ref.watch(contestsProvider);

    return contestsAsync.when(
      data: (contests) => ListView.builder(
        itemCount: contests.length,
        itemBuilder: (context, index) => Text(contests[index].name),
      ),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('에러: $error'),
    );
  }
}
```

---

## 9. 자주 쓰는 패턴

### JSON 파싱 전체 흐름
```dart
// 1. 모델 정의
class User {
  final int id;
  final String name;

  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

// 2. 서비스에서 API 호출
class UserService {
  final ApiClient _api;

  UserService(this._api);

  Future<List<User>> getUsers() async {
    final response = await _api.get('/users');

    if (response.data is List) {
      return (response.data as List)
          .map((e) => User.fromJson(e))
          .toList();
    }
    return [];
  }
}

// 3. Provider 정의
final userServiceProvider = Provider((ref) => UserService(ApiClient()));

final usersProvider = FutureProvider<List<User>>((ref) {
  return ref.watch(userServiceProvider).getUsers();
});

// 4. UI에서 사용
class UserListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(users[i].name),
        ),
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('에러: $e')),
    );
  }
}
```

---

## 10. 유용한 단축 문법

```dart
// 문자열 보간
var name = '홍길동';
print('이름: $name');           // 변수
print('길이: ${name.length}');  // 표현식

// cascade (..)
var user = User()
  ..name = '홍길동'
  ..age = 25
  ..email = 'hong@test.com';

// collection if/for
var list = [
  'always',
  if (condition) 'sometimes',
  for (var i = 0; i < 3; i++) 'item$i',
];

// null-aware assignment
String? name;
name ??= '기본값';  // null일 때만 할당
```
