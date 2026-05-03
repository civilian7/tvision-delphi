{*******************************************************************
 *  TvFormsDemo.dpr
 *  Port of tvision/examples/tvforms (PHONENUM form variant).
 *
 *  The original tvforms uses several TInputLine subclasses with
 *  custom valid() logic and persists the form definition through
 *  TStreamable to .f16/.f32 binary files. Both the streaming and
 *  the C++ subclassing rely on tvision internals that aren't
 *  exposed by the wrapper.
 *
 *  This Delphi port keeps the same UX: same field layout (Name,
 *  Company, Remarks, Phone, Type checkboxes, Gender radios), same
 *  sample records, Save/Cancel buttons, Insert/Edit/Delete/Next/
 *  Prev navigation. Validation is done at the application level
 *  when the dialog returns: required-field check on Name (mirrors
 *  TKeyInputLine.valid()).
 ******************************************************************)
program TvFormsDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.AnsiStrings,
  TVision in '../../source/TVision.pas';

const
  // ---- Sample data layout (matches genphone.h widths) ------------
  NAME_WIDTH    = 25;
  COMPANY_WIDTH = 23;
  REMARKS_WIDTH = 22;
  PHONE_WIDTH   = 20;

  // ---- Commands --------------------------------------------------
  cmRecNew    = 200;
  cmRecEdit   = 201;
  cmRecDelete = 202;
  cmRecNext   = 203;
  cmRecPrev   = 204;
  cmAbout     = 210;

  cmFormSave  = 100;       // matches formcmds.h cmFormSave

  kbAltA      = $1E00;
  kbF2        = $3C00;
  kbAltN      = $3100;
  kbAltD      = $2000;
  kbAltLeft   = $9B00;
  kbAltRight  = $9D00;

  // Bit values for the "Type" checkbox set
  TYPE_BUSINESS = $0001;
  TYPE_PERSONAL = $0002;

  // Index values for the "Gender" radio group
  GENDER_MALE   = 0;
  GENDER_FEMALE = 1;

type
  TPhoneRec = record
    Name:    string;
    Company: string;
    Remarks: string;
    Phone:   string;
    AcqType: Word;     // bitset: TYPE_*
    Gender:  Word;     // 0/1
  end;

  // Layout returned by TDialog::getData(). TInputLine writes
  // (length byte + N chars + NUL pad) totalling (max+2) bytes,
  // followed by the cluster fields as 16-bit words.
  TFormBuffer = packed record
    Name:    array[0..NAME_WIDTH + 1]    of AnsiChar;
    Company: array[0..COMPANY_WIDTH + 1] of AnsiChar;
    Remarks: array[0..REMARKS_WIDTH + 1] of AnsiChar;
    Phone:   array[0..PHONE_WIDTH + 1]   of AnsiChar;
    AcqType: Word;
    Gender:  Word;
  end;
  PFormBuffer = ^TFormBuffer;

var
  GApp:    TvAppHandle = nil;
  GData:   TArray<TPhoneRec>;
  GCursor: Integer = 0;

// ---- Sample seed (genphone.h data[] equivalent) ----------------
procedure AddSeed(const AName, ACompany, ARemarks, APhone: string;
                  AAcq, AGender: Word);
var
  LRec: TPhoneRec;
begin
  LRec.Name    := AName;
  LRec.Company := ACompany;
  LRec.Remarks := ARemarks;
  LRec.Phone   := APhone;
  LRec.AcqType := AAcq;
  LRec.Gender  := AGender;
  GData := GData + [LRec];
end;

procedure SeedData;
begin
  SetLength(GData, 0);
  AddSeed('Helton, Andrew',   'Asterisk International', 'Purch. Mgr.',
          '(415) 868-3964',   TYPE_BUSINESS or TYPE_PERSONAL, GENDER_MALE);
  AddSeed('White, Natalie',   'Exclamation, Inc.',      'VP sales',
          '(408) 242-2030',   TYPE_BUSINESS,                GENDER_FEMALE);
  AddSeed('Stern, Peter',     '',                       'Decent violinist',
          '(111) 222-5555',   TYPE_PERSONAL,                GENDER_MALE);
  AddSeed('Whitcom, Hana O.', 'Nate''s girlfriend',     'Birthday: Jan 8, 1990',
          '(408) 426-1234',   TYPE_PERSONAL,                GENDER_FEMALE);
  GCursor := 0;
