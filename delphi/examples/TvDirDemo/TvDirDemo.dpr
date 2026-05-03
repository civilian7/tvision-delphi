{*******************************************************************
 *  TvDirDemo.dpr
 *  Lite port of tvision/examples/tvdir (tvdir.cpp).
 *
 *  The original uses the TOutline tree widget, which is not exposed
 *  by the wrapper. This port draws an indented tree by hand using
 *  TvCustomView_Create + TvView_WriteText. The view supports
 *  arrow-key, PgUp/PgDn, Home/End scrolling.
 ******************************************************************)
program TvDirDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.AnsiStrings,
  TVision in '../../source/TVision.pas';

const
  cmDirTree = 100;
  cmAbout   = 101;

  kbF3      = $3D00;
  kbAltA    = $1E00;
  kbAltD    = $2000;

  kbUp      = $4800;
  kbDown    = $5000;
  kbPgUp    = $4900;
  kbPgDn    = $5100;
  kbHome    = $4700;
  kbEnd     = $4F00;
  kbEsc     = $011B;

type
  TDirView = record
    Lines: TStringList;
    Top:   Integer;       // index of the first visible line
  end;
  PDirView = ^TDirView;

var
  GApp:     TvAppHandle = nil;
  GView:    PDirView    = nil;       // active directory view (single instance)
  GViewHnd: TvViewHandle = nil;

// ---- Recursive directory scan -----------------------------------
procedure ScanDir(const APath: string; ADepth: Integer; ALines: TStringList);
var
  LSubs:    TStringDynArray;
  LFiles:   TStringDynArray;
  LIndent:  string;
  I:        Integer;
  LName:    string;
begin
  if ADepth > 6 then Exit;  // depth limit

  LIndent := StringOfChar(' ', ADepth * 2);
  if ADepth = 0 then
    ALines.Add('+ ' + APath)
  else
    ALines.Add(LIndent + '+ ' + ExtractFileName(ExcludeTrailingPathDelimiter(APath)));

  try
    LSubs := TDirectory.GetDirectories(APath);
  except
    LSubs := nil;
  end;

  try
    LFiles := TDirectory.GetFiles(APath);
  except
    LFiles := nil;
  end;

  // List files (first 10 only)
  for I := 0 to Length(LFiles) - 1 do
  begin
    if I >= 10 then
    begin
      ALines.Add(LIndent + '  ... (and ' + IntToStr(Length(LFiles) - 10) + ' more files)');
      Break;
    end;
    LName := ExtractFileName(LFiles[I]);
    ALines.Add(LIndent + '  ' + LName);
  end;

  // Recurse into subdirectories (first 5 only)
  for I := 0 to Length(LSubs) - 1 do
  begin
    if I >= 5 then
    begin
      ALines.Add(LIndent + '  ... (' + IntToStr(Length(LSubs) - 5) + ' more dirs)');
      Break;
    end;
    ScanDir(LSubs[I], ADepth + 1, ALines);
  end;
end;

// ---- Custom view: draw the tree ---------------------------------
procedure DirViewDraw(AView: TvViewHandle; AUserData: Pointer); stdcall;
var
  LCx, LCy: Integer;
  LV:       PDirView;
  I:        Integer;
  LIdx:     Integer;
  LText:    AnsiString;
  LAttr:    Byte;
begin
  LV := PDirView(AUserData);
  TvView_GetSize(AView, @LCx, @LCy);

  LAttr := TvView_GetColor(AView, 1);
  TvView_WriteFill(AView, 0, 0, LCx, LCy, ' ', LAttr);

  if (LV = nil) or (LV.Lines = nil) then Exit;

  for I := 0 to LCy - 1 do
  begin
    LIdx := LV.Top + I;
    if LIdx >= LV.Lines.Count then Break;
    LText := AnsiString(LV.Lines[LIdx]);
    if Length(LText) > LCx then SetLength(LText, LCx);
    TvView_WriteText(AView, 0, I, PAnsiChar(LText), LAttr);
  end;
end;

procedure RedrawDirView;
begin
  if GViewHnd <> nil then
    TvView_Redraw(GViewHnd);
end;

// ---- Custom view: key handling ----------------------------------
function DirViewEvent(AView: TvViewHandle; const AEvent: PTvEvent;
                      AUserData: Pointer): Integer; stdcall;
var
  LCx, LCy: Integer;
  LV:       PDirView;
  LMax:     Integer;
