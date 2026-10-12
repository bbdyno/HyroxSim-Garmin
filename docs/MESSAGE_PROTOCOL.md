# Phone ↔ Garmin Watch 메시지 프로토콜

**v1 (2026-04-18)**

iOS / 안드로이드 / Monkey C **공통 스펙**. 워치는 폰 OS를 구분하지 않음.

## 전송 채널

- **iOS**: `ConnectIQ.xcframework` → `IQApp.sendMessage(_:toApp:)`
- **안드로이드**: `ConnectIQ Android AAR` → `IQApp.sendMessage(...)`
- **워치**: `Toybox.Communications.transmit(dict, options, listener)` / `registerForPhoneAppMessages(...)`
- **브릿지**: Garmin Connect Mobile 앱 (사용자 폰에 설치 필수)
- **크기 한도**: 메시지당 약 **10 KB** (초과 시 chunk 분할)

## 공통 헤더

모든 메시지는 이 필드를 포함:

```json
{
  "v": 1,
  "t": "<type>",
  "id": "uuid-v4",
  "payload": { ... }
}
```

- `v`: 스키마 버전 (현재 1)
- `t`: 타입 문자열 (아래 표 참조)
- `id`: 멱등성 키. 수신 측에서 중복 무시
- `payload`: 타입별 본문

---

## 메시지 타입

### 📤 Phone → Watch

#### `hello` — 핸드셰이크
```json
{ "v": 1, "t": "hello", "id": "...", "payload": { "phone_os": "ios", "app_version": "1.2.3" } }
```

#### `goal.set` — 목표 시간 설정
```json
{
  "v": 1, "t": "goal.set", "id": "...",
  "payload": {
    "division": "mens_open_single",
    "template_name": "HYROX Men's Open",
    "target_total_ms": 4500000,
    "target_segments_ms": [300000, 15000, 240000, 15000, ...]
  }
}
```

- `target_segments_ms` 길이 = 31 (WorkoutTemplate 세그먼트 수와 일치)
- 생략 시 Watch는 `PaceReference` 기본값 사용

#### `template.upsert` — 템플릿 동기화 (optional)
```json
{
  "v": 1, "t": "template.upsert", "id": "...",
  "payload": { /* WorkoutTemplate JSON (SPEC.md §7) */ }
}
```

#### `cmd.<action>` — 원격 제어 (Phase 2+ 실시간 미러링)
```json
{ "v": 1, "t": "cmd.advance", "id": "..." }
{ "v": 1, "t": "cmd.pause",   "id": "..." }
{ "v": 1, "t": "cmd.resume",  "id": "..." }
{ "v": 1, "t": "cmd.end",     "id": "..." }
```

---

### 📥 Watch → Phone

#### `hello.ack` — 핸드셰이크 응답
```json
{
  "v": 1, "t": "hello.ack", "id": "...",
  "payload": {
    "device": "fr965",
    "app_version": "0.1.0",
    "battery_pct": 87
  }
}
```

#### `workout.completed` — 운동 종료 결과 ★ 핵심
```json
{
  "v": 1, "t": "workout.completed", "id": "...",
  "payload": {
    "id": "uuid-v4",
    "template_name": "HYROX Men's Open",
    "division": "mens_open_single",
    "started_at_ms": 1745000000000,
    "finished_at_ms": 1745004500000,
    "source": "garmin",
    "segments": [ /* SegmentRecord[] (SPEC.md §9) */ ]
  }
}
```

**HR 샘플**:
- 워치는 15초에 한 번만 보관하고, 전송 시 구간당 최대 40개로 줄인다
- 31개 구간 기록은 한 메시지에 들어가지 않으므로 **분할 전송**한다 (아래 참조)

#### `live.state` — 실시간 상태 (Phase 2+ optional)
```json
{
  "v": 1, "t": "live.state", "id": "...",
  "payload": {
    "segment_index": 5,
    "segment_elapsed_ms": 120000,
    "total_elapsed_ms": 1800000,
    "heart_rate": 152,
    "is_paused": false,
    "delta_total_ms": -5000
  }
}
```

송신 주기: **1~2초** (0.5초는 가민 대역폭 한계)

---

## 분할 전송 (`workout.completed.part`)

기록을 구간 목록 기준으로 잘라 여러 메시지로 보낸다. 조각이 하나뿐이면
`chunk` 없이 `workout.completed` 로 보낸다.

```json
{ "v": 1, "t": "workout.completed.part", "id": "WORKOUT-UUID", "chunk": { "i": 0, "n": 3 },
  "payload": { "id": "...", "templateName": "...", "division": "...", "startedAtMs": 0, "finishedAtMs": 0, "source": "garmin", "segments": [...] } }
{ "v": 1, "t": "workout.completed.part", "id": "WORKOUT-UUID", "chunk": { "i": 1, "n": 3 }, "payload": { "segments": [...] } }
{ "v": 1, "t": "workout.completed.part", "id": "WORKOUT-UUID", "chunk": { "i": 2, "n": 3 }, "payload": { "segments": [...] } }
```

- 타입을 `workout.completed` 와 따로 둔 이유: 분할을 모르는 옛 폰 앱이 0번 조각을
  완성된 기록으로 저장하지 않게 하기 위해서다 (모르는 타입은 무시된다)
- 봉투 `id` 는 기록 id. 모든 조각이 같은 값을 쓴다
- 머리 정보는 0번 조각에만 있고, 나머지는 `segments` 만 싣는다
- 워치는 앞 조각 전송이 끝나야 다음 조각을 보낸다 (전송 큐가 짧다)
- 폰은 `n`개가 모두 모이면 `segments` 를 순서대로 이어 붙여 저장하고 `ack` 한 번을 보낸다.
  그 전에는 ack 하지 않는다
- 조각이 유실되면 워치는 ack 를 못 받으므로 다음 `hello` 때 0번부터 전부 다시 보낸다.
  폰은 0번이 다시 오면 이전에 모으던 조각을 버린다
- 구현: 워치 `CompletedWorkoutCodec.split` / `WorkoutStorage`, iOS·Android `GarminWorkoutPartAssembler`

---

## 신뢰성 & 재시도

1. **송신 실패**: Watch는 `Application.Storage`에 "outbox" 큐에 저장
2. **다음 연결 시**: `hello.ack` 수신 후 outbox 비우기
3. **멱등성**: 폰은 같은 `id` 두 번 수신해도 1건으로 처리 (iOS 기존 idempotent upsert 로직 재사용)

## 버전 관리

- `v` 필드 기반. v1 → v2 변경 시 호환 기간 동안 양쪽 지원
- Breaking change 시 새 메시지 타입 (`goal.set.v2`) 추가가 원칙

---

## 테스트 시나리오 (Phase 5+ 검증)

- [ ] iOS 실기기 + FR965 실기기 `hello` 왕복
- [ ] Goal 전송 → Watch 저장 확인
- [ ] 31 세그먼트 완주 → CompletedWorkout 수신 + SwiftData 저장
- [ ] 같은 id 두 번 전송 → 1건만 저장
- [ ] Watch 오프라인 상태에서 운동 → 재연결 시 outbox 자동 flush
- [ ] 31 세그먼트 기록 분할 전송/수신 (실기기) — 시뮬레이터 단위 테스트는 통과