end;

// ---- TInputLine data block helpers ------------------------------
// TInputLine getData/setData layout: byte 0 = length, bytes 1..N =
// characters, then NUL padding to fill (maxLen + 2). We use the
// AnsiString in/out directly.
procedure StringToInputBuf(const ASrc: string; ABuf: PAnsiChar; AMaxLen: Integer);
var
  LStr: AnsiString;
  LLen: Integer;
begin
  LStr := AnsiString(ASrc);
  LLen := Length(LStr);
  if LLen > AMaxLen then LLen := AMaxLen;
  FillChar(ABuf^, AMaxLen + 2, 0);
  Byte(ABuf^) := LLen;
  if LLen > 0 then
    Move(PAnsiChar(LStr)^, PAnsiChar(@ABuf[1])^, LLen);
end;

function InputBufToString(ABuf: PAnsiChar; AMaxLen: Integer): string;
var
  LLen: Integer;
  LStr: AnsiString;
begin
  LLen := Byte(ABuf^);
  if LLen > AMaxLen then LLen := AMaxLen;
  SetLength(LStr, LLen);
  if LLen > 0 then
    Move(ABuf[1], PAnsiChar(LStr)^, LLen);
  Result := string(LStr);
end;

procedure RecordToBuffer(const ARec: TPhoneRec; out ABuf: TFormBuffer);
begin
  FillChar(ABuf, SizeOf(ABuf), 0);
  StringToInputBuf(ARec.Name,    @ABuf.Name[0],    NAME_WIDTH);
  StringToInputBuf(ARec.Company, @ABuf.Company[0], COMPANY_WIDTH);
  StringToInputBuf(ARec.Remarks, @ABuf.Remarks[0], REMARKS_WIDTH);
  StringToInputBuf(ARec.Phone,   @ABuf.Phone[0],   PHONE_WIDTH);
  ABuf.AcqType := ARec.AcqType;
  ABuf.Gender  := ARec.Gender;
end;

procedure BufferToRecord(const ABuf: TFormBuffer; out ARec: TPhoneRec);
begin
  ARec.Name    := InputBufToString(@ABuf.Name[0],    NAME_WIDTH);
  ARec.Company := InputBufToString(@ABuf.Company[0], COMPANY_WIDTH);
  ARec.Remarks := InputBufToString(@ABuf.Remarks[0], REMARKS_WIDTH);
  ARec.Phone   := InputBufToString(@ABuf.Phone[0],   PHONE_WIDTH);
  ARec.AcqType := ABuf.AcqType;
  ARec.Gender  := ABuf.Gender;
end;

// ---- Build the phonebook form -----------------------------------
function BuildPhoneForm: TvDialogHandle;
const
  formWd     = 41;
  formHt     = 17;
  labelCol   = 1;
  labelWid   = 8;
  inputCol   = 11;
  buttonWd   = 12;
var
  LRect:    TTvRect;
  LDialog:  TvDialogHandle;
  LCtl:     TvViewHandle;
  LItems:   array[0..1] of PAnsiChar;
  Y, X:     Integer;