begin
  Result := 0;
  if (AEvent^.What and TV_evKeyDown) = 0 then Exit;

  LV := PDirView(AUserData);
  if (LV = nil) or (LV.Lines = nil) then Exit;

  TvView_GetSize(AView, @LCx, @LCy);
  LMax := LV.Lines.Count - LCy;
  if LMax < 0 then LMax := 0;

  case AEvent^.Command of
    kbUp:    if LV.Top > 0 then Dec(LV.Top);
    kbDown:  if LV.Top < LMax then Inc(LV.Top);
    kbPgUp:  begin Dec(LV.Top, LCy); if LV.Top < 0 then LV.Top := 0; end;
    kbPgDn:  begin Inc(LV.Top, LCy); if LV.Top > LMax then LV.Top := LMax; end;
    kbHome:  LV.Top := 0;
    kbEnd:   LV.Top := LMax;
  else
    Exit;
  end;
  Result := 1;
  RedrawDirView;
end;

// ---- Show the directory tree window -----------------------------
procedure ShowDirTree;
var
  LBuf:      array[0..259] of AnsiChar;
  LWinRect:  TTvRect;
  LViewRect: TTvRect;
  LWin:      TvWindowHandle;
  LPath:     string;
begin
  System.AnsiStrings.StrCopy(@LBuf[0], PAnsiChar(AnsiString(GetCurrentDir)));
  if TvInputBox('Directory Tree', '~P~ath', @LBuf[0], SizeOf(LBuf)) = TV_cmCancel then
    Exit;

  LPath := string(AnsiString(LBuf));
  if not TDirectory.Exists(LPath) then
  begin
    TvMessageBox(PAnsiChar(AnsiString('Path not found: ' + LPath)),
                 TV_mfError or TV_mfOKButton);
    Exit;
  end;

  // Dispose of any previous view state
  if GView <> nil then
  begin
    GView.Lines.Free;
    Dispose(GView);
  end;

  New(GView);
  GView.Lines := TStringList.Create;
  GView.Top := 0;

  try
    ScanDir(LPath, 0, GView.Lines);
  except
    on E: Exception do
      GView.Lines.Add('<scan error: ' + E.Message + '>');
  end;

  TvApp_GetExtent(GApp, @LWinRect);
  LWinRect.AX := LWinRect.AX + 4;
  LWinRect.AY := LWinRect.AY + 2;
  LWinRect.BX := LWinRect.BX - 4;
  LWinRect.BY := LWinRect.BY - 2;

  LWin := TvWindow_Create(@LWinRect, PAnsiChar(AnsiString('Tree: ' + LPath)),
                          TV_wnNoNumber);

  LViewRect := MakeRect(1, 1,
                        LWinRect.BX - LWinRect.AX - 2,
                        LWinRect.BY - LWinRect.AY - 2);
  GViewHnd := TvCustomView_Create(@LViewRect,
                                  @DirViewDraw,
                                  @DirViewEvent,
                                  nil, 0,
                                  GView);
  TvView_Insert(LWin, GViewHnd);
  TvApp_InsertWindow(GApp, LWin);
end;

// ---- About ------------------------------------------------------
procedure ShowAbout;
var
  LDlgRect, LRect: TTvRect;
  LDialog:         TvDialogHandle;
begin
  LDlgRect := MakeRect(0, 0, 45, 11);
  LDialog := TvDialog_Create(@LDlgRect, 'About TvDir');
  TvView_SetOptionCentered(LDialog);

  LRect := MakeRect(2, 2, 43, 7);
  TvView_Insert(LDialog,
    TvStaticText_Create(@LRect,
      #3'TvDir (lite) — directory tree'#$0A#3 +
      #3'Delphi port of tvision/examples/tvdir'#$0A +
      #3'Up/Down/PgUp/PgDn to scroll'));

  LRect := MakeRect(17, 8, 28, 10);
  TvView_Insert(LDialog,
    TvButton_Create(@LRect, 'OK', TV_cmOK, TV_bfDefault));

  TvApp_ExecView(GApp, LDialog);
  TvView_Destroy(LDialog);
end;

// ---- Menu / status line ----------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);
  TvMenu_AddSub('~F~ile', $2100);
    TvMenu_AddItem('~D~ir tree...', cmDirTree, kbF3, 'F3');
    TvMenu_AddLine;
    TvMenu_AddItem('E~x~it', TV_cmQuit, TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;
  TvMenu_AddSub('~H~elp', $2300);
    TvMenu_AddItem('~A~bout...', cmAbout, kbAltA, nil);
  TvMenu_EndSub;
  Result := TvMenu_FinishBar;
end;

function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit',  TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~F3~ Tree',     kbF3,      cmDirTree);
  TvStatus_AddItem('',              TV_kbF10,  TV_cmMenu);
  Result := TvStatus_Finish;
end;

// ---- Event handler ---------------------------------------------
function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) = 0 then Exit;

  case AEvent^.Command of
    cmDirTree:
      begin
        ShowDirTree;
        Result := 1;
      end;
    cmAbout:
      begin
        ShowAbout;
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
      if GView <> nil then
      begin
        GView.Lines.Free;
        Dispose(GView);
        GView := nil;
      end;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
