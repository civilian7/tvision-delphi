{*******************************************************************
 *  TvHc.dpr
 *  Port of tvision/examples/tvhc (help compiler).
 *
 *  The original tvhc produces two artifacts:
 *    1) a binary THelpFile (.h32) - tvision's internal format
 *    2) a C++ header (.h) with `const int hcXxx = N;`
 *
 *  This port only emits (2). The THelpFile binary format is out of
 *  scope for the wrapper. As a bonus we also emit a Delphi unit
 *  (.pas) with the same constants.
 *
 *  Supported input syntax (same as the original):
 *    .topic Symbol[=N] [, Symbol2[=N2] ...]
 *      <body - ignored>
 *
 *  Usage:
 *    TvHc <input.txt> [out_basename] [-pas|-h]
 *      -pas : emit only the Delphi unit (default: emit both)
 *      -h   : emit only the C header
 ******************************************************************)
program TvHc;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils;

const
  MAXHELPTOPICID = 16379;

type
  TTopic = record
    Symbol: string;
    Value:  Integer;
  end;
  TTopicArray = TArray<TTopic>;

type
  PROCESSENTRY32W = record
    dwSize:              DWORD;
    cntUsage:            DWORD;
    th32ProcessID:       DWORD;
    th32DefaultHeapID:   ULONG_PTR;
    th32ModuleID:        DWORD;
    cntThreads:          DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase:      LongInt;
    dwFlags:             DWORD;
    szExeFile:           array[0..MAX_PATH - 1] of WideChar;
  end;

const
  TH32CS_SNAPPROCESS = $00000002;

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle; stdcall;
  external kernel32 name 'CreateToolhelp32Snapshot';
function Process32FirstW(hSnapshot: THandle; var lppe: PROCESSENTRY32W): BOOL; stdcall;
  external kernel32 name 'Process32FirstW';
function Process32NextW(hSnapshot: THandle; var lppe: PROCESSENTRY32W): BOOL; stdcall;
  external kernel32 name 'Process32NextW';

// Returns True when the program was launched by double-clicking it
// in Explorer (no shell parent). We walk up the process tree looking
// for an explorer.exe ancestor; if the parent is cmd / powershell /
// pwsh / bash / mintty / wt etc. we assume the user is running
// interactively and skip the "Press Enter" prompt.
function LaunchedFromExplorer: Boolean;
var
  LSnap:   THandle;
  LEntry:  PROCESSENTRY32W;
  LSelf:   DWORD;
  LParent: DWORD;
  LName:   string;
  LFound:  Boolean;
  LDepth:  Integer;
begin
  Result := False;
  LSelf  := GetCurrentProcessId;
  LSnap  := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if LSnap = INVALID_HANDLE_VALUE then Exit;
  try
    LParent := 0;
    LDepth  := 0;
    while LDepth < 6 do
    begin
      Inc(LDepth);
      LEntry := Default(PROCESSENTRY32W);
      LEntry.dwSize := SizeOf(LEntry);
      LFound := False;
      if Process32FirstW(LSnap, LEntry) then
      repeat
        if LEntry.th32ProcessID = LSelf then
        begin
          LParent := LEntry.th32ParentProcessID;
          LName := '';
          LFound := True;
          Break;
        end;
      until not Process32NextW(LSnap, LEntry);
      if not LFound or (LParent = 0) then Exit;

      // Look up the parent's exe name
      LEntry := Default(PROCESSENTRY32W);
      LEntry.dwSize := SizeOf(LEntry);
      if Process32FirstW(LSnap, LEntry) then
      repeat
        if LEntry.th32ProcessID = LParent then
        begin
          LName := LowerCase(LEntry.szExeFile);
          LSelf := LParent;
          LParent := LEntry.th32ParentProcessID;
          Break;
        end;
      until not Process32NextW(LSnap, LEntry);

      if LName = 'explorer.exe' then Exit(True);
      if (LName = 'cmd.exe') or (LName = 'powershell.exe') or
         (LName = 'pwsh.exe') or (LName = 'bash.exe') or
         (LName = 'sh.exe')   or (LName = 'mintty.exe') or
         (LName = 'wt.exe')   or (LName = 'windowsterminal.exe') or
         (LName = 'conhost.exe') then
        Exit(False);
    end;
  finally
    CloseHandle(LSnap);
  end;
end;

procedure PauseIfStandalone;
begin
  if LaunchedFromExplorer then
  begin
    Writeln;
    Write('Press Enter to close . . . ');
    Readln;
  end;
end;

procedure ErrorExit(const AMessage: string; ALine: Integer = -1);
begin
  if ALine >= 0 then
    Writeln(ErrOutput, Format('Error (line %d): %s', [ALine, AMessage]))
  else
    Writeln(ErrOutput, 'Error: ', AMessage);
  PauseIfStandalone;
  Halt(1);
