# Connect IQ Store 제출 메타데이터

가민 Connect IQ 개발자 포털 (https://apps.garmin.com/developer) 제출 양식에 그대로 복사하세요. 영문이 1차 언어이고 한국어는 보조로 등록 가능합니다.

---

## App Name (제목)

현재 `resources/strings/strings.xml`에 `HyroxSim`으로 설정. 브랜드를 더 강조하고 싶으면 다음 중 선택:

- `HyroxSim` (현재)
- `HYROX Sim` ← 추천 (브랜드명 대문자 강조 + 공백)
- `Hyrox Race Sim`

App Name을 바꾸려면 `resources/strings/strings.xml`의 `AppName` 값을 수정해 재빌드.

---

## Short Description (한 줄 요약)

스토어 카드에 노출됩니다. 80자 내외로 짧게.

**EN**
> HYROX race simulator with real-time pace deltas, custom templates, and iOS sync.

**KO**
> HYROX 레이스 시뮬레이터 — 실시간 페이스 델타, 커스텀 템플릿, iOS 동기화.

---

## Long Description (상세 설명)

**EN**

```
Run HYROX with the same precision as race day — directly on your Garmin.

HyroxSim is a 31-segment race simulator covering all 9 official divisions
(Men's / Women's, Open / Pro, Singles / Doubles, plus Mixed Doubles).
Press SELECT to advance through Run, ROX zones, and stations. The screen
shows segment time, total elapsed, heart rate, GPS pace on Run segments,
and a live delta against your target finish time.

Key features
• 9 HYROX divisions with the official station order
  (SkiErg → Sled Push → Sled Pull → Burpee Broad Jumps → Rowing →
   Farmer's Carry → Sandbag Lunges → Wall Balls)
• Optional ROX zone toggle — run the standard 31-segment HYROX format
  or strip transitions for a 16-segment training variant
• Real-time pace delta vs your target — green when ahead, red when behind
• Multi-GNSS (GPS + GLONASS + Galileo) for fast cold-start outdoors
• Heart rate, GPS pace, segment & total time on a single screen
• FIT activity recording — runs appear in Garmin Connect like any
  other workout
• Touch input fully blocked during a workout to prevent accidental
  segment advances from sweat or wrist contact

Companion iOS app (separate, free)
• Build custom workout templates and push them to the watch
• Pace planner: set a target finish time and per-segment goals sync
  to the watch automatically
• View completed runs in phone history with full segment breakdowns

Pairing
After installing both apps, pair the watch with Garmin Connect Mobile,
then pair the watch from inside the iOS app. Workouts run untethered;
results sync back to the phone when in Bluetooth range.

Supported devices
• Forerunner 265 / 965
• fenix 7 / fenix 8 47mm
• vívoactive 5

This app is not affiliated with or endorsed by HYROX GmbH. HYROX is a
trademark of its respective owner; this app is an independent training
tool.
```

**KO**

```
경기 당일과 같은 정확도로 HYROX를 — 가민 워치 단독으로.

HyroxSim은 9개 공식 디비전 (Men's / Women's, Open / Pro, Singles /
Doubles, Mixed Doubles)을 모두 지원하는 31세그먼트 레이스 시뮬레이터입니다.
SELECT 버튼으로 Run · ROX zone · station을 차례로 진행하면, 한 화면에
세그먼트 시간, 총 누적 시간, 심박, Run 구간 GPS 페이스, 그리고 목표
완주 시간 대비 실시간 델타가 함께 표시됩니다.

주요 기능
• 공식 station 순서를 따르는 9개 HYROX 디비전
  (SkiErg → Sled Push → Sled Pull → Burpee Broad Jumps → Rowing →
   Farmer's Carry → Sandbag Lunges → Wall Balls)
• ROX zone ON / OFF 토글 — 표준 31세그먼트 또는 16세그먼트 훈련 변형
• 목표 시간 대비 실시간 페이스 델타 (앞서면 초록, 뒤처지면 빨강)
• 다중 GNSS (GPS + GLONASS + Galileo) — 야외 cold-start 단축
• 심박 · GPS 페이스 · 세그먼트/총 시간 통합 뷰
• FIT 활동 기록 — Garmin Connect에 일반 운동처럼 자동 업로드
• 운동 중 화면 터치 완전 차단 — 땀/손목 접촉으로 인한 우발 advance 방지

iOS 동반 앱 (별도 무료 다운로드)
• 커스텀 워크아웃 템플릿 빌더 → 워치로 자동 push
• 페이스 플래너로 목표 완주 시간 설정 → 세그먼트별 목표가 워치 동기화
• 완료된 운동을 폰 히스토리에서 세그먼트 단위로 조회

페어링 절차
두 앱 설치 후, Garmin Connect Mobile에서 워치 페어링 → iOS 앱 내
페어링 화면에서 워치 등록. 운동은 워치 단독으로 진행 가능하며,
Bluetooth 범위 안에 들어오면 결과가 폰으로 자동 전송됩니다.

지원 기기
• Forerunner 265 / 965
• fenix 7 / fenix 8 47mm
• vívoactive 5

본 앱은 HYROX GmbH의 공식 인증·후원 앱이 아닙니다. HYROX는 해당 권리자의
상표이며, 본 앱은 독립 훈련 보조 도구입니다.
```

---

## What's New (1.0.0 — 첫 출시)

```
Initial release.
```

또는 한국어로:

```
첫 출시.
```

---

## Tags / Keywords

`hyrox`, `fitness`, `race`, `training`, `hybrid`, `conditioning`,
`interval`, `pace planner`, `gym`, `crossfit`, `competition`

---

## Category

**Activities** > **Health & Fitness** (스토어 카테고리 트리에서 가장
가까운 옵션 선택)

---

## Required Asset Checklist

| 파일 | 위치 | 사이즈 |
|---|---|---|
| `.iq` 패키지 | `bin/HyroxSim.iq` | — |
| 스토어 마케팅 아이콘 | `assets/store_icon.png` | 256×256 PNG |
| 스크린샷 (기기별) | (다음 단계에서 캡처) | fr265 360×360, fr965 454×454 |
| Privacy Policy URL | iOS 앱 정책 재사용 | — |
| Support Email / URL | 사용자 문의 채널 | — |

---

## 주의

- HYROX 상표 사용에 대한 법적 리스크가 있을 수 있습니다. 가민 검수팀이
  거부할 가능성에 대비해 "Hybrid Race Sim", "8x Station Sim" 같은
  대체 이름도 준비해두는 것을 권장합니다.
- iOS 동반 앱이 App Store에 먼저 등록돼야 사용자 흐름이 자연스럽습니다.
- Privacy Policy URL이 살아있는 페이지여야 검수 통과됩니다.
