{*******************************************************************
 *  TvEditDemo.dpr
 *  Port of tvision/examples/tvedit  (tvedit1/2/3.cpp).
 *
 *  Multi-file text editor built on top of TEditWindow.
 *  Provides Open / New / Tile / Cascade / Close menus and the
 *  standard tvedit keyboard shortcuts.
 ******************************************************************)
program TvEditDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TVision in '../../source/TVision.pas';

const
  // Standard tvedit commands
  cmNew         = 30;
  cmOpen        = 31;
  cmSave        = 32;
  cmSaveAs      = 33;
  cmChangeDrct  = 34;
  cmDosShell    = 35;
  cmCloseAll    = 36;

  cmCut         = 20;
  cmCopy        = 21;
  cmPaste       = 22;
  cmUndo        = 23;
  cmClear       = 24;
  cmFind        = 82;
  cmReplace     = 83;
  cmSearchAgain = 84;
  cmTile        = 25;
  cmCascade     = 26;

  // Keyboard shortcuts
  kbF2       = $3C00;
  kbF3       = $3D00;
  kbF5       = $3F00;
  kbF6       = $4000;
  kbCtrlN    = $000E;
  kbCtrlQ    = $0011;
  kbCtrlW    = $0017;
  kbCtrlU    = $0015;
  kbCtrlF5   = $5F00;
  kbAltF3    = $6800;
  kbShiftF6  = $5B00;
  kbShiftDel = $5300;
  kbCtrlIns  = $0400;
  kbShiftIns = $0500;
  kbCtrlDel  = $0600;

var
  GApp: TvAppHandle = nil;

// ---- Menu --------------------------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);

  TvMenu_AddSub('~F~ile', $2100 {kbAltF});
    TvMenu_AddItem('~O~pen',         cmOpen,    kbF3,     'F3');
    TvMenu_AddItem('~N~ew',          cmNew,     kbCtrlN,  'Ctrl-N');
    TvMenu_AddItem('~S~ave',         cmSave,    kbF2,     'F2');
    TvMenu_AddItem('S~a~ve as...',   cmSaveAs,  0,        nil);
    TvMenu_AddLine;
    TvMenu_AddItem('Close ~a~ll',    cmCloseAll,0,        nil);
    TvMenu_AddItem('E~x~it',         TV_cmQuit, kbCtrlQ,  'Ctrl-Q');
  TvMenu_EndSub;

  TvMenu_AddSub('~E~dit', $1200 {kbAltE});
    TvMenu_AddItem('~U~ndo',  cmUndo,  kbCtrlU,    'Ctrl-U');
    TvMenu_AddLine;
    TvMenu_AddItem('Cu~t~',   cmCut,   kbShiftDel, 'Shift-Del');
    TvMenu_AddItem('~C~opy',  cmCopy,  kbCtrlIns,  'Ctrl-Ins');
    TvMenu_AddItem('~P~aste', cmPaste, kbShiftIns, 'Shift-Ins');
    TvMenu_AddLine;
    TvMenu_AddItem('C~l~ear', cmClear, kbCtrlDel,  'Ctrl-Del');
  TvMenu_EndSub;

  TvMenu_AddSub('~S~earch', $1F00 {kbAltS});
    TvMenu_AddItem('~F~ind...',     cmFind,        0, nil);
    TvMenu_AddItem('~R~eplace...',  cmReplace,     0, nil);
    TvMenu_AddItem('~S~earch again',cmSearchAgain, 0, nil);
  TvMenu_EndSub;

  TvMenu_AddSub('~W~indows', $1100 {kbAltW});
    TvMenu_AddItem('~S~ize/move',   TV_cmResize, kbCtrlF5,   'Ctrl-F5');
    TvMenu_AddItem('~Z~oom',        TV_cmZoom,   kbF5,       'F5');
    TvMenu_AddItem('~T~ile',        cmTile,      0,          nil);
    TvMenu_AddItem('C~a~scade',     cmCascade,   0,          nil);
    TvMenu_AddItem('~N~ext',        TV_cmNext,   kbF6,       'F6');
    TvMenu_AddItem('~P~revious',    TV_cmPrev,   kbShiftF6,  'Shift-F6');
    TvMenu_AddItem('~C~lose',       TV_cmClose,  kbCtrlW,    'Ctrl-W');
  TvMenu_EndSub;

  Result := TvMenu_FinishBar;