begin
  LRect := MakeRect(0, 0, formWd, formHt);
  LDialog := TvDialog_Create(@LRect, 'Phone Numbers');
  TvView_SetOptionCentered(LDialog);

  // Name -----------------------------------------------------------
  Y := 2;
  LRect := MakeRect(inputCol, Y, inputCol + NAME_WIDTH + 2, Y + 1);
  LCtl := TvInputLine_Create(@LRect, NAME_WIDTH);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(labelCol, Y, labelCol + labelWid, Y + 1);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~N~ame', LCtl));

  // Company --------------------------------------------------------
  Inc(Y, 2);
  LRect := MakeRect(inputCol, Y, inputCol + COMPANY_WIDTH + 2, Y + 1);
  LCtl := TvInputLine_Create(@LRect, COMPANY_WIDTH);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(labelCol, Y, labelCol + labelWid, Y + 1);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~C~ompany', LCtl));

  // Remarks --------------------------------------------------------
  Inc(Y, 2);
  LRect := MakeRect(inputCol, Y, inputCol + REMARKS_WIDTH + 2, Y + 1);
  LCtl := TvInputLine_Create(@LRect, REMARKS_WIDTH);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(labelCol, Y, labelCol + labelWid, Y + 1);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~R~emarks', LCtl));

  // Phone ----------------------------------------------------------
  Inc(Y, 2);
  LRect := MakeRect(inputCol, Y, inputCol + PHONE_WIDTH + 2, Y + 1);
  LCtl := TvInputLine_Create(@LRect, PHONE_WIDTH);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(labelCol, Y, labelCol + labelWid, Y + 1);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~P~hone', LCtl));

  // Type checkboxes ------------------------------------------------
  X := inputCol;
  Inc(Y, 3);
  LRect := MakeRect(inputCol, Y, inputCol + Length('Business') + 6, Y + 2);
  LItems[0] := 'Business';
  LItems[1] := 'Personal';
  LCtl := TvCheckBoxes_Create(@LRect, @LItems[0], 2);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(X, Y - 1, X + labelWid, Y);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~T~ype', LCtl));

  // Gender radios --------------------------------------------------
  Inc(X, 15);
  LRect := MakeRect(X, Y, X + Length('Female') + 6, Y + 2);
  LItems[0] := 'Male';
  LItems[1] := 'Female';
  LCtl := TvRadioButtons_Create(@LRect, @LItems[0], 2);
  TvView_Insert(LDialog, LCtl);
  LRect := MakeRect(X, Y - 1, X + labelWid, Y);
  TvView_Insert(LDialog, TvLabel_Create(@LRect, '~G~ender', LCtl));

  // Buttons --------------------------------------------------------
  Inc(Y, 3);
  X := formWd - 2 * (buttonWd + 2);
  LRect := MakeRect(X, Y, X + buttonWd, Y + 2);
  TvView_Insert(LDialog, TvButton_Create(@LRect, '~S~ave', TV_cmOK, TV_bfDefault));

  X := formWd - 1 * (buttonWd + 2);
  LRect := MakeRect(X, Y, X + buttonWd, Y + 2);
  TvView_Insert(LDialog, TvButton_Create(@LRect, 'Cancel', TV_cmCancel, TV_bfNormal));

  Result := LDialog;
end;

// ---- Edit one record (modal) ------------------------------------
// Returns True if the user pressed Save AND the data passed
// validation. On True, ARec is updated with the typed values.
function EditRecord(var ARec: TPhoneRec): Boolean;
var
  LDialog: TvDialogHandle;
  LBuf:    TFormBuffer;
  LResult: Word;
  LCand:   TPhoneRec;
begin
  Result := False;
  LDialog := BuildPhoneForm;
  try
    RecordToBuffer(ARec, LBuf);
    TvView_SetData(LDialog, @LBuf);

    while True do
    begin
      LResult := TvApp_ExecView(GApp, LDialog);
      if LResult = TV_cmCancel then Exit;

      TvView_GetData(LDialog, @LBuf);
      BufferToRecord(LBuf, LCand);

      // TKeyInputLine.valid() equivalent: name must not be empty
      if Trim(LCand.Name) = '' then
      begin
        TvMessageBox('This field cannot be empty.',
                     TV_mfError or TV_mfOKButton);
        Continue;     // re-execute the dialog with the same data
      end;

      ARec := LCand;
      Exit(True);
    end;
  finally
    TvView_Destroy(LDialog);
  end;
end;

// ---- Status / record summary as message ------------------------
function FormatRecord(const ARec: TPhoneRec; AIndex, ATotal: Integer): string;
var
  LType: string;
