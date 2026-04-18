# 포팅 스펙 — HyroxSim 도메인 ↔ Monkey C

**플랫폼 중립 단일 진실 원본**.
iOS(`HyroxCore/Sources/Models`), 안드로이드(`core-model`, `core-engine`), Garmin(`source/Domain`, `source/Engine`) 모두 이 문서를 참조.

## 규약

- **enum raw value**: 3 플랫폼 모두 **동일한 camelCase 문자열** 사용 (iOS Swift `enum: String` 자동 raw value 기준)
- **시간 단위**: **밀리초 (ms)** 기본. 초 단위 필드는 접미사 `_s` 명시
- **거리 단위**: **미터 (m)**
- **무게 단위**: **킬로그램 (kg)**
- **JSON 직렬화**: 필드명은 `snake_case`

---

## 1. SegmentType

| Raw value | 의미 |
|---|---|
| `run` | 러닝 구간 (1km) |
| `roxZone` | 전환 구역 (스테이션 입/퇴장) |
| `station` | 8개 스테이션 중 하나 |

**파생 속성**
- `tracksLocation`: run, roxZone → true / station → false
- `tracksHeartRate`: 모두 true

## 2. StationKind

| Raw value | iOS enum | 표시명 | 기본 타겟 |
|---|---|---|---|
| `skiErg` | `.skiErg` | SkiErg | 1000m |
| `sledPush` | `.sledPush` | Sled Push | 50m |
| `sledPull` | `.sledPull` | Sled Pull | 50m |
| `burpeeBroadJumps` | `.burpeeBroadJumps` | Burpee Broad Jumps | 80m |
| `rowing` | `.rowing` | Rowing | 1000m |
| `farmersCarry` | `.farmersCarry` | Farmers Carry | 200m |
| `sandbagLunges` | `.sandbagLunges` | Sandbag Lunges | 100m |
| `wallBalls` | `.wallBalls` | Wall Balls | 100 reps |
| `custom` | `.custom(name)` | (커스텀) | none |

## 3. StationTarget

Tagged union. JSON 표현:

```json
{ "kind": "distance", "meters": 1000 }
{ "kind": "reps", "count": 100 }
{ "kind": "duration", "seconds": 60 }
{ "kind": "none" }
```

## 4. HyroxDivision

| Raw value | 표시명 | 단축 |
|---|---|---|
| `menOpenSingle` | Men's Open — Singles | M Open |
| `menOpenDouble` | Men's Open — Doubles | M Open 2x |
| `menProSingle` | Men's Pro — Singles | M Pro |
| `menProDouble` | Men's Pro — Doubles | M Pro 2x |
| `womenOpenSingle` | Women's Open — Singles | W Open |
| `womenOpenDouble` | Women's Open — Doubles | W Open 2x |
| `womenProSingle` | Women's Pro — Singles | W Pro |
| `womenProDouble` | Women's Pro — Doubles | W Pro 2x |
| `mixedDouble` | Mixed — Doubles | Mixed 2x |

> `mixedDouble`의 스테이션 스펙은 `menOpenSpecs`와 동일 (공식 룰 미확정 상태 — iOS 구현 따름).

## 5. HyroxDivisionSpec

디비전별 8개 스테이션 스펙 고정 테이블. (상세 수치는 iOS `HyroxDivisionSpec.swift:35-106` 참조)

```json
{
  "division": "mens_open_single",
  "stations": [
    { "kind": "ski_erg", "target": { "kind": "distance", "meters": 1000 } },
    { "kind": "sled_push", "target": { "kind": "distance", "meters": 50 },
      "weight_kg": 152 },
    ...
  ]
}
```

**참고**: 룰북 공식 업데이트 시 iOS 테이블 먼저 갱신 → 본 문서 → Monkey C 순서.

## 6. WorkoutSegment

```json
{
  "id": "uuid-v4",
  "type": "run",
  "distance_meters": 1000,
  "goal_duration_s": 300,
  "station_kind": null,
  "station_target": null,
  "weight_kg": null
}
```

- `type=station`인 경우 `station_kind`, `station_target`, `weight_kg` 필수
- `type=run`/`rox_zone`인 경우 station 필드 모두 null

## 7. WorkoutTemplate

