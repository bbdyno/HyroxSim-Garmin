# 개발 환경 셋업

## 1. Connect IQ SDK

### SDK Manager 설치
https://developer.garmin.com/connect-iq/sdk/

1. macOS 설치 파일 다운로드 → 실행
2. SDK Manager 실행 (`/Applications/Garmin/...`)
3. SDK 목록에서 **9.1.0** (또는 최신 안정) "Install"
4. "Set as Current" 확인

### 확인

```bash
cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
# → /Users/.../Sdks/connectiq-sdk-mac-9.1.0-.../

ls "$(cat "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg")/bin/monkeyc"
```

## 2. VS Code

```bash
code --install-extension garmin.monkey-c
```

### 확장 설정
- `Cmd+Shift+P` → "Monkey C: Set Developer Key" → 프로젝트 루트의 `developer_key.der` 선택
- `Cmd+Shift+P` → "Monkey C: Build for Device" / "Run in Simulator"

## 3. 개발자 키

프로젝트 루트에 이미 생성됨 (`developer_key.der`).

### 재생성이 필요하다면

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
    -in developer_key.pem -out developer_key.der -nocrypt
```

**⚠️ 키는 Connect IQ Store 앱 ID와 바인딩됨. 키 교체 시 스토어 앱은 새 앱으로 재등록 필요.**

## 4. 시뮬레이터

```bash
./scripts/run-sim.sh fr265
```

### 시뮬레이터 단축키
| 기능 | 키 |
|---|---|
| Select (가운데 버튼) | Enter |
| Up / Down | ↑ / ↓ |
| Back | Esc |
| Menu | M |
| Touch 시뮬레이션 | 화면 클릭 |

### HR / GPS 데이터 주입
- Simulation → FIT Data Playback → 샘플 FIT 파일 재생
- Simulation → Sensors → HR/Power/Cadence 수동 입력

## 5. 트러블슈팅

| 증상 | 해결 |
|---|---|
| `monkeyc: command not found` | 스크립트는 `current-sdk.cfg`로 경로 해결. SDK 미설치 확인 |
| `Unable to load developer key` | `developer_key.der` 프로젝트 루트 존재 확인, 권한 600 |
| 시뮬레이터가 `onUpdate` 호출 안 함 | 기기 프로파일 변경 후 재시작 |
| 시뮬레이터 멈춤 | `killall ConnectIQ` 후 재실행 |

## 6. (Phase 5+) 실기기 테스트

1. 워치를 USB 케이블로 Mac에 연결
2. 워치 설정에서 "USB 마운트 모드" 활성화
3. `.prg` 파일을 워치의 `GARMIN/APPS/` 디렉토리에 복사
4. 워치 재시작

> iOS 시뮬레이터 + 가민 시뮬레이터 조합으로는 iOS↔워치 실제 통신 테스트 불가. **실기기 필수.**
