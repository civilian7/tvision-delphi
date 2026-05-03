{*******************************************************************
 *  TVision.pas
 *  Delphi import unit for the tvision_c wrapper DLL.
 *  Targets: Win32 -> tvision32.dll, Win64 -> tvision64.dll
 *
 *  Naming follows project standard: A-prefixed parameters,
 *  L-prefixed locals, namespace-style unit name.
 ******************************************************************}
unit TVision;

interface

{$IFDEF WIN64}
  {$DEFINE TV_DLL64}
{$ELSE}
  {$IFDEF WIN32}
    {$DEFINE TV_DLL32}
  {$ELSE}
    {$MESSAGE FATAL 'TVision wrapper supports only Win32/Win64.'}
  {$ENDIF}
{$ENDIF}

const
  {$IFDEF TV_DLL64}
  TVisionDLL = 'tvision64.dll';
  {$ELSE}
  TVisionDLL = 'tvision32.dll';
  {$ENDIF}

type
  TvHandle        = Pointer;
  TvAppHandle     = Pointer;
  TvViewHandle    = Pointer;
  TvDialogHandle  = Pointer;
  TvWindowHandle  = Pointer;
  TvMenuHandle    = Pointer;
  TvStatusHandle  = Pointer;

  PTvRect = ^TTvRect;
  TTvRect = record
    AX, AY, BX, BY: SmallInt;
  end;

  PTvEvent = ^TTvEvent;
  TTvEvent = record
    What:    Word;
    Command: Word;
    InfoInt: Integer;
    InfoPtr: Pointer;
  end;

  /// <summary>Event callback. Return 1 if the event was handled
  /// (the wrapper will call clearEvent on it).</summary>
  TTvEventHandler   = function(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
  /// <summary>Menu-bar builder callback. Inside the callback issue a
  /// sequence of TvMenu_* calls and return the result of TvMenu_FinishBar.</summary>
  TTvMenuBuilder    = function(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
  /// <summary>Status-line builder callback (mirror of TTvMenuBuilder).</summary>
  TTvStatusBuilder  = function(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
  /// <summary>Idle callback, fired by TApplication::idle().</summary>
  TTvIdleHandler    = procedure(AAppData: Pointer); stdcall;

const
  // ---- Event types -----------------------------------------------
  TV_evNothing      = $0000;
  TV_evMouseDown    = $0001;
  TV_evMouseUp      = $0002;
  TV_evMouseMove    = $0004;
  TV_evMouseAuto    = $0008;
  TV_evKeyDown      = $0010;
  TV_evCommand      = $0100;
  TV_evBroadcast    = $0200;

  // ---- Standard commands -----------------------------------------
  TV_cmValid   = 0;
  TV_cmQuit    = 1;
  TV_cmError   = 2;
  TV_cmMenu    = 3;
  TV_cmClose   = 4;
  TV_cmZoom    = 5;
  TV_cmResize  = 6;
  TV_cmNext    = 7;
  TV_cmPrev    = 8;
  TV_cmHelp    = 9;
  TV_cmOK      = 10;
  TV_cmCancel  = 11;
  TV_cmYes     = 12;
  TV_cmNo      = 13;
  TV_cmDefault = 14;

  // ---- Button flags ----------------------------------------------
  TV_bfNormal    = $00;
  TV_bfDefault   = $01;
  TV_bfLeftJust  = $02;
  TV_bfBroadcast = $04;
  TV_bfGrabFocus = $08;

  // ---- Message-box options ---------------------------------------
  TV_mfWarning      = $0000;
  TV_mfError        = $0001;
  TV_mfInformation  = $0002;
  TV_mfConfirmation = $0003;
  TV_mfYesButton    = $0100;
  TV_mfNoButton     = $0200;
  TV_mfOKButton     = $0400;
  TV_mfCancelButton = $0800;
  TV_mfYesNoCancel  = TV_mfYesButton or TV_mfNoButton or TV_mfCancelButton;
  TV_mfOKCancel     = TV_mfOKButton or TV_mfCancelButton;

  // ---- Frequently used key codes ---------------------------------
  TV_kbNoKey  = $0000;
  TV_kbAltX   = $2D00;
  TV_kbF10    = $4400;
  TV_kbAltF3  = $6800;

  TV_hcNoContext = 0;

  // ---- Window number ---------------------------------------------
  TV_wnNoNumber = -1;

  // ---- File-dialog options ---------------------------------------
  TV_fdOKButton      = $0001;
  TV_fdOpenButton    = $0002;
  TV_fdReplaceButton = $0004;
  TV_fdClearButton   = $0008;
  TV_fdHelpButton    = $0010;
  TV_fdNoLoadDir     = $0100;

  TV_cmFileOpen    = 1001;
  TV_cmFileReplace = 1002;
  TV_cmFileClear   = 1003;
  TV_cmFileInit    = 1004;

// ---- Application -------------------------------------------------
function  TvApp_Create(AMenuBuilder: TTvMenuBuilder;
                       AStatusBuilder: TTvStatusBuilder;
                       AEventHandler: TTvEventHandler;
                       AIdleHandler: TTvIdleHandler;
                       AAppData: Pointer): TvAppHandle; stdcall;
                       external TVisionDLL name 'TvApp_Create';

procedure TvApp_Run(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_Run';
procedure TvApp_Suspend(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_Suspend';
procedure TvApp_Resume(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_Resume';
procedure TvApp_Destroy(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_Destroy';

function  TvApp_GetDeskTop(AApp: TvAppHandle): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvApp_GetDeskTop';
procedure TvApp_GetExtent(AApp: TvAppHandle; AOutRect: PTvRect); stdcall;
                       external TVisionDLL name 'TvApp_GetExtent';
procedure TvApp_InsertWindow(AApp: TvAppHandle; AWin: TvWindowHandle); stdcall;
                       external TVisionDLL name 'TvApp_InsertWindow';
function  TvApp_ExecView(AApp: TvAppHandle; AView: TvViewHandle): Word; stdcall;
                       external TVisionDLL name 'TvApp_ExecView';

/// <summary>Destroy a view. If the view still has a parent owner,
/// it is removed first so the underlying area is repainted; without
/// that step the desktop keeps a dangling pointer and frame artifacts
/// are left on the screen.</summary>
procedure TvView_Destroy(AView: TvViewHandle); stdcall;
                       external TVisionDLL name 'TvView_Destroy';

/// <summary>Force a single view to repaint.</summary>
procedure TvView_Redraw(AView: TvViewHandle); stdcall;
                       external TVisionDLL name 'TvView_Redraw';
/// <summary>Force the whole application (desktop + menu bar +
/// status line) to repaint.</summary>
procedure TvApp_Redraw(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_Redraw';

// ---- Menu builder ------------------------------------------------
procedure TvMenu_BeginBar(const ARect: PTvRect); stdcall;
                       external TVisionDLL name 'TvMenu_BeginBar';
procedure TvMenu_AddSub(const ATitle: PAnsiChar; AHotKey: Word); stdcall;
                       external TVisionDLL name 'TvMenu_AddSub';
procedure TvMenu_EndSub; stdcall;
                       external TVisionDLL name 'TvMenu_EndSub';
procedure TvMenu_AddItem(const ATitle: PAnsiChar;
                         ACommand, AKeyCode: Word;
                         const AHint: PAnsiChar); stdcall;
                       external TVisionDLL name 'TvMenu_AddItem';
procedure TvMenu_AddLine; stdcall;
                       external TVisionDLL name 'TvMenu_AddLine';
function  TvMenu_FinishBar: TvMenuHandle; stdcall;
                       external TVisionDLL name 'TvMenu_FinishBar';

// ---- Status-line builder -----------------------------------------
procedure TvStatus_Begin(const ARect: PTvRect); stdcall;
                       external TVisionDLL name 'TvStatus_Begin';
procedure TvStatus_AddItem(const AText: PAnsiChar;
                           AKeyCode, ACommand: Word); stdcall;
                       external TVisionDLL name 'TvStatus_AddItem';
function  TvStatus_Finish: TvStatusHandle; stdcall;
                       external TVisionDLL name 'TvStatus_Finish';

// ---- Dialogs / windows -------------------------------------------
function  TvDialog_Create(const ARect: PTvRect; const ATitle: PAnsiChar): TvDialogHandle; stdcall;
                       external TVisionDLL name 'TvDialog_Create';
function  TvWindow_Create(const ARect: PTvRect; const ATitle: PAnsiChar;
                          AWindowNumber: SmallInt): TvWindowHandle; stdcall;
                       external TVisionDLL name 'TvWindow_Create';

procedure TvView_Insert(AParent, AChild: TvViewHandle); stdcall;
                       external TVisionDLL name 'TvView_Insert';
procedure TvView_SetData(AView: TvViewHandle; const AData: Pointer); stdcall;
                       external TVisionDLL name 'TvView_SetData';
procedure TvView_GetData(AView: TvViewHandle; AData: Pointer); stdcall;
                       external TVisionDLL name 'TvView_GetData';

// ---- Standard widgets --------------------------------------------
function  TvStaticText_Create(const ARect: PTvRect; const AText: PAnsiChar): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvStaticText_Create';
function  TvButton_Create(const ARect: PTvRect; const ATitle: PAnsiChar;
                          ACommand, AFlags: Word): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvButton_Create';
function  TvLabel_Create(const ARect: PTvRect; const AText: PAnsiChar;
                         ALinkedView: TvViewHandle): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvLabel_Create';
function  TvInputLine_Create(const ARect: PTvRect; AMaxLen: SmallInt): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvInputLine_Create';
function  TvCheckBoxes_Create(const ARect: PTvRect;
                              const AItems: PPAnsiChar; ACount: Integer): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvCheckBoxes_Create';
function  TvRadioButtons_Create(const ARect: PTvRect;
                                const AItems: PPAnsiChar; ACount: Integer): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvRadioButtons_Create';

// ---- Message / input boxes ---------------------------------------
function  TvMessageBox(const AMsg: PAnsiChar; AOptions: Word): Word; stdcall;
                       external TVisionDLL name 'TvMessageBox';
function  TvInputBox(const ATitle, ALabel: PAnsiChar;
                     ABuffer: PAnsiChar; ABufferSize: Integer): Word; stdcall;
                       external TVisionDLL name 'TvInputBox';

// ---- Editor window -----------------------------------------------
function  TvEditWindow_Create(const ARect: PTvRect; const AFileName: PAnsiChar;
                              AWindowNumber: SmallInt): TvWindowHandle; stdcall;
                       external TVisionDLL name 'TvEditWindow_Create';

// ---- Custom view -------------------------------------------------
type
  TTvDrawCallback      = procedure(AView: TvViewHandle; AUserData: Pointer); stdcall;
  TTvViewEventCallback = function (AView: TvViewHandle; const AEvent: PTvEvent;
                                   AUserData: Pointer): Integer; stdcall;

function  TvCustomView_Create(const ARect: PTvRect;
                              ADrawCb: TTvDrawCallback;
                              AEventCb: TTvViewEventCallback;
                              const APaletteBytes: PAnsiChar;
                              APaletteLen: Integer;
                              AUserData: Pointer): TvViewHandle; stdcall;
                       external TVisionDLL name 'TvCustomView_Create';

// ---- View drawing primitives (call from drawCb) ------------------
procedure TvView_GetSize(AView: TvViewHandle; AOutCx, AOutCy: PInteger); stdcall;
                       external TVisionDLL name 'TvView_GetSize';
function  TvView_GetColor(AView: TvViewHandle; APaletteIndex: Word): Byte; stdcall;
                       external TVisionDLL name 'TvView_GetColor';
procedure TvView_WriteText(AView: TvViewHandle; AX, AY: Integer;
                           const AText: PAnsiChar; AAttr: Byte); stdcall;
                       external TVisionDLL name 'TvView_WriteText';
procedure TvView_WriteFill(AView: TvViewHandle; AX, AY, AW, AH: Integer;
                           ACh: AnsiChar; AAttr: Byte); stdcall;
                       external TVisionDLL name 'TvView_WriteFill';

procedure TvView_SetOptionCentered(AView: TvViewHandle); stdcall;
                       external TVisionDLL name 'TvView_SetOptionCentered';

// ---- Command enable / disable ------------------------------------
procedure TvApp_EnableCommand(ACommand: Word); stdcall;
                       external TVisionDLL name 'TvApp_EnableCommand';
procedure TvApp_DisableCommand(ACommand: Word); stdcall;
                       external TVisionDLL name 'TvApp_DisableCommand';

// ---- File dialog -------------------------------------------------
function  TvFileDialog_Create(const AWildCard, ATitle, AInputName: PAnsiChar;
                              AOptions: Word; AHistId: Byte): TvDialogHandle; stdcall;
                       external TVisionDLL name 'TvFileDialog_Create';
function  TvFileDialog_GetFileName(ADlg: TvDialogHandle;
                                   ABuffer: PAnsiChar; ABufferSize: Integer): Integer; stdcall;
                       external TVisionDLL name 'TvFileDialog_GetFileName';

// ---- Window / desktop management ---------------------------------
procedure TvApp_SetMenuBar(AApp: TvAppHandle; ANewMenu: TvMenuHandle); stdcall;
                       external TVisionDLL name 'TvApp_SetMenuBar';
procedure TvApp_DesktopTile(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_DesktopTile';
procedure TvApp_DesktopCascade(AApp: TvAppHandle); stdcall;
                       external TVisionDLL name 'TvApp_DesktopCascade';
procedure TvApp_BroadcastCmd(AApp: TvAppHandle; ACommand: Word); stdcall;
                       external TVisionDLL name 'TvApp_BroadcastCmd';
function  TvApp_DesktopWindowCount(AApp: TvAppHandle): Integer; stdcall;
                       external TVisionDLL name 'TvApp_DesktopWindowCount';

// ---- Color quantization (used by avscolor) ----------------------
/// <summary>Map a 0xRRGGBB value to the closest xterm-16 index (0..15).</summary>
function  TvColor_RGBtoXTerm16(ARgb: Cardinal): Byte; stdcall;
                       external TVisionDLL name 'TvColor_RGBtoXTerm16';
/// <summary>Map a 0xRRGGBB value to an xterm-256 index in [16..255].</summary>
function  TvColor_RGBtoXTerm256(ARgb: Cardinal): Byte; stdcall;
                       external TVisionDLL name 'TvColor_RGBtoXTerm256';
/// <summary>Reverse the xterm-256 index 16..255 back to 0xRRGGBB.</summary>
function  TvColor_XTerm256toRGB(AIndex: Byte): Cardinal; stdcall;
                       external TVisionDLL name 'TvColor_XTerm256toRGB';

// ---- Misc --------------------------------------------------------
function  TvVersion: PAnsiChar; stdcall;
                       external TVisionDLL name 'TvVersion';

/// <summary>Helper that builds a TTvRect record.</summary>
function MakeRect(AX, AY, BX, BY: Integer): TTvRect; inline;

implementation

function MakeRect(AX, AY, BX, BY: Integer): TTvRect;
begin
  Result.AX := AX;
  Result.AY := AY;
  Result.BX := BX;
  Result.BY := BY;
end;

end.