begin
  LType := '';
  if (ARec.AcqType and TYPE_BUSINESS) <> 0 then LType := LType + 'Business ';
  if (ARec.AcqType and TYPE_PERSONAL) <> 0 then LType := LType + 'Personal ';
  if LType = '' then LType := '(none)';

  Result :=
    Format('Record %d / %d'#13#10#13#10, [AIndex + 1, ATotal]) +
    'Name:    ' + ARec.Name + #13#10 +
    'Company: ' + ARec.Company + #13#10 +
    'Remarks: ' + ARec.Remarks + #13#10 +
    'Phone:   ' + ARec.Phone + #13#10 +
    'Type:    ' + Trim(LType) + #13#10 +
    'Gender:  ' + IfThen(ARec.Gender = GENDER_MALE, 'Male', 'Female');
end;

// ---- Browser window (simple custom view showing current rec) ----
// We re-purpose TvCustomView_Create to display a multi-line summary
// of the current record. Up/Down arrows navigate.
type
  PRecPtr = ^Integer;

procedure RecViewDraw(AView: TvViewHandle; AUserData: Pointer); stdcall;
var
  LCx, LCy: Integer;
  LAttr:    Byte;
  LLines:   TArray<string>;
  I:        Integer;
  LText:    AnsiString;
begin
  TvView_GetSize(AView, @LCx, @LCy);
  LAttr := TvView_GetColor(AView, 1);
  TvView_WriteFill(AView, 0, 0, LCx, LCy, ' ', LAttr);

  if Length(GData) = 0 then
  begin
    LText := '(no records)';
    TvView_WriteText(AView, 1, 1, PAnsiChar(LText), LAttr);
    Exit;
  end;

  if GCursor < 0 then GCursor := 0;
  if GCursor >= Length(GData) then GCursor := High(GData);

  LLines := FormatRecord(GData[GCursor], GCursor, Length(GData)).Split([#13#10]);
  for I := 0 to High(LLines) do
  begin
    if I >= LCy then Break;
    LText := AnsiString(LLines[I]);
    if Length(LText) > LCx - 2 then SetLength(LText, LCx - 2);
    TvView_WriteText(AView, 1, I, PAnsiChar(LText), LAttr);
  end;
end;

var
  GBrowser: TvViewHandle = nil;
  GBrowserWin: TvWindowHandle = nil;

procedure RefreshBrowser;
begin
  if GBrowser <> nil then TvView_Redraw(GBrowser);
end;

procedure ShowBrowser;
var
  LWinR, LViewR: TTvRect;
begin
  if GBrowserWin <> nil then
  begin
    RefreshBrowser;
    Exit;
  end;
  TvApp_GetExtent(GApp, @LWinR);
  LWinR.AX := LWinR.AX + 8;
  LWinR.AY := LWinR.AY + 2;
  LWinR.BX := LWinR.BX - 8;
  LWinR.BY := LWinR.BY - 4;

  GBrowserWin := TvWindow_Create(@LWinR, 'Phone book', TV_wnNoNumber);

  LViewR := MakeRect(1, 1,
                     LWinR.BX - LWinR.AX - 2,
                     LWinR.BY - LWinR.AY - 2);
  GBrowser := TvCustomView_Create(@LViewR,
                                  @RecViewDraw, nil, nil, 0, nil);
  TvView_Insert(GBrowserWin, GBrowser);
  TvApp_InsertWindow(GApp, GBrowserWin);
end;

// ---- Operations -------------------------------------------------
procedure RecInsert;
var
  LRec: TPhoneRec;
begin
  LRec := Default(TPhoneRec);
  LRec.Gender := GENDER_MALE;
  if EditRecord(LRec) then
  begin
    GData := GData + [LRec];
    GCursor := High(GData);
    RefreshBrowser;
  end;
end;

procedure RecEdit;
begin
  if Length(GData) = 0 then
  begin
    TvMessageBox('No record to edit.', TV_mfInformation or TV_mfOKButton);
    Exit;
  end;
  if EditRecord(GData[GCursor]) then
    RefreshBrowser;
end;

procedure RecDelete;
var
  I: Integer;
begin
  if Length(GData) = 0 then Exit;
  if TvMessageBox('Delete this record?',
                  TV_mfConfirmation or TV_mfYesNoCancel) <> TV_cmYes then
    Exit;
  for I := GCursor to High(GData) - 1 do
    GData[I] := GData[I + 1];
  SetLength(GData, Length(GData) - 1);
  if GCursor > High(GData) then GCursor := High(GData);
  if GCursor < 0 then GCursor := 0;
  RefreshBrowser;
end;

procedure RecNext;
begin
  if Length(GData) = 0 then Exit;
  Inc(GCursor);
  if GCursor > High(GData) then GCursor := High(GData);
  RefreshBrowser;
end;

procedure RecPrev;
begin
  if GCursor > 0 then Dec(GCursor);
  RefreshBrowser;
end;

// ---- About ------------------------------------------------------
procedure ShowAbout;
var
  LDlgRect, LRect: TTvRect;
  LDialog:         TvDialogHandle;
begin
  LDlgRect := MakeRect(0, 0, 50, 11);
  LDialog := TvDialog_Create(@LDlgRect, 'About TvForms');
  TvView_SetOptionCentered(LDialog);

  LRect := MakeRect(2, 2, 48, 7);
  TvView_Insert(LDialog,
    TvStaticText_Create(@LRect,
      #3'TvForms - phonebook demo'#$0A#3 +
      #3'Delphi port of tvision/examples/tvforms'#$0A +
      #3'Insert / Edit / Delete + Next / Prev'));

  LRect := MakeRect(20, 8, 31, 10);
  TvView_Insert(LDialog,
    TvButton_Create(@LRect, 'OK', TV_cmOK, TV_bfDefault));

  TvApp_ExecView(GApp, LDialog);
  TvView_Destroy(LDialog);
end;

// ---- Menu / status line ----------------------------------------
function MenuBuilder(const ARect: PTvRect; AAppData: Pointer): TvMenuHandle; stdcall;
begin
  TvMenu_BeginBar(ARect);

  TvMenu_AddSub('~R~ecord', $1300 {kbAltR});
    TvMenu_AddItem('~I~nsert',    cmRecNew,    kbAltN, nil);
    TvMenu_AddItem('~E~dit',      cmRecEdit,   kbF2,   'F2');
    TvMenu_AddItem('~D~elete',    cmRecDelete, kbAltD, nil);
    TvMenu_AddLine;
    TvMenu_AddItem('~N~ext',      cmRecNext,   kbAltRight, nil);
    TvMenu_AddItem('~P~revious',  cmRecPrev,   kbAltLeft,  nil);
    TvMenu_AddLine;
    TvMenu_AddItem('E~x~it',      TV_cmQuit,   TV_kbAltX, 'Alt-X');
  TvMenu_EndSub;

  TvMenu_AddSub('~H~elp', $2300 {kbAltH});
    TvMenu_AddItem('~A~bout...', cmAbout, kbAltA, nil);
  TvMenu_EndSub;

  Result := TvMenu_FinishBar;
end;

function StatusBuilder(const ARect: PTvRect; AAppData: Pointer): TvStatusHandle; stdcall;
begin
  TvStatus_Begin(ARect);
  TvStatus_AddItem('~Alt-X~ Exit',   TV_kbAltX, TV_cmQuit);
  TvStatus_AddItem('~F2~ Edit',      kbF2,      cmRecEdit);
  TvStatus_AddItem('~Alt-N~ New',    kbAltN,    cmRecNew);
  TvStatus_AddItem('~Alt-D~ Delete', kbAltD,    cmRecDelete);
  TvStatus_AddItem('',               TV_kbF10,  TV_cmMenu);
  Result := TvStatus_Finish;
end;

// ---- Event handler ---------------------------------------------
function EventHandler(const AEvent: PTvEvent; AAppData: Pointer): Integer; stdcall;
begin
  Result := 0;
  if (AEvent^.What and TV_evCommand) = 0 then Exit;

  case AEvent^.Command of
    cmRecNew:    begin RecInsert; Result := 1; end;
    cmRecEdit:   begin RecEdit;   Result := 1; end;
    cmRecDelete: begin RecDelete; Result := 1; end;
    cmRecNext:   begin RecNext;   Result := 1; end;
    cmRecPrev:   begin RecPrev;   Result := 1; end;
    cmAbout:     begin ShowAbout; Result := 1; end;
  end;
end;

var
  LApp: TvAppHandle;
begin
  try
    SeedData;
    LApp := TvApp_Create(@MenuBuilder, @StatusBuilder, @EventHandler, nil, nil);
    if LApp = nil then
    begin
      Writeln('TvApp_Create failed.');
      Exit;
    end;
    GApp := LApp;
    try
      ShowBrowser;
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
