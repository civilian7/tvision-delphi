{*******************************************************************
 *  TvPaletteDemo.dpr
 *  Port of tvision/examples/palette  (palette.cpp + test.cpp).
 *
 *  Reproduces TTestView (a C++ TView subclass with a custom draw
 *  and a custom palette) using the wrapper's TvCustomView_Create
 *  callback mechanism.
 ******************************************************************)
program TvPaletteDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  TVision in '../../source/TVision.pas';

const
  cmAbout       = 200;
  cmPaletteView = 201;

  // palette.cpp: cpTestView = "\x9\xA\xB\xC\xD\xE"
  // Six palette indices. Each byte is a slot in the system palette
  // (cpAppColor) that the view will resolve through getColor().
  cpTestView: array[0..5] of AnsiChar = (#9, #10, #11, #12, #13, #14);

  TEST_WIDTH  = 50;   // TEST_WIDTH from palette.h
  TEST_HEIGHT = 9;

  kbAltA = $1E00;
  kbAltP = $1900;

var
  GApp: TvAppHandle = nil;

// ---- Custom-view draw callback ---------------------------------
// Mirrors TTestView::draw() from the original palette.cpp:
//   each palette index draws one line in its resolved color, and
//   the last line bypasses the palette altogether and is drawn with
//   raw attribute 5 (purple-on-black).
procedure CustomViewDraw(AView: TvViewHandle; AUserData: Pointer); stdcall;
var
  LCx, LCy: Integer;
  I:        Integer;
  LAttr:    Byte;
  LText:    AnsiString;
begin
  TvView_GetSize(AView, @LCx, @LCy);

  for I := 1 to 6 do
  begin
    LAttr := TvView_GetColor(AView, I);
    LText := AnsiString(Format(' This line uses index %0.2X, color is %0.2X ',
                               [I, LAttr]));
    // Fill the line first, then write the text on top
    TvView_WriteFill(AView, 0, I - 1, LCx, 1, ' ', LAttr);
    TvView_WriteText(AView, 0, I - 1, PAnsiChar(LText), LAttr);
  end;

  // Palette bypass: always drawn with attr 5 (purple/black-ish)
  LText := '   This line bypasses the palettes!    ';
  TvView_WriteFill(AView, 0, 6, LCx, 1, ' ', 5);
  TvView_WriteText(AView, 0, 6, PAnsiChar(LText), 5);
end;

// ---- TTestWindow equivalent ------------------------------------
// The original is a TWindow subclass with its own getPalette
// override; this port uses a plain window and inserts the custom
// view inside it instead.
procedure ShowPaletteView;
var
  LWinRect, LViewRect: TTvRect;
  LWin:  TvWindowHandle;
  LView: TvViewHandle;
begin
  LWinRect := MakeRect(0, 0, TEST_WIDTH, TEST_HEIGHT);
  LWin := TvWindow_Create(@LWinRect, 'Palette Test', TV_wnNoNumber);
  TvView_SetOptionCentered(LWin);

  // Inside the frame: (1,1)..(width-2, height-2)
  LViewRect := MakeRect(1, 1, TEST_WIDTH - 2, TEST_HEIGHT - 2);
  LView := TvCustomView_Create(@LViewRect,
                               @CustomViewDraw,
                               nil,
                               @cpTestView[0], Length(cpTestView),
                               nil);
  TvView_Insert(LWin, LView);

  TvApp_InsertWindow(GApp, LWin);
end;

// ---- About dialog ----------------------------------------------
procedure ShowAbout;
var
  LDlgRect, LRect: TTvRect;
  LDialog:         TvDialogHandle;
begin
  LDlgRect := MakeRect(0, 0, 47, 13);
  LDialog := TvDialog_Create(@LDlgRect, 'About');

  LRect := MakeRect(2, 1, 45, 9);
  TvView_Insert(LDialog,
    TvStaticText_Create(@LRect,
      #$0A#3'PALETTE EXAMPLE'#$0A' '#$0A +
      #3'A Turbo Vision Demo'#$0A' '#$0A +
      #3'written by'#$0A' '#$0A +
      #3'Borland C++ Tech Support'#$0A));

  LRect := MakeRect(18, 10, 29, 12);
  TvView_Insert(LDialog,
    TvButton_Create(@LRect, 'OK', TV_cmOK, TV_bfDefault));

  TvView_SetOptionCentered(LDialog);
  TvApp_ExecView(GApp, LDialog);
  TvView_Destroy(LDialog);
end;

// ---- Menu / status line ----------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);
  TvMenu_AddSub('~T~est', $1400 {kbAltT});
    TvMenu_AddItem('~A~bout...',  cmAbout,       kbAltA, nil);
    TvMenu_AddItem('~P~alette',   cmPaletteView, kbAltP, nil);
    TvMenu_AddItem('E~x~it',      TV_cmQuit,     TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;
  Result := TvMenu_FinishBar;
end;

function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit',    TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~Alt-P~ Palette', kbAltP,    cmPaletteView);
  TvStatus_AddItem('',                TV_kbF10,  TV_cmMenu);
  Result := TvStatus_Finish;
end;

// ---- Event handler ----------------------------------------------
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
    cmPaletteView:
      begin
        ShowPaletteView;
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