```json
{
  "id": "uuid-v4",
  "name": "HYROX Men's Open",
  "division": "mens_open_single",
  "uses_rox_zone": true,
  "segments": [/* 31 WorkoutSegment */]
}
```

31 세그먼트 시퀀스:
```
Run #1 → RoxZone → Station #1 → RoxZone → Run #2 → RoxZone → Station #2 → ...
  ... → Run #8 → RoxZone → Station #8
```
마지막 Station 뒤 RoxZone 없음.

## 8. EngineState (WorkoutEngine 내부)

4-상태 머신:

| State | 필드 |
|---|---|
| `idle` | — |
| `running` | `current_index`, `segment_started_at` (ms), `workout_started_at` (ms) |
| `paused` | `current_index`, `segment_elapsed_ms`, `total_elapsed_ms` |
| `finished` | `workout_started_at`, `finished_at` |

**전이 함수**:
- `start(now)`: idle → running(0, now, now)
- `advance(now)`: running → running(i+1) 또는 finished
- `pause(now)`: running → paused
- `resume(now)`: paused → running (일시정지 기간 제외)
- `finish(now)`: running/paused → finished
- `undo(now)`: 마지막 SegmentRecord 제거, 이전 인덱스로 복귀

**불변식**: 엔진 내부에서 `Time.now()` 직접 호출 금지. 호출자가 `now` 주입.

## 9. SegmentRecord (완료된 세그먼트)

```json
{
  "id": "uuid-v4",
  "segment_id": "uuid-of-source-WorkoutSegment",
  "index": 0,
  "type": "run",
  "started_at_ms": 1745000000000,
  "ended_at_ms": 1745000300000,
  "paused_duration_ms": 0,
  "planned_distance_meters": 1000,
  "goal_duration_s": 300,
  "station_display_name": null,
  "measurements": {
    "location_samples": [ /* optional */ ],
    "heart_rate_samples": [ { "t_ms": 1745000005000, "bpm": 142 } ]
  }
}
```

**파생 프로퍼티** (저장 안 하고 계산):
- `duration_ms = ended_at - started_at`
- `active_duration_ms = duration_ms - paused_duration_ms`
- `average_pace_s_per_km` (거리 있을 때만)
- `average_heart_rate`

## 10. CompletedWorkout

```json
{
  "id": "uuid-v4",
  "template_name": "HYROX Men's Open",
  "division": "mens_open_single",
  "started_at_ms": 1745000000000,
  "finished_at_ms": 1745004500000,
  "source": "garmin",
  "segments": [ /* SegmentRecord[] */ ]
}
```

`source` enum (iOS `WorkoutSource`):
- `watch` — Apple Watch
- `manual` — 수동 입력
- `garmin` — Garmin 워치

---

## Monkey C 매핑 노트

| 이슈 | 해결 |
|---|---|
| enum 문자열 비교 | `.equals()` 사용 (== 금지) |
| UUID 생성 | `Time.now().value().toString() + Math.rand()` 조합 |
| Dictionary 중첩 직렬화 | `Toybox.Communications.makeJsonRequest`는 폰 전송만. 로컬 저장은 `Application.Storage.setValue(key, dict)` 사용 가능 (자동 직렬화) |
| Long 정수 (epoch ms) | Monkey C `Long`은 64-bit signed, `Number`는 32-bit. ms 타임스탬프는 `Long` 필수 |
| Optional 필드 | `null` 허용, `has :key` 체크 |

---

## 포팅 완료 체크리스트 (Phase 1 종료 기준)

- [ ] `source/Domain/SegmentType.mc`
- [ ] `source/Domain/StationKind.mc`
- [ ] `source/Domain/StationTarget.mc`
- [ ] `source/Domain/HyroxDivision.mc`
- [ ] `source/Domain/HyroxDivisionSpec.mc` (9 디비전 × 8 스테이션 = 72 엔트리)
- [ ] `source/Domain/WorkoutSegment.mc`
- [ ] `source/Domain/WorkoutTemplate.mc` (31 세그먼트 자동 생성)
- [ ] `source/Engine/EngineState.mc`
- [ ] `source/Engine/WorkoutEngine.mc`
- [ ] `source/Engine/SegmentRecord.mc`
- [ ] `tests/unit/` — advance/pause/resume/finish E2E
