{*******************************************************************
 *  TvAppDemo.dpr
 *  Port of tvision/examples/tvdemo (focused on tvdemo3.cpp menus +
 *  tvdemo1.cpp openFile path).
 *
 *  Implements File menu, Window menu (Tile / Cascade / Close All),
 *  About dialog, file selection through TFileDialog, and an info
 *  window that displays the chosen file path - all driven from
 *  Delphi via the TVision DLL.
 ******************************************************************)
program TvAppDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TVision in '../../source/TVision.pas';

const
  cmAbout         = 200;
  cmFileOpen      = 201;
  cmTile          = 202;
  cmCascade       = 203;
  cmCloseAll      = 204;

  // Key codes
  kbF3     = $3D00;
  kbF5     = $3F00;
  kbF6     = $4000;
  kbCtrlF5 = $5F00;
  kbAltF3  = $6800;

var
  GApp:        TvAppHandle = nil;
  GWindowSeq:  Integer     = 0;

// ---- Menu --------------------------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);

  TvMenu_AddSub('~F~ile', $2100 {kbAltF});
    TvMenu_AddItem('~O~pen...',  cmFileOpen, kbF3, 'F3');
    TvMenu_AddLine;
    TvMenu_AddItem('E~x~it',     TV_cmQuit, TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;

  TvMenu_AddSub('~W~indows', $1100 {kbAltW});
    TvMenu_AddItem('~R~esize/move', TV_cmResize, kbCtrlF5, 'Ctrl-F5');
    TvMenu_AddItem('~Z~oom',        TV_cmZoom,   kbF5,     'F5');
    TvMenu_AddItem('~N~ext',        TV_cmNext,   kbF6,     'F6');
    TvMenu_AddItem('~C~lose',       TV_cmClose,  kbAltF3,  'Alt-F3');
    TvMenu_AddLine;
    TvMenu_AddItem('~T~ile',        cmTile,      0, nil);
    TvMenu_AddItem('C~a~scade',     cmCascade,   0, nil);
    TvMenu_AddItem('Close ~A~ll',   cmCloseAll,  0, nil);
  TvMenu_EndSub;

  TvMenu_AddSub('~H~elp', $2300 {kbAltH});
    TvMenu_AddItem('~A~bout...', cmAbout, 0, nil);
  TvMenu_EndSub;

  Result := TvMenu_FinishBar;
end;

// ---- Status line -------------------------------------------------
function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit',  TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~F3~ Open',     kbF3,      cmFileOpen);
  TvStatus_AddItem('~Alt-F3~ Close',kbAltF3,   TV_cmClose);
  TvStatus_AddItem('',              TV_kbF10,  TV_cmMenu);
  Result := TvStatus_Finish;
end;

// ---- About dialog ------------------------------------------------
procedure ShowAbout;
var
  LDlgRect, LRect: TTvRect;
  LDialog:         TvDialogHandle;
begin
  LDlgRect := MakeRect(0, 0, 39, 13);
  LDialog  := TvDialog_Create(@LDlgRect, 'About');

  LRect := MakeRect(9, 2, 30, 7);
  TvView_Insert(LDialog,
    TvStaticText_Create(@LRect,
      #3'TVision Delphi Wrapper'#$0D +
      #3'Demo Application'#$0D +
      #3#$0D +
      #3'(c) 2026 sample port'));

  LRect := MakeRect(14, 9, 26, 11);
  TvView_Insert(LDialog,
    TvButton_Create(@LRect, 'O~K~', TV_cmOK, TV_bfDefault));

  TvApp_ExecView(GApp, LDialog);
  TvView_Destroy(LDialog);
end;

// ---- File info window (displays the chosen file path) -----------
procedure InsertFileInfoWindow(const AFileName: string);
var
  LWinRect, LTextRect: TTvRect;
  LWin:                TvWindowHandle;
  LText:               TvViewHandle;
  LMsg:                AnsiString;
begin
  Inc(GWindowSeq);
  // Cascade-like placement on the desktop
  LWinRect := MakeRect(2 + GWindowSeq * 2, 1 + GWindowSeq, 60 + GWindowSeq * 2, 18 + GWindowSeq);
  LWin := TvWindow_Create(@LWinRect, PAnsiChar(AnsiString('File: ' + AFileName)), GWindowSeq);

  // Inner client coordinates (inside the frame): (1,1)..(width-2, height-2)
  LTextRect := MakeRect(1, 1, 56, 6);
  LMsg := AnsiString(
    'You opened:'#13#10 + AFileName + #13#10 +
    'This window mimics tvdemo''s TFileWindow.');
  LText := TvStaticText_Create(@LTextRect, PAnsiChar(LMsg));
  TvView_Insert(LWin, LText);

  TvApp_InsertWindow(GApp, LWin);
end;

procedure OpenFile;
var
  LDlg:    TvDialogHandle;
  LResult: Word;
  LBuf:    array[0..259] of AnsiChar;
begin
  LDlg := TvFileDialog_Create('*.*', 'Open a File', '~N~ame',
                              TV_fdOpenButton, 100);
  LResult := TvApp_ExecView(GApp, LDlg);
  if LResult <> TV_cmCancel then
  begin
    FillChar(LBuf, SizeOf(LBuf), 0);
    TvFileDialog_GetFileName(LDlg, @LBuf[0], SizeOf(LBuf));
    InsertFileInfoWindow(string(AnsiString(LBuf)));
  end;
  TvView_Destroy(LDlg);
end;

procedure CloseAllWindows;
begin
  // Same as tvdemo's closeView: broadcast cmClose across the desktop
  TvApp_BroadcastCmd(GApp, TV_cmClose);
end;

// ---- Event handler -----------------------------------------------
function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) = 0 then Exit;

  case AEvent^.Command of
    cmAbout:
      begin
        ShowAbout;
        Result := 1;
      end;
    cmFileOpen:
      begin
        OpenFile;
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
        CloseAllWindows;
        Result := 1;
      end;
  end;
end;

var
  LApp: TvAppHandle;
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
