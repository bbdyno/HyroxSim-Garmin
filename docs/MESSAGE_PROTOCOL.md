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

**HR 샘플 다운샘플링**:
- 원본 1Hz → 전송 시 5초 간격 (0.2 Hz)으로 축소
- 31 세그먼트 × 평균 5분 = 9300초 → 1860 샘플 → JSON ~35KB
- 10KB 초과 시 **chunked 전송** (아래 참조)

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

## Chunked 전송 (10KB 초과 시)

한 논리 메시지를 여러 물리 메시지로 분할:

```json
{ "v": 1, "t": "workout.completed", "id": "LOG-ID", "chunk": { "i": 0, "n": 3 }, "payload": {...} }
{ "v": 1, "t": "workout.completed", "id": "LOG-ID", "chunk": { "i": 1, "n": 3 }, "payload": {...} }
{ "v": 1, "t": "workout.completed", "id": "LOG-ID", "chunk": { "i": 2, "n": 3 }, "payload": {...} }
```

- 같은 `id`로 모든 청크 공유
- 수신 측은 `n`개 모두 도착 시 payload 병합 후 처리
- `i` 누락 감지 시 3초 후 `chunk.resend` 요청 (Phase 7에서 확정)

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
- [ ] 10KB 초과 메시지 chunked 전송/수신
