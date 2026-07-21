# 리더 디자인 리프레시 설계안

날짜: 2026-07-21
대상: flutter_epub_viewer_kit 0.2.x
방향: 리디북스/밀리 계열 - 차분한 중성 톤, 부드러운 라운딩, 절제된 간격

## 배경

현재 리더 UI는 기본 Material 위젯을 그대로 사용하고, 테마 토큰이 배경색과
글자색 2개뿐이라 모든 크롬(UI 컨트롤)이 `textColor` 알파값으로 파생된다.
선택 표시가 하드코딩된 `Colors.blue`인 것도 이 구조 탓이다. 이번 작업은
토큰을 최소한으로 확장(접근 B)하고 프리셋과 컴포넌트를 재조율한다.

## 범위

1. 컬러 토큰 확장 + 6개 프리셋 재조율
2. SettingsPanel 재설계
3. 리더 오버레이(상단 바 정리, 하단 바 신규)
4. 로딩/에러 상태 토큰 적용
5. example 앱 톤 통일

## 1. 컬러 토큰 & 프리셋

### ColorTheme 확장

`ColorTheme`에 선택 필드 `accent`(`Color?`) 추가. 미지정 시 파생값 사용.
기존 생성자 시그니처는 유지(필드 추가는 non-breaking).

### ReaderSettings 파생 토큰

computed getter 4개 추가:

- `accentColor`: 현재 배경/글자색과 매칭되는 프리셋의 accent. 매칭 실패 시
  밝은 배경이면 `#2E7CE0`, 어두운 배경이면 `#6AA5E8` 폴백
- `mutedColor`: `textColor` 55% 알파
- `dividerColor`: `textColor` 8% 알파
- `surfaceColor`: 크롬(패널/바)용 배경. 밝은 테마는 배경보다 살짝 어둡게,
  어두운 테마는 살짝 밝게 (약 3-4% 시프트)

하드코딩된 `Colors.blue` 등은 전부 토큰으로 교체한다.

### 프리셋 재조율

순흑 글자와 순백 대비를 없애고, 다크 계열 글자를 톤다운한다.
(값은 구현 시 시각 튜닝 가능, 아래는 기준값)

| name | background | text | accent |
|------|-----------|------|--------|
| White | #FFFFFF | #212529 | #2E7CE0 |
| Sepia | #FAF4E6 | #433A2F | #B0763B |
| Gray | #ECEEF0 | #343A40 | #2E7CE0 |
| Paper Green | #E5EFE7 | #2E4A38 | #3E7A55 |
| Dark | #222326 | #C8C8C8 | #6AA5E8 |
| Black | #000000 | #B8B8B8 | #6AA5E8 |

`ReaderSettings` 기본 생성자와 `fromJson` 폴백의 기본 색상도 새 Sepia 값
기준으로 갱신한다. (기존 기본값 #FFFBF0 계열이 Warm/세피아 포지션)

## 2. SettingsPanel 재설계

- 컨테이너: `surfaceColor` 배경, 상단 radius 20, 상단 드래그 핸들
  (36x4 알약, text 20% 알파)
- 섹션 라벨: 12sp, `mutedColor`, weight 600
- 테마 스와치: 44px 원, 헤어라인 테두리(`dividerColor`). 선택 시
  악센트 링(2px) + 배경색 간격 링(2px) 스타일. `Colors.blue` 제거
- 폰트 선택: 각 폰트로 렌더된 칩. 선택 시 악센트 테두리 + 악센트 10% 배경,
  비선택 시 `dividerColor` 테두리
- 크기/줄간격/여백 스테퍼: 알약형 컨테이너 하나에 `- 값 +` 배치
- 보기 모드: 기본 SegmentedButton 제거, 커스텀 2세그먼트 토글
  (트랙: `dividerColor` 배경, 선택 세그먼트: `backgroundColor` 칩 + 미세 그림자)
- 초기화 버튼: `mutedColor` 텍스트 버튼

기능 변경 없음 - 콜백/notifier 연결은 그대로.

## 3. 오버레이

### 상단 바

- 배경 `surfaceColor` 96% 알파, 높이 `kToolbarHeight` 유지
- 제목 15sp w500, 하단 헤어라인(`dividerColor`)
- `topBarBuilder` 오버라이드 동작 유지

### 하단 바 (신규 기본 구현)

현재 `_buildBottomOverlay`는 빈 위젯. 기본 구현을 추가한다:

- 좌우 패딩 있는 슬라이더: active 트랙 `accentColor`, inactive 트랙
  `dividerColor`, 썸 8px
- 슬라이더 아래 `12 / 340` 페이지 표시: 12sp, `mutedColor`
- 페이지 모드: 드래그 종료 시 `goToPage`, 스크롤 모드: `goToProgress` 호출
  - 기존 내비게이션 메서드 재사용, 새 이동 로직 없음
- 드래그 중에는 표시 페이지만 갱신하고 이동은 드래그 종료 시 1회
- `bottomBarBuilder` 오버라이드 동작 유지
- 배경/헤어라인은 상단 바와 동일 처리

### 진행 바 (바 숨김 시)

- 기본색을 `textColor` 30%에서 `accentColor` 40%로 변경
- `progressBarColor` 파라미터 오버라이드 유지

## 4. 로딩/에러 상태

- 로딩 스피너: `accentColor`, 퍼센트 텍스트: `mutedColor`
- 에러 아이콘/텍스트: `mutedColor` (빨간 아이콘 제거)
- 구조 변경 없음, 색상만 토큰화

## 5. example 앱

- 데모 목록 화면: 시드 컬러를 White 프리셋 악센트(#2E7CE0)로, 카드 톤 정리
- example이 자체 구현한 리더 상단/하단 바를 새 토큰 기반으로 통일
  (북마크 amber 하드코딩 등 제거)

## 하위호환

- `ColorTheme.accent`는 옵션 필드, getter 추가뿐 - API breaking 없음
- 저장 포맷(JSON 키) 변경 없음. 기존 사용자의 저장된 색상값은 그대로 로드됨
  (새 프리셋 색은 사용자가 테마를 다시 선택할 때 적용)
- `topBarBuilder`/`bottomBarBuilder`/`progressBarColor` 등 기존 커스터마이징
  API 동작 유지

## 검증

- `flutter analyze` 클린
- 기존 테스트 통과 (`flutter test`)
- 하단 바 슬라이더 스모크 테스트 1개 추가 (드래그 종료 시 페이지 이동 확인)
- example 앱 수동 확인 (6개 테마 각각 패널/바 대비 확인)