end;

// ---- Token extraction (matches the original getWord) -----------
// A run of alpha/digit/underscore characters is one word; anything
// else is returned as a single-character token.
function IsValidWordChar(AC: Char): Boolean; inline;
begin
  Result := CharInSet(AC, ['A'..'Z','a'..'z','0'..'9','_']);
end;

function GetWord(const ALine: string; var APos: Integer): string;
var
  LStart: Integer;
begin
  // skipWhite
  while (APos <= Length(ALine)) and CharInSet(ALine[APos], [' ', #9]) do
    Inc(APos);
  if APos > Length(ALine) then Exit('');

  LStart := APos;
  if IsValidWordChar(ALine[APos]) then
  begin
    while (APos <= Length(ALine)) and IsValidWordChar(ALine[APos]) do
      Inc(APos);
  end
  else
  begin
    Inc(APos);  // single-character punctuation token
  end;
  Result := Copy(ALine, LStart, APos - LStart);
end;

function IsNumeric(const AStr: string): Boolean;
var
  LDummy: Integer;
begin
  Result := (AStr <> '') and TryStrToInt(AStr, LDummy);
end;

// ---- .topic header parser ---------------------------------------
// Like the original topicDefinitionList: handles multiple
// comma-separated definitions on one line.
function ParseTopicHeader(const ALine: string;
                          var AHelpCounter: Integer;
                          ALineNo: Integer): TTopicArray;
var
  LPos:    Integer;
  LWord:   string;
  LSymbol: string;
  LTopic:  TTopic;
  LCount:  Integer;
begin
  Result := nil;
  LCount := 0;
  SetLength(Result, 8);

  LPos := 1;
  LWord := GetWord(ALine, LPos);
  if LWord <> '.' then
    ErrorExit('not a topic header line', ALineNo);

  LWord := GetWord(ALine, LPos);
  if not SameText(LWord, 'topic') then
    ErrorExit('TOPIC expected', ALineNo);

  // One or more symbol[=N] entries, separated by commas
  repeat
    LSymbol := GetWord(ALine, LPos);
    if LSymbol = '' then
      ErrorExit('Expected topic definition', ALineNo);

    LWord := GetWord(ALine, LPos);
    if LWord = '=' then
    begin
      LWord := GetWord(ALine, LPos);
      if not IsNumeric(LWord) then
        ErrorExit('Expected numeric value after "="', ALineNo);
      AHelpCounter := StrToInt(LWord);
      LWord := GetWord(ALine, LPos);  // next token (comma or EOL)
    end
    else
      Inc(AHelpCounter);

    if AHelpCounter > MAXHELPTOPICID then
      ErrorExit(Format('Topic id for "%s" exceeds limit %d',
                       [LSymbol, MAXHELPTOPICID]), ALineNo);

    LTopic.Symbol := LSymbol;
    LTopic.Value  := AHelpCounter;

    if LCount = Length(Result) then
      SetLength(Result, LCount * 2);
    Result[LCount] := LTopic;
    Inc(LCount);
  until LWord <> ',';

  SetLength(Result, LCount);
end;

// ---- Robust file loader (try several encodings) -----------------
// Original tvhc help sources are typically CP437 (DOS box-drawing).
// Korean / Japanese Windows would otherwise mangle them on load.
function LoadTextFile(const AFileName: string; ATarget: TStringList): Boolean;
var
  LCandidates: array of TEncoding;
  LFreeMask:   array of Boolean;
  I:           Integer;
begin
  Result := False;
  LCandidates := [
    TEncoding.UTF8,
    TEncoding.Default,
    TEncoding.GetEncoding(437),    // CP437 — original tvhc help format
    TEncoding.GetEncoding(1252),   // Western Latin-1
    TEncoding.ANSI
  ];
  // Only the encodings obtained via GetEncoding(...) need to be freed;
  // the singleton instances (UTF8/Default/ANSI) must NOT be freed.
  SetLength(LFreeMask, Length(LCandidates));
  for I := 0 to High(LCandidates) do
    LFreeMask[I] := (LCandidates[I] <> TEncoding.UTF8) and
                    (LCandidates[I] <> TEncoding.Default) and
                    (LCandidates[I] <> TEncoding.ANSI);

  for I := 0 to High(LCandidates) do
  begin
    try
      ATarget.LoadFromFile(AFileName, LCandidates[I]);
      Result := True;
      Break;
    except
      // try next encoding
    end;
  end;

  for I := 0 to High(LCandidates) do
    if LFreeMask[I] then LCandidates[I].Free;
end;

function ProcessFile(const AFileName: string): TTopicArray;
var
  LText:        TStringList;
  I, LCounter, LCount: Integer;
  LLine:        string;
  LBatch:       TTopicArray;
  J:            Integer;
begin
  Result := nil;
  LCount := 0;
  SetLength(Result, 32);

  LText := TStringList.Create;
  try
    if not LoadTextFile(AFileName, LText) then
      ErrorExit(Format('Could not read file: %s', [AFileName]));
    for I := 0 to LText.Count - 1 do
    begin
      LLine := Trim(LText[I]);
      if (LLine = '') or (LLine[1] <> '.') then Continue;

      // Ignore any non-.topic command lines (the original is similarly lax)
      if not StartsText('.topic', LLine) then Continue;

      LBatch := ParseTopicHeader(LLine, LCounter, I + 1);
      for J := 0 to High(LBatch) do
      begin
        if LCount = Length(Result) then
          SetLength(Result, LCount * 2);
        Result[LCount] := LBatch[J];
        Inc(LCount);
      end;
    end;
  finally
    LText.Free;
  end;
  SetLength(Result, LCount);
end;

// ---- Emitters ---------------------------------------------------
procedure WriteCHeader(const AFileName: string; const ATopics: TTopicArray);
var
  LSL: TStringList;
  I:   Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.Add('// Generated by TvHc (Delphi port)');
    LSL.Add('#ifndef HC_GENERATED_H');
    LSL.Add('#define HC_GENERATED_H');
    LSL.Add('');
    LSL.Add('const int');
    for I := 0 to High(ATopics) do
    begin
      if I < High(ATopics) then
        LSL.Add(Format('    hc%-20s = %d,', [ATopics[I].Symbol, ATopics[I].Value]))
      else
        LSL.Add(Format('    hc%-20s = %d;', [ATopics[I].Symbol, ATopics[I].Value]));
    end;
    LSL.Add('');
    LSL.Add('#endif');
    LSL.SaveToFile(AFileName);
  finally
    LSL.Free;
  end;
end;

procedure WritePasUnit(const AFileName, AUnitName: string;
                      const ATopics: TTopicArray);
var
  LSL: TStringList;
  I:   Integer;
begin
  LSL := TStringList.Create;
  try
    LSL.Add('// Generated by TvHc (Delphi port)');
    LSL.Add('unit ' + AUnitName + ';');
    LSL.Add('');
    LSL.Add('interface');
    LSL.Add('');
    LSL.Add('const');
    for I := 0 to High(ATopics) do
      LSL.Add(Format('  hc%-20s = %d;', [ATopics[I].Symbol, ATopics[I].Value]));
    LSL.Add('');
    LSL.Add('implementation');
    LSL.Add('');
    LSL.Add('end.');
    LSL.SaveToFile(AFileName);
  finally
    LSL.Free;
  end;
end;

// ---- Main ------------------------------------------------------
procedure PrintHelp;
begin
  Writeln('TvHc - Help context compiler (Delphi port)');
  Writeln;
  Writeln('Usage: TvHc <input[.txt]> [out_basename] [-pas|-h]');
  Writeln('  -pas : emit Delphi unit only');
  Writeln('  -h   : emit C header only');
  Writeln('  (omit both flags to emit C header and Delphi unit)');
end;

var
  LIn, LBase, LMode: string;
  LTopics:           TTopicArray;
  I:                 Integer;
  LEmitH, LEmitPas:  Boolean;
begin
  if ParamCount < 1 then
  begin
    PrintHelp;
    PauseIfStandalone;
    Halt(1);
  end;

  LIn := ParamStr(1);
  if not FileExists(LIn) and FileExists(LIn + '.txt') then
    LIn := LIn + '.txt';
  if not FileExists(LIn) then
    ErrorExit(Format('File not found: %s', [LIn]));

  LBase := ChangeFileExt(LIn, '');
  LEmitH := True;
  LEmitPas := True;

  for I := 2 to ParamCount do
  begin
    LMode := ParamStr(I);
    if LMode = '-pas' then
    begin
      LEmitH := False; LEmitPas := True;
    end
    else if LMode = '-h' then
    begin
      LEmitH := True; LEmitPas := False;
    end
    else if not LMode.StartsWith('-') then
      LBase := LMode;
  end;

  try
    LTopics := ProcessFile(LIn);
    if Length(LTopics) = 0 then
    begin
      Writeln(ErrOutput, 'No .topic directives found in ', LIn);
      Halt(1);
    end;

    if LEmitH then
    begin
      WriteCHeader(LBase + '.h', LTopics);
      Writeln('Wrote ', LBase, '.h (', Length(LTopics), ' topics)');
    end;
    if LEmitPas then
    begin
      WritePasUnit(LBase + 'Help.pas', ExtractFileName(LBase) + 'Help', LTopics);
      Writeln('Wrote ', LBase, 'Help.pas (', Length(LTopics), ' topics)');
    end;
    PauseIfStandalone;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      PauseIfStandalone;
      Halt(1);
    end;
  end;
end.
