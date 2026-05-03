{*******************************************************************
 *  MMenuDemo.dpr
 *  Port of tvision/examples/mmenu (test.cpp).
 *  TMultiMenu C++ subclass cannot be exposed via the C ABI, so this
 *  port reproduces the same behavior by swapping the menu bar at
 *  runtime via TvApp_SetMenuBar whenever the user picks One/Two/Three
 *  or "Next menu".
 ******************************************************************)
program MMenuDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TVision in '../../source/TVision.pas';

const
  // Same constants as the original cmds.h
  cmOne     = 100;
  cmTwo     = 101;
  cmThree   = 102;
  cmCycle   = 110;
  cmNothing = 111;

  // Menu accelerators (kbAlt + letter)
  kbAltN = $3100;
  kbAltM = $3200;
  kbAltO = $1800;
  kbAltT = $1400;
  kbAltH = $2300;
  kbAltF = $2100;
  kbAltS = $1F00;
  kbAltA = $1E00;
  kbAltE = $1200;
  kbAltC = $2E00;
  kbAltP = $1900;

var
  GApp:     TvAppHandle = nil;
  GCurMenu: Integer     = 0;       // cycles through 0..2

// ---- Menu builder helpers --------------------------------------
procedure BuildSharedHeader;
begin
  // Common entries shared by every menu set: "Next menu" plus One/Two/Three
  TvMenu_AddSub('~N~ext menu', kbAltN);
    TvMenu_AddItem('next', cmCycle, kbAltN, nil);
  TvMenu_EndSub;
end;

procedure BuildOneTwoThree(const ASectionTitle: PAnsiChar);
begin
  TvMenu_AddSub(ASectionTitle, kbAltM);
    TvMenu_AddItem('~O~ne',   cmOne,   kbAltO, nil);
    TvMenu_AddItem('~T~wo',   cmTwo,   kbAltT, nil);
    TvMenu_AddItem('T~h~ree', cmThree, kbAltH, nil);
  TvMenu_EndSub;
end;

function BuildMenu(const ARect: PTvRect; AIndex: Integer): TvMenuHandle;
begin
  TvMenu_BeginBar(ARect);

  BuildSharedHeader;

  case AIndex of
    0:
      begin
        BuildOneTwoThree('~M~enu One');
        TvMenu_AddSub('~F~ile', kbAltF);
          TvMenu_AddItem('~N~ew',     cmNothing, kbAltN, nil);
          TvMenu_AddItem('~O~pen',    cmNothing, kbAltO, nil);
          TvMenu_AddItem('~S~ave',    cmNothing, kbAltS, nil);
          TvMenu_AddItem('S~a~ve all',cmNothing, kbAltA, nil);
        TvMenu_EndSub;
      end;
    1:
      begin
        BuildOneTwoThree('~M~enu Two');
        TvMenu_AddSub('~E~dit', kbAltE);
          TvMenu_AddItem('Cu~t~',  cmNothing, kbAltT, nil);
          TvMenu_AddItem('~C~opy', cmNothing, kbAltC, nil);
          TvMenu_AddItem('~P~aste',cmNothing, kbAltP, nil);
        TvMenu_EndSub;
      end;
    2:
      begin
        BuildOneTwoThree('~M~enu Three');
        TvMenu_AddSub('~C~ompile', kbAltC);
          TvMenu_AddItem('~C~ompile',  cmNothing, kbAltO, nil);
          TvMenu_AddItem('~M~ake',     cmNothing, kbAltT, nil);
          TvMenu_AddItem('~L~ink',     cmNothing, kbAltH, nil);
          TvMenu_AddItem('~B~uild All',cmNothing, kbAltH, nil);
        TvMenu_EndSub;
      end;
  end;

  // Exit item is present in every variant
  TvMenu_AddSub('E~x~it', TV_kbAltX);
    TvMenu_AddItem('E~x~it', TV_cmQuit, TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;

  Result := TvMenu_FinishBar;
end;

// ---- Builder callbacks ------------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  Result := BuildMenu(ARect, GCurMenu);
end;

function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit', TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~Alt-N~ Next menu', kbAltN, cmCycle);
  TvStatus_AddItem('', TV_kbF10, TV_cmMenu);
  Result := TvStatus_Finish;
end;

procedure SwitchMenu;
var
  LRect: TTvRect;
  LBar:  TvMenuHandle;
begin
  // Compute the menu-bar rect from the desktop extent
  TvApp_GetExtent(GApp, @LRect);
  LRect.BY := LRect.AY + 1;
  LBar := BuildMenu(@LRect, GCurMenu);
  TvApp_SetMenuBar(GApp, LBar);
end;

function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) = 0 then Exit;

  case AEvent^.Command of
    cmOne, cmTwo, cmThree:
      begin
        GCurMenu := (Integer(AEvent^.Command) - cmOne) mod 3;
        SwitchMenu;
        Result := 1;
      end;
    cmCycle:
      begin
        GCurMenu := (GCurMenu + 1) mod 3;
        SwitchMenu;
        Result := 1;
      end;
    cmNothing:
      begin
        TvMessageBox('Not implemented in this demo.',
                     TV_mfInformation or TV_mfOKButton);
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
