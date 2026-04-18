# Handoff — 2026-04-19

## 현재 상태
가민 Connect IQ 워치 앱 Phase 1-7 **전체 완료**. 다음은 iOS 통합(`../HyroxSim-iOS`)과 안드로이드 신규 앱(`../HyroxSim-Android`).

## 완료한 Phase

| Phase | 내용 | 커밋 |
|---|---|---|
| 0 | 스캐폴딩 + 빌드 파이프라인 + 스펙 문서 | `c060652` |
| 1 | 도메인/엔진 포팅 + 단위 테스트 7 PASS | `c1fc864`~`52a799f` |
| 2 | UI MVP (Home/DivisionPicker/ActiveWorkout/ActionMenu/Result + Styles) | `a4947a9` |
| 3 | HR 샘플링 + ActivityRecording FIT 기록 | `b4583f5` |
| 4 | WorkoutStorage 영속 outbox | `164dd80` (4+6 합본) |
| 6 | GoalStore/DeltaCalculator/PaceReference 델타 badge | `164dd80` |
| 5+7 | PhoneMessageHandler + CompletedWorkoutCodec + MessageProtocol | `3c8be14` |

## 빌드/테스트

```bash
./scripts/build.sh fenix7          # 빌드
./scripts/test.sh fenix7            # 엔진 단위 테스트 7종 실행
./scripts/run-sim.sh fenix7         # 시뮬레이터 실행
```

현재 SDK 설치된 기기: fenix/epix/venu/vivoactive 계열. **FR265/FR965는 미설치** — SDK Manager에서 다운로드 필요 (빌드는 동작하지만 manifest WARNING).

## 환경
- Connect IQ SDK **9.1.0**
- Homebrew `openjdk@17` (keg-only, 빌드 스크립트가 자동 해결)
- `developer_key.der` 생성됨 (gitignore)

## 미적용 Phase

| Phase | 상태 |
|---|---|
| 8 | 실기기 멀티 테스트 — 기기 필요 |
| 9 | Connect IQ Store 제출 — 스토어 계정 + 아이콘 에셋 정비 |
| 10 | Custom Data Field (네이티브 러닝 액티비티용) — 별도 CIQ 프로젝트 |

## 다음 작업

### 1. iOS 통합 (`../HyroxSim-iOS`)
- `Targets/HyroxCore/Sources/Models/WorkoutSource.swift` 추가 (`watch/manual/garmin`)
- `StoredWorkout`에 `sourceRaw: String` 컬럼 + 마이그레이션
- `Targets/HyroxSim/Sources/Integration/Garmin/`:
  - `GarminBridge.swift` — ConnectIQ.framework 래퍼
  - `GarminDeviceStore.swift`
  - `GarminMessageCodec.swift` (MessageProtocol 상수 Swift 미러)
  - `GarminImportService.swift`
  - `GarminGoalSyncService.swift`
  - `UI/GarminPairingViewController.swift`
- ConnectIQ.xcframework는 **사용자가 수동 드롭인** 필요 — Garmin 개발자 포털 다운로드
- `Frameworks/README.md`에 드롭인 절차 명시

### 2. 안드로이드 신규 (`../HyroxSim-Android`)
- 기존 폴더는 사용자가 별도 삭제 예정
- Kotlin + Compose + Room
- `core/domain`, `core/engine`, `core/persistence`, `feature/home`, `feature/history`, `integration/garmin`
- Garmin Connect IQ Android SDK (AAR) 수동 드롭인

## 핵심 파일 포인터
- 프로토콜 단일 진실 원본: `docs/MESSAGE_PROTOCOL.md`
- 도메인 포팅 스펙: `docs/SPEC.md`
- 디자인 토큰: `source/UI/Styles.mc`
- 데스크톱 노트: `~/Desktop/HyroxSim-Garmin/Phase1-도메인포팅.md`, `Phase2-7-워치앱완성.md`
