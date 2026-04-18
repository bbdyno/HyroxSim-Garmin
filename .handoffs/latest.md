# Handoff — 2026-04-18

## 현재 상태
Phase 0 스캐폴딩 완료. 빌드 가능한 "Hello HyroxSim" 스켈레톤 상태.

## 완료
- 저장소 디렉토리 구조 생성
- `manifest.xml`, `monkey.jungle`, `.gitignore` 구성
- `developer_key.der` 생성 (4096-bit RSA → PKCS8 DER), `.gitignore` 등록
- `scripts/build.sh`, `scripts/run-sim.sh` 작성 (current-sdk.cfg로 동적 SDK 경로 해결)
- 초기 Monkey C 스켈레톤:
  - `source/HyroxSimApp.mc` — AppBase 진입
  - `source/UI/HomeView.mc` — 골드 "HyroxSim" 타이틀 + "Ready" 서브타이틀
- 리소스:
  - `resources/strings/strings.xml`
  - `resources/drawables/drawables.xml`
  - `resources/drawables/launcher_icon.png` (60×60 골드 원 placeholder, 교체 예정)
- 문서:
  - `CLAUDE.md` (프로젝트 규칙, iOS와 유사 포맷)
  - `README.md`
  - `docs/SETUP.md` (SDK/VSCode/개발자키)
  - `docs/SPEC.md` (플랫폼 중립 도메인 스펙)
  - `docs/MESSAGE_PROTOCOL.md` (Phone ↔ Watch JSON v1)
  - `docs/DEVICE_SUPPORT.md` (P0: FR265, FR965)

## 환경 확인
- Connect IQ SDK **9.1.0** 설치됨 (`~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/`)
- VS Code Monkey C 확장: 사용자 설치 진행 중
- 가민 개발자 계정 로그인 완료

## 다음 단계

### 즉시 (Phase 0 마무리)
1. VS Code Monkey C 확장 설치 확인: `code --list-extensions | grep monkey`
2. 첫 빌드 실행: `./scripts/run-sim.sh fr265`
3. 시뮬레이터에 "HyroxSim / Ready" 표시되는지 확인
4. git init + 첫 커밋

### Phase 1 (도메인 포팅)
- `source/Domain/*` 구현 (SegmentType, StationKind, StationTarget, HyroxDivision, HyroxDivisionSpec)
- `source/Engine/*` 구현 (EngineState, WorkoutEngine, SegmentRecord)
- iOS `Targets/HyroxCore/Sources/Models/*.swift` 과 `Targets/HyroxCore/Sources/Engine/*.swift` 참조
- `HyroxDivisionSpec.swift:35-106` 의 9×8 테이블 완전 복사
- 단위 테스트 `tests/unit/` 에 Toybox.Test 케이스

## 주의
- `developer_key.der`는 절대 커밋 금지 (`.gitignore` 처리됨)
- iOS `HyroxCore`의 UUID 필드는 Monkey C에서 `Time.now().value().toString() + Math.rand()` 조합으로 대체
- 메시지 스키마 변경 시 `docs/MESSAGE_PROTOCOL.md` 가 단일 진실 원본

## 참조 파일 (iOS 원본)
- `../HyroxSim-iOS/Targets/HyroxCore/Sources/Models/WorkoutSegment.swift`
- `../HyroxSim-iOS/Targets/HyroxCore/Sources/Models/HyroxDivisionSpec.swift`
- `../HyroxSim-iOS/Targets/HyroxCore/Sources/Engine/WorkoutEngine.swift`
- `../HyroxSim-iOS/Targets/HyroxCore/Sources/Engine/EngineState.swift`
- `../HyroxSim-iOS/Targets/HyroxCore/Sources/Models/CompletedWorkout.swift`
