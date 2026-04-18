# 지원 기기 매트릭스

## MVP (P0)

| 기기 | product id | 해상도 | 디스플레이 | CIQ | 메모리 | 비고 |
|---|---|---|---|---|---|---|
| Forerunner 265 | `fr265` | 360×360 | AMOLED round | 4.2 | ~128KB | 터치, HYROX 대상층 핵심 |
| Forerunner 965 | `fr965` | 454×454 | AMOLED round | 4.2 | ~512KB | 터치, 프리미엄 |

## Phase 8 확장 (P1)

| 기기 | product id | 해상도 | 비고 |
|---|---|---|---|
| fēnix 7 | `fenix7` | 260×260 | MIP, 비AMOLED |
| epix 2 | `epix2` | 416×416 | AMOLED |
| Venu 3 | `venu3` | 454×454 | AMOLED, CIQ 5.0 |
| Venu 3S | `venu3s` | 390×390 | AMOLED |

## P2 (후순위)

- Forerunner 255 (`fr255`) — 비터치, 버튼 전용 UI 별도 구현 필요
- Vivoactive 5 (`vivoactive5`)
- Edge 계열 — 사이클링 전용, HYROX 부적합

## 제외 기기

- CIQ 4.0 미만 기기 (메모리/API 한계)
- Instinct 계열 — MIP 흑백, UX 불일치
- 키즈 워치

---

## product id 추가 절차

1. SDK Manager에서 해당 기기 "Device" 다운로드
2. `manifest.xml`의 `<iq:products>` 섹션에 추가
3. 시뮬레이터에서 `./scripts/run-sim.sh <device-id>` 동작 확인
4. `monkey.jungle`에 해상도별 리소스 오버라이드 필요하면 추가
5. `DEVICE_SUPPORT.md`에 한 줄 추가

## 해상도/폼팩터 대응 원칙

- **round 위주** 설계. rectangular(edge 계열) 제외
- 텍스트 크기는 `FONT_LARGE`, `FONT_MEDIUM`, `FONT_SMALL` 상수만 사용 (기기별 자동 스케일)
- Layout은 코드 기반 (Rez layout XML 최소화) — 기기별 분기 최소화

## 메모리 한계 대응

| 기기 | App 예산 | 대응 |
|---|---|---|
| FR265 (~128KB) | HR 샘플 링버퍼 1800개(10분분) 제한 | 10분 초과 시 파일 저장 후 버퍼 비움 |
| FR965 (~512KB) | 여유 | 제한 없음 |

메모리 프로파일: `Cmd+Shift+P` → "Monkey C: View Runtime Memory" (시뮬레이터 실행 중)
