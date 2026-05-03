{*******************************************************************
 *  TVisionDemo.dpr
 *  Console program that calls the tvision DLL from Delphi and shows
 *  a Turbo Vision demo equivalent to the original hello.cpp.
 ******************************************************************}
program TVisionDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TVision in '../../source/TVision.pas';

const
  cmGreet = 100;

var
  GApp: TvAppHandle = nil;

// ---- Menu-bar builder --------------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);

  TvMenu_AddSub('~H~ello', $2300 {kbAltH});
    TvMenu_AddItem('~G~reeting...', cmGreet, $2200 {kbAltG}, nil);
    TvMenu_AddLine;
    TvMenu_AddItem('E~x~it', TV_cmQuit, TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;

  Result := TvMenu_FinishBar;
end;

// ---- Status-line builder -----------------------------------------
function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit', TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('',             TV_kbF10,  TV_cmMenu);
  Result := TvStatus_Finish;
end;

procedure GreetingBox(AApp: TvAppHandle);
var
  LDlgRect, LRect:  TTvRect;
  LDialog:          TvDialogHandle;
begin
  LDlgRect := MakeRect(25, 5, 55, 16);
  LDialog := TvDialog_Create(@LDlgRect, 'Hello, World!');

  LRect := MakeRect(3, 5, 15, 6);
  TvView_Insert(LDialog, TvStaticText_Create(@LRect, 'How are you?'));

  LRect := MakeRect(16, 2, 28, 4);
  TvView_Insert(LDialog, TvButton_Create(@LRect, 'Terrific', TV_cmCancel, TV_bfNormal));

  LRect := MakeRect(16, 4, 28, 6);
  TvView_Insert(LDialog, TvButton_Create(@LRect, 'Ok', TV_cmCancel, TV_bfNormal));

  LRect := MakeRect(16, 6, 28, 8);
  TvView_Insert(LDialog, TvButton_Create(@LRect, 'Lousy', TV_cmCancel, TV_bfNormal));

  LRect := MakeRect(16, 8, 28, 10);
  TvView_Insert(LDialog, TvButton_Create(@LRect, 'Cancel', TV_cmCancel, TV_bfNormal));

  TvApp_ExecView(AApp, LDialog);
  TvView_Destroy(LDialog);
end;

// ---- Event handler -----------------------------------------------
function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) <> 0 then
  begin
    case AEvent^.Command of
      cmGreet:
        begin
          GreetingBox(GApp);
          Result := 1;
        end;
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
