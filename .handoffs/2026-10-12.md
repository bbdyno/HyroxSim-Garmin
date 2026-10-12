# Handoff — 2026-10-12

## 현재 상태
`release/2.0` 브랜치. 워치 앱 2.0 화면 전면 개편 완료, 버전 2.0.0. 푸시·스토어 제출은 아직.

## 이번에 한 일
- 모든 화면을 폰 앱 2.0 디자인(블랙+골드, 16칸 진행 링, 굵은 이탤릭 숫자, 버튼 힌트)으로 다시 그림
  - 공통: `source/UI/Styles.mc`(팔레트 amoled/mip), `Fonts.mc`, `Ui.mc`, `Ring.mc`, `WheelView.mc`
  - 화면: `HomeView`, `DivisionPickerView`(+ROX 선택), `CustomWorkoutsView`, `ActionMenu`, `ActiveWorkoutView`, `ResultView`
- 전용 비트맵 폰트: `tools/numfont/build.swift` → `resources*/fonts/` (기기 크기별 4벌)
- 화면 바로가기(디버그 전용): `source/Debug/DebugLaunch.mc`, `tools/screenshots/shoot.sh`
- 디버그·테스트 빌드는 폰 통신 끔 (`phoneLinkEnabled()`), 실기기는 `RELEASE=1 ./scripts/build.sh`
- 버린 운동이 앱 종료 때 폰 outbox 에 들어가던 문제 수정 (`ActionMenu` discard → `markDiscarded`)
- 테스트 20개 (기존 13 + `RingTests` 7)

## 확인한 것
- 5개 기기 × SDK 9.1.0/9.2.0 × 디버그/릴리스/테스트 빌드 30개 성공
- 단위 테스트 20/20: fr265, fenix7 (SDK 9.2.0 시뮬레이터)
- 시뮬레이터 캡처: `docs/screenshots/2.0/` (fr265·fenix7 전 화면, 나머지 주요 화면)

## 확인 못 한 것
- 실기기 동작(버튼 감, MIP 실제 색, 햇빛 아래 가독성), 폰과의 실제 동기화
- 터치 입력(목록 탭·스와이프)과 버튼 입력 — 시뮬레이터에 키 입력을 스크립트로 넣지 못해 화면만 확인
- 한글 운동 이름: 시뮬레이터 fr265 시스템 폰트에 한글이 없어 ◇ 로 보임 (한국어 펌웨어 실기기 확인 필요)

## 다음 작업
1. 실기기 사이드로드(`./scripts/build.sh <device>`)로 버튼·터치·동기화 확인
2. `./scripts/package.sh` 로 `.iq` 만들고 스토어 제출 (`docs/STORE_LISTING.md` What's New 2.0.0)

## 재탐색 명령
- SDK 경로: `cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"`
- 화면 이름 목록: `sed -n 1,20p tools/screenshots/shoot.sh`
