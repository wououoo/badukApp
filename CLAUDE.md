# Baduk 프로젝트 - 모바일/웹 아키텍처 가이드

## 프로젝트 구조

| 프로젝트 | 용도 | 경로 |
|----------|------|------|
| **Flutter App** | 모바일 앱 (iOS/Android) | `baduk_app/` |
| **React App** | 웹 프론트엔드 | `badukDistribution/src/main/frontend/my-app/` |
| **Spring Boot** | 백엔드 API | `badukDistribution/src/main/java/` |

---

## 핵심 원칙
**모바일 백엔드 수정 시 웹 백엔드에 영향을 주지 않는다!**

---

## 백엔드 API 구분

### 모바일 전용 API (`/api/mobile/*`)
Flutter 앱에서만 호출. 수정해도 React 웹에 영향 없음.

| 엔드포인트 | 컨트롤러 | 설명 |
|------------|----------|------|
| `/mobile/auth/otp/*` | `MobileAuthController.java` | OTP 인증 |
| `/mobile/contests` | `MobileContestController.java` | 대회 목록 (ContestHomepage 기반) |
| `/mobile/contests/{id}` | `MobileContestController.java` | 대회 상세 |
| `/mobile/users/*` | `MobileUserController.java` | 모바일 사용자 관리 |

### 웹 전용 API (`/api/live/*`, `/api/contest/*` 등)
React 웹에서만 호출. 모바일 작업 시 절대 수정 금지!

| 엔드포인트 | 컨트롤러 | 설명 |
|------------|----------|------|
| `/live/contests` | `LiveContestController.java` | 라이브 대회 목록 |
| `/live/contests/{id}/sorts/*` | `LiveContestController.java` | 순위표/대진표 |
| `/contest/*` | `ContestController.java` | 대회 관리 |
| `/gameroom/*` | 각종 GameRoom 컨트롤러 | 대회 운영 |

---

## 백엔드 파일 구분

### 모바일 전용 (수정 가능)

```
src/main/java/badukContest/system/
├── controller/
│   ├── MobileAuthController.java      # 모바일 OTP 인증
│   ├── MobileContestController.java   # 모바일 대회 API
│   └── MobileUserController.java      # 모바일 사용자 API
├── service/mobile/
│   ├── MobileAuthService.java         # OTP 인증 로직
│   └── MobileUserService.java         # 모바일 사용자 로직
└── entity/dto/mobile/
    └── MobileAuthResponseDTO.java     # 모바일 인증 응답
```

### 웹 전용 (모바일 작업 시 수정 금지!)

```
src/main/java/badukContest/system/
├── controller/
│   ├── LiveContestController.java     # 웹 라이브 API
│   ├── ContestController.java         # 웹 대회 관리
│   ├── FullLeagueController.java      # 풀리그
│   ├── TeamLeagueController.java      # 단체전
│   └── 기타 GameRoom 컨트롤러들
├── service/
│   ├── LiveContestService.java
│   ├── ContestService.java
│   └── 기타 서비스들
└── function/mcmahon/                  # 맥마흔 관련
```

---

## 데이터베이스 테이블 역할

### 모바일에서 사용하는 테이블 (ContestHomepage 기반)

| 테이블 | 역할 | 설명 |
|--------|------|------|
| `contest_homepage` | 대회 홈페이지 | **모바일 대회 목록의 기준**. isPublished=true인 것만 모바일에 노출 |
| `contest_category` | 참가 부문 | 부문명, 기력제한, 최대인원, 참가비 등 |
| `contest_category_prize` | 상금 정보 | 순위별 상금/상품 |
| `contest_game_method` | 게임 방식 | 대국방식, 제한시간, 핸디캡 |
| `homepage_registration` | 참가신청 | 모바일에서 신청한 참가자 |
| `homepage_contest_mapping` | 매핑 | 홈페이지 ↔ Contest 연결 |
| `mobile_user` | 모바일 사용자 | OTP 인증된 사용자 |
| `mobile_refresh_token` | 토큰 | 모바일 JWT 리프레시 토큰 |

### 웹에서 사용하는 테이블 (Contest 기반)

| 테이블 | 역할 |
|--------|------|
| `contest` | 실제 대회 (대회 운영의 핵심) |
| `contest_sort` | 대회 부문 (운영용) |
| `mcmahon_player` | 맥마흔 참가자 |
| `mcmahon_match` | 맥마흔 대국 기록 |
| `swiss_*` | 스위스리그 관련 |
| `team_*` | 단체전 관련 |
| `game_room_*` | 게임룸 관련 |

---

## 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│                     contest_homepage                         │
│              (모바일 대회 홈페이지 - 공개용)                  │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   contest_category    contest_category_prize   contest_game_method
   (참가 부문)          (상금 정보)              (게임 방식)
         │
         ▼
   homepage_registration (모바일 참가신청)
         │
         │  homepage_contest_mapping (연결)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                        contest                               │
│                (실제 대회 - 운영용)                          │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
   contest_sort → mcmahon_player → mcmahon_match
   (부문)         (참가자)          (대국)
         │
         ▼
   [웹 관리자 페이지에서 운영]
```

---

## 모바일 기능 추가 시 체크리스트

### 백엔드
1. [ ] `/api/mobile/*` 엔드포인트 사용
2. [ ] `Mobile*Controller.java`에서 작업
3. [ ] `contest_homepage` 관련 테이블 사용
4. [ ] **LiveContestController, ContestController 등 수정하지 않음**

### Flutter
1. [ ] `api_constants.dart`에서 `/mobile/*` 엔드포인트 사용
2. [ ] 필요시 `mobile_*.dart` 파일 생성

---

## 주의사항

1. **LiveContestController.java 수정 금지** - 웹 전용
2. **ContestController.java 수정 금지** - 웹 전용
3. **contest 테이블 직접 조회 금지** - 모바일은 contest_homepage 사용
4. 모바일 API는 반드시 `/mobile/` prefix 사용
5. 새 모바일 컨트롤러는 `Mobile` prefix 붙이기
