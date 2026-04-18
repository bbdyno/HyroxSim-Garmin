# HyroxSim-Garmin

HYROX 경기 시뮬레이터 — Garmin Connect IQ 워치 앱.

iOS/안드로이드 메인 앱과 양방향 동기화:
- iOS → 워치: 목표 시간, 디비전
- 워치 → iOS: 운동 결과 (HR 포함)

## 빌드 & 실행

### 사전 요구사항
- macOS
- Connect IQ SDK 9.1.0+ (SDK Manager로 설치)
- VS Code + Monkey C 확장 (Garmin 공식)
- 생성된 `developer_key.der` (프로젝트 루트)

### 첫 실행

```bash
# 시뮬레이터에서 FR265로 실행
./scripts/run-sim.sh fr265

# FR965로 실행
./scripts/run-sim.sh fr965

# 빌드만
./scripts/build.sh fr265
```

## 디렉토리 구조

| 경로 | 내용 |
|---|---|
| `source/` | Monkey C 소스 (Domain/Engine/Sensors/Goal/Sync/Storage/UI) |
| `resources/` | 문자열/이미지/메뉴 리소스 |
| `docs/` | 포팅 스펙, 메시지 프로토콜, 기기 지원 매트릭스 |
| `scripts/` | 빌드/실행 헬퍼 |
| `tests/unit/` | Toybox.Test 단위 테스트 |
| `.handoffs/` | 세션 연속성용 작업 메모 |

## 문서

- [SETUP.md](docs/SETUP.md) — 개발 환경 셋업
- [SPEC.md](docs/SPEC.md) — HyroxCore ↔ Monkey C 포팅 스펙
- [MESSAGE_PROTOCOL.md](docs/MESSAGE_PROTOCOL.md) — iOS/Android ↔ 워치 JSON 스키마
- [DEVICE_SUPPORT.md](docs/DEVICE_SUPPORT.md) — 지원 기기 매트릭스
- [CLAUDE.md](CLAUDE.md) — Claude Code 작업 규칙

## 라이선스

미정.
