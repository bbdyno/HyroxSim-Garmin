# HyroxSim-Garmin — Claude Code 규칙

## 프로젝트 개요

HYROX 경기 시뮬레이터 가민(Connect IQ) 버전. iOS/안드로이드 앱과 양방향 동기화.
형제 프로젝트:
- `../HyroxSim-iOS` — iOS 메인 앱 (Apple Watch + Garmin 통합)
- `../HyroxSim-Android` — 안드로이드 메인 앱 (예정, 가민 전용)

## 언어 / 툴체인

- **Monkey C** (Garmin 전용 언어)
- **Connect IQ SDK 9.1.0 / 9.2.0** (`~/Library/Application Support/Garmin/ConnectIQ/`)
- **Target API**: 4.0.0+
- 빌드/실행: `./scripts/build.sh <device>` / `./scripts/run-sim.sh <device>` / `./scripts/test.sh <device>`
- 실기기용: `RELEASE=1 ./scripts/build.sh <device>` — **디버그·테스트 빌드는 폰 통신이 꺼져 있다** (`phoneLinkEnabled()`). 시뮬레이터가 전송마다 경고창을 띄우기 때문이며, 릴리스 동작은 그대로다
- 화면 바로가기(스크린샷): `tools/screenshots/shoot.sh <screen|tour> <device> <out.prg>` — `source/Debug/` 는 전부 `(:debug)` 라 릴리스에 안 들어간다
- 폰트 재생성: `swift tools/numfont/build.swift`

## 세션 Handoff

- 최신: `.handoffs/latest.md`
- 스냅샷: `.handoffs/YYYY-MM-DD.md`
- 새 세션은 초기 분석 전에 latest.md 읽기
- repo-relative path로 기록, 머신 의존 값은 재탐색 명령만 남김

## 지원 기기

| 기기 | 해상도 | 디스플레이 |
|---|---|---|
| Forerunner 265 | 416×416 | AMOLED |
| Forerunner 965 | 454×454 | AMOLED |
| fēnix 7 | 260×260 | MIP 64색 |
| fēnix 8 47mm | 454×454 | AMOLED |
| vívoactive 5 | 390×390 | AMOLED, 버튼 2개 |

## 모듈 구조

```
source/
├── Domain/     # SegmentType, StationKind, HyroxDivision, HyroxDivisionSpec, WorkoutSegment, WorkoutTemplate
├── Engine/     # EngineState, WorkoutEngine, SegmentRecord
├── Sensors/    # HeartRateProvider, ActivityRecorder
├── Goal/       # PaceReference, GoalStore, DeltaCalculator
├── Sync/       # PhoneMessageHandler, MessageProtocol, CompletedWorkoutCodec
├── Storage/    # WorkoutStorage (Application.Storage 래퍼)
├── UI/         # Styles(팔레트), Fonts, Ui(그리기 도우미), Ring(진행 링), WheelView(목록 공통),
│               # HomeView, DivisionPickerView, CustomWorkoutsView, ActionMenu, ActiveWorkoutView, ResultView
├── Debug/      # DebugLaunch — 화면 바로가기, (:debug) 전용
└── Tests/      # EngineTests, OutboxTests, RingTests
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

## 디자인 (2.0)

폰 앱 2.0 과 같은 블랙 + 골드. 토큰은 `source/UI/Styles.mc`.

```monkeyc
// Palette — (:amoled) 기준. fēnix 7 은 (:mip) 팔레트가 대신 컴파일된다
const GOLD     = 0xFFD700;  // 액센트, 목표보다 앞섬
const ORANGE   = 0xFF7A33;  // 목표보다 뒤짐
const BLUE     = 0x4C99FF;  // 런 캡션 색 (라벨에만)
const GREY     = 0x8A8A8A;  // 보조 텍스트
const UPCOMING = 0x2E2E2E;  // 링에서 아직 안 온 칸
```

- 배경은 항상 순수 블랙. 둥근 카드·배지·그림자 없이 각진 면과 헤어라인만
- 화면마다 굵은 이탤릭 숫자 하나가 주인공, 캡션은 작게·대문자·자간
- 테두리 링: 런·스테이션마다 한 칸 (프리셋은 16칸), ROX 존은 옆 런에 포함. 끝난 칸은 골드/오렌지, 지금 칸은 흰색. 로직은 `RingModel` (순수 함수, `RingTests`)
- 버튼 힌트: 오른쪽 위 START(−30°)·오른쪽 아래 BACK(+30°)에 흰 사각형 + 검은 글씨
- 좌표는 화면 지름의 1/200 단위 (`Ui.px`). 새 화면도 이 단위로 그리고 5개 기기에서 겹침·잘림을 캡처로 확인
- 전용 폰트(`Fonts`)는 A-Z·숫자·기본 문장부호만 있다. 사용자 글자는 `Ui.isPlain()` 으로 확인하고 시스템 폰트로
- 목록형 화면은 `WheelView` 를 상속하고 `activate()` / `back()` 만 구현

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

- 워치 앱 메모리 한도는 5개 기기 모두 768KB. HR·위치 샘플은 엔진에서 간격·개수를 제한
- `onUpdate` 내부에서 **heavy 계산 금지** — 링 상태·캡션은 구간이 바뀔 때만 다시 계산 (`ActiveWorkoutView._refreshCache`)
- AOD(Always-On Display) 모드에서는 `onPartialUpdate`만 호출됨 — 텍스트 갱신 최소화
- 실기기 없이 시뮬레이터만으로는 **iOS↔Garmin 메시지 검증 불가** (Phase 5+)
- `developer_key.der`는 절대 커밋 금지 (`.gitignore` 처리됨)
