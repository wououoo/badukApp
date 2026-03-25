#!/bin/bash
# 프로덕션 릴리즈 빌드 스크립트
# 사용법: ./build_release.sh

set -e

API_FILE="lib/core/constants/api_constants.dart"

echo "========================================="
echo "  프로덕션 릴리즈 빌드"
echo "========================================="

# 1. baseURL이 localhost인지 체크
if grep -q "static const String baseUrl = 'http://localhost" "$API_FILE"; then
    echo "[!] localhost 감지 → swissbaduk.org로 변경합니다."
    sed -i "s|static const String baseUrl = 'http://localhost:8080/api';|// static const String baseUrl = 'http://localhost:8080/api';|g" "$API_FILE"
    sed -i "s|static const String webUrl = 'http://localhost:3000';|// static const String webUrl = 'http://localhost:3000';|g" "$API_FILE"
    sed -i "s|// static const String baseUrl = 'https://swissbaduk.org/api';|static const String baseUrl = 'https://swissbaduk.org/api';|g" "$API_FILE"
    sed -i "s|// static const String webUrl = 'https://swissbaduk.org';|static const String webUrl = 'https://swissbaduk.org';|g" "$API_FILE"
fi

# 2. 최종 확인
echo ""
echo "[확인] 현재 baseUrl:"
grep "static const String baseUrl" "$API_FILE" | grep -v "^[[:space:]]*//"
echo ""

if grep "static const String baseUrl" "$API_FILE" | grep -v "^[[:space:]]*//" | grep -q "localhost"; then
    echo "[에러] 아직 localhost입니다! 빌드를 중단합니다."
    exit 1
fi

echo "[OK] swissbaduk.org 확인됨"
echo ""

# 3. 버전코드 자동 +1
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | head -1)
BUILD_NUM=$(echo "$CURRENT_VERSION" | grep -o '+[0-9]*' | tr -d '+')
NEW_BUILD_NUM=$((BUILD_NUM + 1))
NEW_VERSION=$(echo "$CURRENT_VERSION" | sed "s/+${BUILD_NUM}/+${NEW_BUILD_NUM}/")

sed -i "s/$CURRENT_VERSION/$NEW_VERSION/" pubspec.yaml
echo "[버전] $CURRENT_VERSION → $NEW_VERSION"
echo ""

# 4. 빌드
echo "[빌드] flutter build appbundle --release"
echo ""
flutter build appbundle --release

# 5. api_constants.dart에 마지막 빌드 정보 기록
BUILD_DATE=$(date '+%Y-%m-%d %H:%M')
VERSION_STR=$(echo "$NEW_VERSION" | sed 's/version: //')

# 기존 빌드 기록 제거 후 새로 추가
sed -i '/^\/\/ \[마지막 릴리즈/d' "$API_FILE"
echo "// [마지막 릴리즈] $VERSION_STR ($BUILD_DATE)" >> "$API_FILE"

echo ""
echo "========================================="
echo "  빌드 완료!"
echo "  파일: build/app/outputs/bundle/release/app-release.aab"
echo "  버전: $VERSION_STR"
echo "  시간: $BUILD_DATE"
echo "========================================="
