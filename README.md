# TVision Delphi Wrapper

[magiblot/tvision](https://github.com/magiblot/tvision) (Borland Turbo Vision 2.0의 현대적 포팅)
을 vcpkg로 정적 라이브러리로 빌드한 뒤, C ABI를 노출하는 DLL로 감싸서 Delphi에서 사용할 수 있게 하는 프로젝트입니다.

## 디렉토리 구성
```
TVISION/
├── build_all.bat                # 전체 빌드 (vcpkg + DLL + Delphi demos)
├── wrapper/                     # C ABI wrapper (C++ → DLL)
│   ├── include/tvision_c.h      # 공개 헤더
│   ├── src/tvision_c.cpp        # 구현
│   └── CMakeLists.txt
├── delphi/
│   ├── bin/                     # 빌드 산출물
│   │   ├── tvision32.dll        # x86 wrapper DLL
│   │   ├── tvision64.dll        # x64 wrapper DLL
│   │   └── *.exe                # 데모 실행파일들
│   ├── source/
│   │   └── TVision.pas          # Delphi import 유닛
│   └── examples/                # 샘플별 폴더 (각 .dpr 단독)
│       ├── TVisionDemo/
│       ├── MMenuDemo/
│       ├── TvAppDemo/
│       ├── TvEditDemo/
│       ├── TvPaletteDemo/
│       ├── TvDirDemo/
│       └── TvHc/
└── tvision-src/                 # 참조용 원본 소스(선택, git clone)
    ├── examples/                # 원본 C++ 샘플 (hello, mmenu, palette, ...)
    └── bin/                     # 원본 샘플 실행파일 (build_all.bat이 빌드)
```

## 사전 요구사항
- **vcpkg** (`VCPKG_ROOT` 환경변수 또는 `D:\OpenSource\vcpkg`)
- **Visual Studio 2022 (Build Tools)** + **CMake 3.20+**
- **Delphi 13 (Studio 37.0)** — `dcc64.exe`

## 빌드
```cmd
build_all.bat
```
스크립트는 다음 순서로 동작합니다.
1. `vcpkg install tvision:x64-windows-static-md tvision:x86-windows-static-md`
2. `wrapper/`를 x64 / x86 으로 각각 CMake 빌드 → `tvision64.dll`, `tvision32.dll`
3. DLL을 `delphi/bin/` 폴더로 복사
4. `dcc64`로 9개의 Delphi 데모 빌드 → `delphi/bin/*.exe`
5. `tvision-src/` 가 있으면 원본 C++ 샘플도 함께 빌드 → `tvision-src/bin/*.exe`
   (hello, mmenu, palette, tvdemo, tvdir, tvedit, tvforms, tvhc, genparts, genphone)

> 빌드 산출물:
> - `wrapper/build/x64/bin/Release/tvision64.dll`
> - `wrapper/build/x86/bin/Release/tvision32.dll`
> - `delphi/bin/*.exe` (9 Delphi demos)
> - `tvision-src/bin/*.exe` (10 original C++ samples)

## API 개요 (`tvision_c.h` / `TVision.pas`)
TVision은 가상함수 기반 C++ 프레임워크라 전체 클래스 트리를 그대로 노출하기는 어렵습니다.
본 wrapper는 **콜백 기반 + 빌더 패턴**으로 핵심 기능을 노출합니다.

### 애플리케이션 라이프사이클
- `TvApp_Create(menuBuilder, statusBuilder, eventHandler, idleHandler, appData)` — `TApplication` 파생 객체 생성
- `TvApp_Run`, `TvApp_Suspend`, `TvApp_Resume`, `TvApp_Destroy`
- `TvApp_GetDeskTop`, `TvApp_GetExtent`
- `TvApp_InsertWindow`, `TvApp_ExecView`

### 메뉴 빌더 (콜백 안에서 사용)
```
TvMenu_BeginBar(rect)
  TvMenu_AddSub("~F~ile", kbAltF)
    TvMenu_AddItem("~O~pen", cmOpen, 0, "")
    TvMenu_AddLine
    TvMenu_AddItem("E~x~it", cmQuit, kbAltX, "Alt-X")
  TvMenu_EndSub
TvMenu_FinishBar -> handle 반환
```

### 상태바 빌더
```
TvStatus_Begin(rect)
TvStatus_AddItem("~Alt-X~ Exit", kbAltX, cmQuit)
TvStatus_AddItem("",             kbF10,  cmMenu)
TvStatus_Finish -> handle 반환
```

### 다이얼로그 / 위젯
- `TvDialog_Create`, `TvWindow_Create`
- `TvStaticText_Create`, `TvButton_Create`, `TvLabel_Create`
- `TvInputLine_Create`, `TvCheckBoxes_Create`, `TvRadioButtons_Create`
- `TvView_Insert`, `TvView_SetData`, `TvView_GetData`, `TvView_Destroy`

### 표준 박스
- `TvMessageBox(msg, options)` — `mfWarning|mfError|mfInformation|mfConfirmation` + 버튼 플래그
- `TvInputBox(title, label, buffer, bufferSize)`

### 이벤트 콜백
```pascal
function EventHandler(const E: PTvEvent; Data: Pointer): Integer; stdcall;
```
- `E^.What` 비트 플래그가 `TV_evCommand` 면 `E^.Command` 가 명령 ID
- 반환값 1 → tvision 측에서 `clearEvent` 처리

## 스크린샷

| Demo            | Screenshot                                              |
|-----------------|---------------------------------------------------------|
| TVisionDemo     | ![](delphi/screenshot/TVisionDemo.png)                  |
| MMenuDemo       | ![](delphi/screenshot/MMenuDemo.png)                    |
| TvAppDemo       | ![](delphi/screenshot/TvAppDemo.png)                    |
| TvEditDemo      | ![](delphi/screenshot/TvEditDemo.png)                   |
| TvPaletteDemo   | ![](delphi/screenshot/TvPaletteDemo.png)                |
| TvDirDemo       | ![](delphi/screenshot/TvDirDemo.png)                    |
| TvFormsDemo     | ![](delphi/screenshot/TvFormsDemo.png)                  |

스크린샷을 다시 생성하려면:
```cmd
powershell -ExecutionPolicy Bypass -File delphi\screenshot\capture.ps1
```

(TvHc 와 AvsColor 는 CLI 툴이라 스크린샷 대상에서 제외)

## Delphi 데모 (원본 샘플 포팅)

`delphi/` 폴더에는 tvision 원본 샘플을 Delphi 로 포팅한 데모들이 있습니다.

| Delphi DPR          | 원본 샘플                                              | 보여주는 기능                                                              |
|---------------------|--------------------------------------------------------|----------------------------------------------------------------------------|
| `TVisionDemo.dpr`   | [`hello.cpp`](tvision-src/hello.cpp)                   | TApplication 라이프사이클, 메뉴, 상태바, 다이얼로그, 버튼                  |
| `MMenuDemo.dpr`     | [`examples/mmenu/`](tvision-src/examples/mmenu)        | 명령에 따라 메뉴바를 런타임에 교체 (One/Two/Three + Next 순환)             |
| `TvAppDemo.dpr`     | [`examples/tvdemo/`](tvision-src/examples/tvdemo)      | File→Open(TFileDialog), Window 메뉴 (Tile/Cascade/Close All), About        |
| `TvEditDemo.dpr`    | [`examples/tvedit/`](tvision-src/examples/tvedit)      | 다중 파일 텍스트 에디터 (TEditWindow), Open/New, Edit/Search/Window 메뉴   |
| `TvPaletteDemo.dpr` | [`examples/palette/`](tvision-src/examples/palette)    | 커스텀 TView (draw + 팔레트) — `TvCustomView_Create` 콜백 시연             |
| `TvDirDemo.dpr`     | [`examples/tvdir/`](tvision-src/examples/tvdir)        | 디렉토리 트리 뷰어 (TOutline 대신 커스텀 뷰로 구현, 키보드 스크롤)         |
| `TvHc.dpr`          | [`examples/tvhc/`](tvision-src/examples/tvhc)          | 도움말 컨텍스트 컴파일러 (CLI). `.h` 와 Delphi `.pas` 헤더 모두 출력       |
| `AvsColor.dpr`      | [`examples/avscolor/`](tvision-src/examples/avscolor)  | RGB → xterm-16/256 색상 양자화 CLI. PPM 입출력, 합성 그라디언트 자동 생성 |
| `TvFormsDemo.dpr`   | [`examples/tvforms/`](tvision-src/examples/tvforms)    | 폰북 폼 데모: 입력 검증, Insert/Edit/Delete, Next/Prev 네비게이션         |

```cmd
cd delphi\bin
TVisionDemo.exe       :: hello-style
MMenuDemo.exe         :: rotating menus
TvAppDemo.exe         :: file open + window mgmt + about
TvEditDemo.exe        :: text editor (open files via Alt-F O)
TvPaletteDemo.exe     :: custom palette view
TvDirDemo.exe         :: directory tree
TvFormsDemo.exe       :: phonebook form (Insert/Edit/Delete/Next/Prev)
TvHc.exe demohelp.txt :: emit demohelp.h + demohelpHelp.pas
AvsColor.exe          :: synthetic gradient -> 4 quantized PPMs
```

### 단일 샘플 빌드 (수동)
```cmd
cd delphi
"C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe" -B ^
    -E"%cd%\bin" ^
    -N"%cd%\examples\TvAppDemo" ^
    -U"%cd%\source" ^
    -I"%cd%\source" ^
    "examples\TvAppDemo\TvAppDemo.dpr"
```

### 포팅 시 주의사항
- **mmenu** 원본의 `TMultiMenu` 는 `TMenuBar` 의 C++ 서브클래스라 C ABI로 노출 불가.
  대신 `TvApp_SetMenuBar` 로 메뉴바를 런타임 교체하여 동일한 효과 구현.
- **tvdemo** 는 다수의 커스텀 `TView` (TClockView/THeapView/TPuzzleWindow/TFileWindow 등) 사용.
  본 포팅은 메뉴 / 파일다이얼로그 / 윈도우 관리 등 **비-서브클래스 영역만** 포팅.
- **palette** 의 커스텀 `TView::draw()` 와 `getPalette()` 오버라이드는
  wrapper의 `TvCustomView_Create(rect, drawCb, eventCb, paletteBytes, palLen, userData)`
  메커니즘으로 그대로 포팅. 원본 `TTestWindow` 의 윈도우 자체 팔레트 오버라이드는 생략.
- **tvedit** 은 `TEditWindow` 가 모든 텍스트 편집 + 파일 IO 를 직접 처리하므로
  wrapper에 `TvEditWindow_Create` 만 추가하면 거의 직접 포팅 가능.
- **tvdir** 원본은 `TOutline` 트리 뷰. wrapper에 노출되어 있지 않아
  커스텀 뷰 + 들여쓰기 텍스트 + 자체 키보드 스크롤로 동등 기능 구현.
- **tvhc** 의 `THelpFile` 바이너리 출력 부분은 tvision 내부 포맷이라 범위 밖.
  본 포팅은 `.topic` 파싱 + 헤더 파일(.h, .pas) 생성 부분만 제공.
- **avscolor** 의 원본은 AviSynth 비디오 필터 (.dll) 라서 그대로는 Delphi 와 맞지 않음.
  본 포팅은 동일한 색상 양자화 로직(`RGBtoXTerm16`/`256`)을 wrapper에 노출시킨 뒤,
  PPM 이미지에 적용하는 standalone CLI 툴로 구현.
- **tvforms** 의 `TKeyInputLine`/`TNumInputLine` 등 커스텀 `TInputLine` 서브클래스는
  C ABI 로 노출 불가. `.f16`/`.f32` 바이너리 폼 정의 파일도 `TStreamable` 직렬화에 의존하여
  scope 외. 본 포팅은 동일 폼 레이아웃과 샘플 데이터를 사용하면서 검증을 다이얼로그
  레벨(`TKeyInputLine.valid()` → 빈 이름 거절)에서 수행. 데이터는 in-memory 컬렉션.

## 호출 규약
- C ABI: `__stdcall` (Windows)
- Delphi: `stdcall`
- DLL 이름: 64-bit는 `tvision64.dll`, 32-bit는 `tvision32.dll` (TVision.pas가 자동 선택)

## 메모리 관리 노트
- 빌더 호출(`TvDialog_Create`, `Tv*_Create`, `TvMenu_FinishBar`, `TvStatus_Finish`)은 새 TView를 `new` 합니다.
- `TvView_Insert` 후에는 부모(group) 가 소유권을 가지므로 따로 `TvView_Destroy` 하지 않습니다.
- modal `TvApp_ExecView` 호출 후에는 `TvView_Destroy(dialog)` 로 정리합니다 (원본 `destroy()` 호출).
- `TvApp_Destroy`는 데스크탑/메뉴/상태바 모두 정리합니다.

## 한계
이 wrapper는 일상적인 Turbo Vision UI 패턴을 충분히 커버하기 위한 **focused subset** 입니다.
필요시 `wrapper/src/tvision_c.cpp` 에 함수를 추가해 더 많은 클래스를 노출할 수 있습니다.
주요 미노출 영역: `TEditor`, `TListBox`/`TListViewer`, `TFileDialog`, `THelpFile`, `TStreamable`(직렬화).