end;

// ---- Status line -------------------------------------------------
function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('',                TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~F2~ Save',       kbF2,      cmSave);
  TvStatus_AddItem('~F3~ Open',       kbF3,      cmOpen);
  TvStatus_AddItem('~Ctrl-W~ Close',  kbCtrlW,   TV_cmClose);
  TvStatus_AddItem('~F5~ Zoom',       kbF5,      TV_cmZoom);
  TvStatus_AddItem('~F6~ Next',       kbF6,      TV_cmNext);
  TvStatus_AddItem('~F10~ Menu',      TV_kbF10,  TV_cmMenu);
  TvStatus_AddItem('',                kbShiftDel,cmCut);
  TvStatus_AddItem('',                kbCtrlIns, cmCopy);
  TvStatus_AddItem('',                kbShiftIns,cmPaste);
  TvStatus_AddItem('',                kbCtrlF5,  TV_cmResize);
  Result := TvStatus_Finish;
end;

// ---- Open an editor window --------------------------------------
procedure OpenEditor(const AFileName: string);
var
  LRect: TTvRect;
  LWin:  TvWindowHandle;
  LName: AnsiString;
  LPtr:  PAnsiChar;
begin
  TvApp_GetExtent(GApp, @LRect);
  // Exclude the menu bar and status line
  Inc(LRect.AY);
  Dec(LRect.BY);

  if AFileName = '' then
    LPtr := nil
  else
  begin
    LName := AnsiString(AFileName);
    LPtr := PAnsiChar(LName);
  end;

  LWin := TvEditWindow_Create(@LRect, LPtr, TV_wnNoNumber);
  if LWin <> nil then
    TvApp_InsertWindow(GApp, LWin);
end;

procedure FileNew;
begin
  OpenEditor('');
end;

procedure FileOpen;
var
  LDlg:    TvDialogHandle;
  LResult: Word;
  LBuf:    array[0..259] of AnsiChar;
begin
  LDlg := TvFileDialog_Create('*.*', 'Open file', '~N~ame',
                              TV_fdOpenButton, 100);
  LResult := TvApp_ExecView(GApp, LDlg);
  if LResult <> TV_cmCancel then
  begin
    FillChar(LBuf, SizeOf(LBuf), 0);
    TvFileDialog_GetFileName(LDlg, @LBuf[0], SizeOf(LBuf));
    OpenEditor(string(AnsiString(LBuf)));
  end;
  TvView_Destroy(LDlg);
end;

// ---- Event handler ----------------------------------------------
function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) = 0 then Exit;

  case AEvent^.Command of
    cmOpen:
      begin
        FileOpen;
        Result := 1;
      end;
    cmNew:
      begin
        FileNew;
        Result := 1;
      end;
    cmTile:
      begin
        TvApp_DesktopTile(GApp);
        Result := 1;
      end;
    cmCascade:
      begin
        TvApp_DesktopCascade(GApp);
        Result := 1;
      end;
    cmCloseAll:
      begin
        TvApp_BroadcastCmd(GApp, TV_cmClose);
        Result := 1;
      end;
  end;
  // cmSave, cmCut, cmCopy, cmPaste, cmUndo and cmClear are handled
  // inside TEditWindow itself, so we don't intercept them here.
end;

// ---- Main ------------------------------------------------------
var
  LApp: TvAppHandle;
  I:    Integer;
begin
  try
    LApp := TvApp_Create(@MenuBuilder, @StatusBuilder, @EventHandler, nil, nil);
    if LApp = nil then
    begin
      Writeln('TvApp_Create failed.');
      Exit;
    end;
    GApp := LApp;
    try
      // Auto-open files passed on the command line (matches tvedit1.cpp)
      for I := 1 to ParamCount do
        OpenEditor(ParamStr(I));
      if ParamCount > 0 then
        TvApp_DesktopCascade(LApp);

      TvApp_Run(LApp);
    finally
      TvApp_Destroy(LApp);
      GApp := nil;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
