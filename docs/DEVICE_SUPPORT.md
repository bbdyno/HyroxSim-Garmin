# 지원 기기 매트릭스

## 지원 기기 (2.0)

| 기기 | product id | 해상도 | 디스플레이 | 버튼 | 폰트·아이콘 리소스 |
|---|---|---|---|---|---|
| Forerunner 265 | `fr265` | 416×416 | AMOLED | 5 + 터치 | `resources-fr265` |
| Forerunner 965 | `fr965` | 454×454 | AMOLED | 5 + 터치 | `resources` |
| fēnix 7 | `fenix7` | 260×260 | MIP 64색 | 5 + 터치 | `resources-fenix7` |
| fēnix 8 47mm | `fenix847mm` | 454×454 | AMOLED | 5 + 터치 | `resources` |
| vívoactive 5 | `vivoactive5` | 390×390 | AMOLED | 2 + 터치 | `resources-vivoactive5` |

다섯 기기 모두 워치 앱 메모리 한도는 768KB (시뮬레이터 표시 763.6kB).
START/STOP 은 오른쪽 위(−30°), BACK 은 오른쪽 아래(+30°)에 있어 버튼 힌트 위치가 같다.
vívoactive 5 는 위/아래 버튼이 없어 목록을 밀거나 눌러서 고른다.

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
- 위치·크기는 화면 지름의 1/200 단위로 적는다 (`Ui.px`). 260~454px 화면이 한 레이아웃을 쓴다
- 숫자·캡션은 화면 크기별로 구운 전용 폰트 (`tools/numfont/build.swift`). 폰에서 온 운동 이름처럼 한글이 섞일 수 있는 글자만 시스템 폰트
- fēnix 7 (MIP 64색) 은 패널이 낼 수 있는 색으로 바꾼 팔레트를 쓴다 (`Styles.mc` 의 `:mip`)
- Layout은 코드 기반 (Rez layout XML 최소화) — 기기별 분기 최소화

## 메모리

- 2.0 화면은 시뮬레이터에서 약 97kB / 763.6kB (fr265·fenix7, 운동 중 화면, 80초 동안 변화 없음)
- 폰트는 그래픽 리소스 풀에 올라가며 앱 힙을 쓰지 않는다
- HR·위치 샘플은 엔진에서 5~15초 간격으로 줄이고 구간당 360개로 막는다 (`WorkoutEngine.mc`)

메모리 프로파일: `Cmd+Shift+P` → "Monkey C: View Runtime Memory" (시뮬레이터 실행 중)
