# TVision Delphi Wrapper

[magiblot/tvision](https://github.com/magiblot/tvision)(Borland Turbo Vision 2.0의 현대적 포팅)을
**vcpkg**로 정적 라이브러리 형태로 빌드한 뒤, **C ABI를 노출하는 DLL**로 감싸서
**Delphi**에서 그대로 사용할 수 있게 하는 프로젝트입니다.

원본의 모든 샘플(`hello`, `mmenu`, `palette`, `tvdemo`, `tvdir`, `tvedit`, `tvforms`, `tvhc`, `avscolor`)을
Delphi 로 포팅한 데모 9개가 포함되어 있습니다.

[English README](README.en.md)

---

## 디렉토리 구성
```
TVISION/
├── build_all.bat                # 원클릭 빌드 (vcpkg + DLL + Delphi + 원본 C++ 샘플)
├── wrapper/                     # C ABI wrapper (C++ → DLL)
│   ├── include/tvision_c.h      # 공개 헤더
│   ├── src/tvision_c.cpp        # 구현
│   └── CMakeLists.txt
├── delphi/
│   ├── bin/                     # 빌드 산출물 (DLL + 데모 EXE)
│   ├── source/TVision.pas       # Delphi 임포트 유닛 (Win32/Win64 자동 선택)
│   ├── examples/                # 샘플별 폴더 (각 .dpr 단독)
│   │   ├── TVisionDemo/   MMenuDemo/   TvAppDemo/   TvEditDemo/
│   │   ├── TvPaletteDemo/ TvDirDemo/   TvHc/        TvFormsDemo/
│   │   └── AvsColor/
│   └── screenshot/              # 자동 캡처된 PNG 스크린샷 + capture.ps1
└── tvision-src/                 # 참조용 원본 소스 (선택, .gitignore)
    └── bin/                     # 원본 C++ 샘플 EXE (build_all.bat 이 빌드)
```

---

## 사전 요구사항
| 항목 | 버전 / 경로 |
|---|---|
| **vcpkg** | `VCPKG_ROOT` 환경변수 또는 기본 `D:\OpenSource\vcpkg` |
| **Visual Studio 2022 Build Tools** | cl.exe 19.44 이상 |
| **CMake** | 3.20 이상 |
| **Delphi 13** (Studio 37.0) | `dcc64.exe` |

---

## 빠른 시작

### 1. 전체 빌드
```cmd
build_all.bat
```
스크립트는 다음을 차례로 수행합니다.

1. `vcpkg install tvision:{x64,x86}-windows-static-md`
2. `wrapper/` 를 x64 / x86 으로 각각 CMake 빌드 → `tvision64.dll` / `tvision32.dll`
3. DLL 을 `delphi/bin/` 으로 복사
4. 9개 Delphi 데모 빌드 → `delphi/bin/*.exe`
5. `tvision-src/` 가 있으면 원본 C++ 샘플 10개도 함께 빌드 → `tvision-src/bin/*.exe`

### 2. 데모 실행
```cmd
cd delphi\bin

TVisionDemo.exe       :: hello-style: Hello 메뉴 / Greeting 다이얼로그
MMenuDemo.exe         :: 메뉴바 런타임 교체 (One/Two/Three 순환)
TvAppDemo.exe         :: 파일 열기 + 윈도우 관리 + About
TvEditDemo.exe        :: 다중 파일 텍스트 에디터 (TEditWindow)
TvPaletteDemo.exe     :: 커스텀 팔레트 뷰
TvDirDemo.exe         :: 디렉토리 트리 뷰어
TvFormsDemo.exe       :: 폰북 폼 (Insert/Edit/Delete/Next/Prev)
TvHc.exe demohelp.txt :: 도움말 컨텍스트 컴파일러 (.h + .pas 생성)
AvsColor.exe          :: 색상 양자화 (PPM 4종 출력)
```

### 3. 단일 샘플만 빌드
```cmd
cd delphi
"C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe" -B ^
    -E"%cd%\bin" ^
    -N"%cd%\source" ^
    -U"%cd%\source" ^
    -I"%cd%\source" ^
    "examples\TvAppDemo\TvAppDemo.dpr"
```

---

## 스크린샷

| 데모 | 화면 |
|---|---|
| **TVisionDemo** | ![](delphi/screenshot/TVisionDemo.png) |
| **MMenuDemo** | ![](delphi/screenshot/MMenuDemo.png) |
| **TvAppDemo** | ![](delphi/screenshot/TvAppDemo.png) |
| **TvEditDemo** | ![](delphi/screenshot/TvEditDemo.png) |
| **TvPaletteDemo** | ![](delphi/screenshot/TvPaletteDemo.png) |
| **TvDirDemo** | ![](delphi/screenshot/TvDirDemo.png) |
| **TvFormsDemo** | ![](delphi/screenshot/TvFormsDemo.png) |

> 스크린샷을 다시 캡처하려면:
> ```cmd
> powershell -ExecutionPolicy Bypass -File delphi\screenshot\capture.ps1
> ```
> `TvHc` 와 `AvsColor` 는 CLI 툴이라 캡처 대상에서 제외.

---

## 데모 ↔ 원본 매핑

| Delphi 포트 | 원본 샘플 | 보여주는 기능 |
|---|---|---|
| `TVisionDemo.dpr`   | [`hello.cpp`](https://github.com/magiblot/tvision/blob/master/hello.cpp) | TApplication 라이프사이클, 메뉴, 상태바, 다이얼로그, 버튼 |
| `MMenuDemo.dpr`     | [`mmenu`](https://github.com/magiblot/tvision/tree/master/examples/mmenu) | 명령에 따른 메뉴바 런타임 교체 (One/Two/Three + Next 순환) |
| `TvAppDemo.dpr`     | [`tvdemo`](https://github.com/magiblot/tvision/tree/master/examples/tvdemo) | File→Open(`TFileDialog`), Window 메뉴(Tile/Cascade/Close All), About |
| `TvEditDemo.dpr`    | [`tvedit`](https://github.com/magiblot/tvision/tree/master/examples/tvedit) | 다중 파일 텍스트 에디터(`TEditWindow`), Open/New, Edit/Search/Window |
| `TvPaletteDemo.dpr` | [`palette`](https://github.com/magiblot/tvision/tree/master/examples/palette) | 커스텀 `TView` (draw + 팔레트) — `TvCustomView_Create` 콜백 |
| `TvDirDemo.dpr`     | [`tvdir`](https://github.com/magiblot/tvision/tree/master/examples/tvdir) | 디렉토리 트리 뷰어 (TOutline 대신 커스텀 뷰로 구현) |
| `TvFormsDemo.dpr`   | [`tvforms`](https://github.com/magiblot/tvision/tree/master/examples/tvforms) | 폰북 폼 — 입력 검증, Insert/Edit/Delete, Next/Prev |
| `TvHc.dpr`          | [`tvhc`](https://github.com/magiblot/tvision/tree/master/examples/tvhc) | 도움말 컨텍스트 컴파일러(CLI) — `.h` + Delphi `.pas` 헤더 출력 |
| `AvsColor.dpr`      | [`avscolor`](https://github.com/magiblot/tvision/tree/master/examples/avscolor) | RGB → xterm-16/256 색상 양자화 CLI (PPM 입출력) |

---

## API 개요 (`tvision_c.h` / `TVision.pas`)

TVision 은 가상함수 기반 C++ 프레임워크라 전체 클래스 트리를 그대로 노출하기는 어렵습니다.
이 wrapper 는 **불투명 핸들 + 콜백 + 빌더 패턴**으로 핵심 기능을 노출합니다.

### 애플리케이션 라이프사이클
```pascal
LApp := TvApp_Create(@MenuBuilder, @StatusBuilder, @EventHandler,
                     @IdleHandler {nil 가능}, AAppData);
TvApp_Run(LApp);
TvApp_Destroy(LApp);
```
부속 함수: `TvApp_Suspend`, `TvApp_Resume`, `TvApp_GetDeskTop`, `TvApp_GetExtent`,
`TvApp_InsertWindow`, `TvApp_ExecView`, `TvApp_SetMenuBar`,
`TvApp_DesktopTile`, `TvApp_DesktopCascade`, `TvApp_BroadcastCmd`, `TvApp_Redraw`.

### 메뉴 빌더 (콜백 안에서 사용)
```pascal
TvMenu_BeginBar(ARect);
  TvMenu_AddSub('~F~ile', kbAltF);
    TvMenu_AddItem('~O~pen', cmOpen, 0, nil);
    TvMenu_AddLine;
    TvMenu_AddItem('E~x~it', TV_cmQuit, TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;
Result := TvMenu_FinishBar;
```

### 상태바 빌더
```pascal
TvStatus_Begin(ARect);
TvStatus_AddItem('~Alt-X~ Exit', TV_kbAltX, TV_cmQuit);
TvStatus_AddItem('',             TV_kbF10,  TV_cmMenu);
Result := TvStatus_Finish;
```

### 다이얼로그 / 윈도우 / 위젯
- `TvDialog_Create`, `TvWindow_Create`, `TvEditWindow_Create`
- `TvStaticText_Create`, `TvButton_Create`, `TvLabel_Create`,
  `TvInputLine_Create`, `TvCheckBoxes_Create`, `TvRadioButtons_Create`
- `TvView_Insert`, `TvView_SetData`, `TvView_GetData`,
  `TvView_Destroy`, `TvView_Redraw`, `TvView_SetOptionCentered`

### 표준 박스 / 파일 다이얼로그
- `TvMessageBox(msg, options)` — `TV_mfWarning|Error|Information|Confirmation` + 버튼 플래그
- `TvInputBox(title, label, buffer, bufferSize)`
- `TvFileDialog_Create`, `TvFileDialog_GetFileName`

### 커스텀 뷰 (Delphi 측에서 draw / handleEvent)
```pascal
LView := TvCustomView_Create(@LRect,
                             @MyDrawCallback,    // procedure(view, userData)
                             @MyEventCallback,   // function(view, event, userData)
                             @PaletteBytes[0], Length(PaletteBytes),
                             AUserData);
```
draw 콜백 안에서는 `TvView_GetSize`, `TvView_GetColor`, `TvView_WriteText`,
`TvView_WriteFill` 로 화면을 그립니다.

### 색상 양자화 (avscolor 용)
- `TvColor_RGBtoXTerm16(rgb)` — 16색 인덱스(0..15)
- `TvColor_RGBtoXTerm256(rgb)` — 256색 인덱스(16..255)
- `TvColor_XTerm256toRGB(idx)` — 역변환

### 이벤트 콜백
```pascal
function EventHandler(const E: PTvEvent; AUserData: Pointer): Integer; stdcall;
```
- `E^.What` 의 비트 플래그가 `TV_evCommand` 면 `E^.Command` 가 명령 ID
- 반환값 1 → wrapper 가 `clearEvent` 호출

---

## 호출 규약 / DLL 선택
- C ABI: **`__stdcall`** (Windows)
- Delphi: **`stdcall`**
- DLL 이름은 `TVision.pas` 의 `{$IFDEF WIN64}` 분기로 자동 선택:
  - 64-bit: `tvision64.dll`
  - 32-bit: `tvision32.dll`

---

## 메모리 관리 규칙
- **`TvDialog_Create` / `TvWindow_Create` / `TvEditWindow_Create` /
  `Tv*Widget*_Create` / `TvMenu_FinishBar` / `TvStatus_Finish`** 는 모두 새 객체를 `new` 합니다.
- **`TvView_Insert(parent, child)`** 후에는 부모(group)가 소유권을 가지므로 자식을
  별도로 `TvView_Destroy` 할 필요 없습니다.
- **modal `TvApp_ExecView` 호출 후**에는 `TvView_Destroy(dialog)` 로 정리합니다
  (TVision 의 `destroy()` 와 동일).
- **`TvView_Destroy`** 는 view 가 아직 부모에 속해 있으면 자동으로 `remove()` 한 뒤 delete 합니다.
  이렇게 하지 않으면 데스크탑이 dangling pointer 를 가져 화면 잔상이 남습니다.
- **`TvApp_Destroy`** 는 데스크탑 / 메뉴 / 상태바 / 모든 자식 view 를 일괄 정리합니다.

---

## 포팅 시 주의사항 (왜 일부 기능이 단순화되었나)
- **`TMultiMenu` (mmenu)** 는 `TMenuBar` 의 C++ 서브클래스라 C ABI 로 노출 불가.
  대신 `TvApp_SetMenuBar` 로 메뉴바를 런타임에 교체하여 동등 효과를 냅니다.
- **`TClockView` / `THeapView` / `TPuzzleWindow` / `TFileWindow` (tvdemo)** 같은
  복잡한 커스텀 뷰들은 광범위한 가상메서드 오버라이드가 필요하여 본 포팅에서는 생략.
  메뉴 / 파일 다이얼로그 / 윈도우 관리 같은 비-서브클래스 영역만 포팅했습니다.
- **`TOutline` (tvdir)** 트리 뷰는 wrapper 에 노출되어 있지 않아, 들여쓰기 텍스트와
  자체 키보드 스크롤로 동등 기능을 구현했습니다.
- **`THelpFile` 바이너리 출력 (tvhc)** 은 tvision 내부 포맷이라 범위 외.
  본 포팅은 `.topic` 파싱과 `.h` / `.pas` 헤더 생성만 제공합니다.
- **AviSynth 비디오 필터 (avscolor)** 는 그대로 Delphi 와 맞지 않아, 동일한
  색상 양자화 로직을 wrapper 에 노출시킨 뒤 PPM 이미지 변환 CLI 로 재구성했습니다.
- **`TKeyInputLine` / `TNumInputLine` 같은 `TInputLine` 서브클래스 (tvforms)**
  와 `.f16` / `.f32` 바이너리 폼 정의 (`TStreamable` 직렬화) 는 노출 불가.
  본 포팅은 동일한 폼 레이아웃 + 샘플 데이터를 사용하면서 검증을 다이얼로그 레벨에서 수행하고
  레코드는 in-memory 컬렉션으로 관리합니다.

---

## 한계
이 wrapper 는 일상적인 Turbo Vision UI 패턴을 충분히 다룰 수 있는
**focused subset** 을 목표로 합니다. 필요시 `wrapper/src/tvision_c.cpp` 에
함수를 추가하여 더 많은 클래스를 노출할 수 있습니다.

현재 미노출 영역:
- **`TListBox` / `TListViewer` / `TOutline`** (직접 스크롤 가능한 리스트/트리 위젯)
- **`THelpFile` / `THelpWindow`** (TVision 의 도움말 시스템)
- **`TStreamable`** (객체 직렬화)
- **`TInputLine` 가상 메서드 오버라이드** (커스텀 검증 필드)
- **`TWindow::getPalette()` 오버라이드** (윈도우 자체 팔레트 변경)

---

## 라이선스
- 본 wrapper / Delphi 포트 / 데모 코드: **[MIT License](LICENSE)**
- 원본 [magiblot/tvision](https://github.com/magiblot/tvision): MIT 라이선스
- 원본 [Borland Turbo Vision 2.0](https://en.wikipedia.org/wiki/Turbo_Vision): 1994 Borland International (재배포 허가됨)
