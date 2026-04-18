# HyroxSim-Garmin — Claude Code 규칙

## 프로젝트 개요

HYROX 경기 시뮬레이터 가민(Connect IQ) 버전. iOS/안드로이드 앱과 양방향 동기화.
형제 프로젝트:
- `../HyroxSim-iOS` — iOS 메인 앱 (Apple Watch + Garmin 통합)
- `../HyroxSim-Android` — 안드로이드 메인 앱 (예정, 가민 전용)

## 언어 / 툴체인

- **Monkey C** (Garmin 전용 언어)
- **Connect IQ SDK 9.1.0** (`~/Library/Application Support/Garmin/ConnectIQ/`)
- **Target API**: 4.0.0+
- 빌드/실행: `./scripts/build.sh <device>` / `./scripts/run-sim.sh <device>`

## 세션 Handoff

- 최신: `.handoffs/latest.md`
- 스냅샷: `.handoffs/YYYY-MM-DD.md`
- 새 세션은 초기 분석 전에 latest.md 읽기
- repo-relative path로 기록, 머신 의존 값은 재탐색 명령만 남김

## 지원 기기 (MVP P0)

| 기기 | 해상도 | CIQ |
|---|---|---|
| Forerunner 265 | 360×360 | 4.2 |
| Forerunner 965 | 454×454 | 4.2 |

P1 (fēnix 7, Venu 3 등)은 MVP 검증 후 확장.

## 모듈 구조

```
source/
├── Domain/     # SegmentType, StationKind, HyroxDivision, HyroxDivisionSpec, WorkoutSegment, WorkoutTemplate
├── Engine/     # EngineState, WorkoutEngine, SegmentRecord
├── Sensors/    # HeartRateProvider, ActivityRecorder
├── Goal/       # PaceReference, GoalStore, DeltaCalculator
├── Sync/       # PhoneMessageHandler, MessageProtocol, CompletedWorkoutCodec
├── Storage/    # WorkoutStorage (Application.Storage 래퍼)
└── UI/         # HomeView, DivisionPickerView, ActiveWorkoutView, ResultView, Styles
```

## 파일 헤더 형식

모든 `.mc` 파일 헤더:

```monkeyc
//
//  FileName.mc
//  HyroxSimGarmin
//
//  Created by bbdyno on M/D/YY.
//
```

- TargetName 고정: `HyroxSimGarmin`
- 날짜 포맷: `M/D/YY` (예: `4/18/26`)
- `Created by`는 항상 `bbdyno`

## 커밋 규칙

- **커밋 메시지: 한국어**
- author/committer: `bbdyno <della.kimko@gmail.com>`
- `Co-Authored-By: Claude` 붙이지 않음
- 작업 단위별 분리

## 디자인 토큰

iOS 앱과 동일한 블랙+옐로우(골드) 스킴.

```monkeyc
// source/UI/Styles.mc
const COLOR_BACKGROUND = 0x000000;  // 블랙
const COLOR_ACCENT     = 0xFFD700;  // 골드
const COLOR_RUN        = 0x007AFF;  // 블루
const COLOR_ROXZONE    = 0xFF9500;  // 오렌지
const COLOR_STATION    = 0xFFD700;  // 골드
const COLOR_OVER       = 0xFF3B30;  // 델타 초과 시
```

## 도메인 원칙 (iOS와 동일)

- **31 세그먼트** per 프리셋 (8 × [Run + RoxZone + Station + RoxZone] - 마지막 RoxZone 퇴장 없음)
- **9개 디비전**: Men's Open/Pro, Women's Open/Pro (Single/Double) + Mixed Double
- **스테이션 순서**: SkiErg → SledPush → SledPull → BurpeeBroadJumps → Rowing → FarmersCarry → SandbagLunges → WallBalls
- **WorkoutEngine**: 시간(`Time.Moment`)을 외부 주입, 내부에서 `Time.now()` 직접 호출 금지

## iOS/Android 호환 규칙

- **메시지 스키마는 `docs/MESSAGE_PROTOCOL.md`가 단일 진실 원본**
- 플랫폼별로 다르게 보내거나 해석하지 않음 (워치는 폰 OS 모름)
- enum raw value는 iOS/Android/Monkey C 3곳에서 **문자열로 일치** (`"mens_open_single"` 등)

## 주의사항

- `Application.Storage`는 **기기마다 메모리 한계 상이** — FR265는 ~128KB. HR 샘플 배열은 링버퍼로 제한
- `onUpdate` 내부에서 **heavy 계산 금지** — 델타/포맷팅은 틱마다 캐시
- AOD(Always-On Display) 모드에서는 `onPartialUpdate`만 호출됨 — 텍스트 갱신 최소화
- 실기기 없이 시뮬레이터만으로는 **iOS↔Garmin 메시지 검증 불가** (Phase 5+)
- `developer_key.der`는 절대 커밋 금지 (`.gitignore` 처리됨)
