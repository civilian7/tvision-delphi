{*******************************************************************
 *  AvsColor.dpr
 *  Port of tvision/examples/avscolor (termcolor.cpp).
 *
 *  The original is an AviSynth video filter plugin (.dll loaded by
 *  AVS+) that demonstrates the four terminal-color quantizations
 *  used by Turbo Vision: indexed8, indexed16, indexed256, direct.
 *  AVS+ is not relevant in a Delphi context, so this port is a
 *  standalone CLI: it takes a PPM (P6, 24-bit) image, runs each
 *  pixel through the wrapper's quantization helpers, and writes
 *  one output PPM per mode.
 *
 *  Usage:
 *    AvsColor [<input.ppm>] [<out_basename>]
 *      input.ppm    - 24-bit binary PPM. If omitted, a synthetic
 *                     256x64 RGB gradient is generated.
 *      out_basename - prefix for the four output files. Defaults
 *                     to the input basename or "gradient".
 *
 *  Output: <base>.indexed8.ppm  <base>.indexed16.ppm
 *          <base>.indexed256.ppm <base>.direct.ppm
 ******************************************************************)
program AvsColor;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  TVision in '../../source/TVision.pas';

type
  TPixel = packed record
    R, G, B: Byte;
  end;

  TImage = record
    Width, Height: Integer;
    Pixels:        array of TPixel;
  end;

procedure ErrorExit(const AMsg: string);
begin
  Writeln(ErrOutput, 'Error: ', AMsg);
  Halt(1);
end;

// ---- PPM I/O (P6, 8-bit per channel) ----------------------------
procedure ReadPpm(const AFileName: string; var AImg: TImage);
var
  LStream: TFileStream;
  LLine:   AnsiString;
  LCh:     AnsiChar;
  LMaxVal: Integer;
  LBytes:  TBytes;
  I:       Integer;

  // Read one whitespace-terminated token, skipping comments
  function ReadToken: AnsiString;
  var
    LAcc: AnsiString;
  begin
    LAcc := '';
    repeat
      while (LStream.Read(LCh, 1) = 1) and CharInSet(LCh, [' ', #9, #10, #13]) do ;
      if LCh = '#' then
      begin
        // skip until end of line
        while (LStream.Read(LCh, 1) = 1) and (LCh <> #10) do ;
        Continue;
      end;
      LAcc := LAcc + LCh;
      while LStream.Read(LCh, 1) = 1 do
      begin
        if CharInSet(LCh, [' ', #9, #10, #13]) then Break;
        LAcc := LAcc + LCh;
      end;
      Exit(LAcc);
    until False;
  end;

begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LLine := ReadToken;
    if LLine <> 'P6' then
      ErrorExit('Only binary P6 PPM is supported (got "' + string(LLine) + '")');

    AImg.Width  := StrToInt(string(ReadToken));
    AImg.Height := StrToInt(string(ReadToken));
    LMaxVal     := StrToInt(string(ReadToken));
    if LMaxVal <> 255 then
      ErrorExit('Only 8-bit PPM supported (maxval=' + IntToStr(LMaxVal) + ')');

    SetLength(AImg.Pixels, AImg.Width * AImg.Height);
    SetLength(LBytes, Length(AImg.Pixels) * 3);
    if LStream.Read(LBytes[0], Length(LBytes)) <> Length(LBytes) then
      ErrorExit('Unexpected EOF in pixel data');

    for I := 0 to High(AImg.Pixels) do
    begin
      AImg.Pixels[I].R := LBytes[I * 3 + 0];
      AImg.Pixels[I].G := LBytes[I * 3 + 1];
      AImg.Pixels[I].B := LBytes[I * 3 + 2];
    end;
  finally
    LStream.Free;
  end;
end;

procedure WritePpm(const AFileName: string; const AImg: TImage);
var
  LStream: TFileStream;
  LHeader: AnsiString;
  LBytes:  TBytes;
  I:       Integer;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    LHeader := AnsiString(Format('P6'#10'%d %d'#10'255'#10,
                                 [AImg.Width, AImg.Height]));
    LStream.WriteBuffer(PAnsiChar(LHeader)^, Length(LHeader));

    SetLength(LBytes, Length(AImg.Pixels) * 3);
    for I := 0 to High(AImg.Pixels) do
    begin
      LBytes[I * 3 + 0] := AImg.Pixels[I].R;
      LBytes[I * 3 + 1] := AImg.Pixels[I].G;
      LBytes[I * 3 + 2] := AImg.Pixels[I].B;
    end;
    LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free;
  end;
end;

// ---- Synthetic gradient generator -------------------------------
procedure MakeGradient(var AImg: TImage);
var
  X, Y: Integer;
  P:    ^TPixel;
  T:    Single;
begin
  AImg.Width  := 256;
  AImg.Height := 64;
  SetLength(AImg.Pixels, AImg.Width * AImg.Height);
  for Y := 0 to AImg.Height - 1 do
    for X := 0 to AImg.Width - 1 do
    begin
      P := @AImg.Pixels[Y * AImg.Width + X];
      T := X / (AImg.Width - 1);
      // Top half: hue-style RGB sweep. Bottom half: grayscale.
      if Y < AImg.Height div 2 then
      begin
        P.R := Round(255 * Abs(Sin(T * Pi * 2)));
        P.G := Round(255 * Abs(Sin(T * Pi * 2 + Pi * 2 / 3)));
        P.B := Round(255 * Abs(Sin(T * Pi * 2 + Pi * 4 / 3)));
      end
      else
      begin
        P.R := Round(255 * T);
        P.G := P.R;
        P.B := P.R;
      end;
    end;
end;

// ---- Quantization passes ----------------------------------------
// Mirrors the four FrameProcessor variants in termcolor.cpp.
type
  TQuantizeMode = (qmIndexed8, qmIndexed16, qmIndexed256, qmDirect);

const
  // Same xterm16 -> RGB table as in termcolor.cpp.
  XTerm16toRGB: array[0..15] of Cardinal =
    ($000000, $800000, $008000, $808000,
     $000080, $800080, $008080, $C0C0C0,
     $808080, $FF0000, $00FF00, $FFFF00,
     $0000FF, $FF00FF, $00FFFF, $FFFFFF);

function PixelToU32(const AP: TPixel): Cardinal; inline;
begin
  Result := (Cardinal(AP.R) shl 16) or (Cardinal(AP.G) shl 8) or Cardinal(AP.B);
end;

procedure U32ToPixel(AVal: Cardinal; out AP: TPixel); inline;
begin
  AP.R := (AVal shr 16) and $FF;
  AP.G := (AVal shr 8)  and $FF;
  AP.B :=  AVal         and $FF;
end;

procedure Quantize(const ASrc: TImage; var ADst: TImage; AMode: TQuantizeMode);
var
  X, Y: Integer;
  LIn:  Cardinal;
  LOut: Cardinal;
  LIdx: Byte;
begin
  ADst.Width  := ASrc.Width;
  ADst.Height := ASrc.Height;
  SetLength(ADst.Pixels, Length(ASrc.Pixels));

  for Y := 0 to ASrc.Height - 1 do
    for X := 0 to ASrc.Width - 1 do
    begin
      LIn := PixelToU32(ASrc.Pixels[Y * ASrc.Width + X]);
      case AMode of
        qmIndexed8:
          begin
            // Like the original: simulate 8-color palette by
            // dropping the bright bit on every other line.
            LIdx := TvColor_RGBtoXTerm16(LIn);
            if (LIdx >= 8) and ((Y and 1) <> 0) then Dec(LIdx, 8);
            LOut := XTerm16toRGB[LIdx];
          end;
        qmIndexed16:
          begin
            LIdx := TvColor_RGBtoXTerm16(LIn);
            LOut := XTerm16toRGB[LIdx];
          end;
        qmIndexed256:
          begin
            LIdx := TvColor_RGBtoXTerm256(LIn);
            LOut := TvColor_XTerm256toRGB(LIdx);
          end;
      else
        LOut := LIn;   // qmDirect: 24-bit truecolor passthrough
      end;
      U32ToPixel(LOut, ADst.Pixels[Y * ASrc.Width + X]);
    end;
end;

// ---- Main -------------------------------------------------------
var
  LIn, LBase: string;
  LImg, LOut: TImage;
  LMode:      TQuantizeMode;
const
  Suffix: array[TQuantizeMode] of string =
    ('.indexed8', '.indexed16', '.indexed256', '.direct');
begin
  try
    LIn   := '';
    LBase := '';
    if ParamCount >= 1 then LIn   := ParamStr(1);
    if ParamCount >= 2 then LBase := ParamStr(2);

    if LIn = '' then
    begin
      Writeln('No input file - generating 256x64 RGB gradient.');
      MakeGradient(LImg);
      if LBase = '' then LBase := 'gradient';
    end
    else
    begin
      if not FileExists(LIn) then
        ErrorExit('File not found: ' + LIn);
      ReadPpm(LIn, LImg);
      if LBase = '' then LBase := ChangeFileExt(LIn, '');
    end;

    Writeln(Format('Image: %d x %d (%d pixels)',
                   [LImg.Width, LImg.Height, Length(LImg.Pixels)]));

    for LMode := Low(TQuantizeMode) to High(TQuantizeMode) do
    begin
      Quantize(LImg, LOut, LMode);
      WritePpm(LBase + Suffix[LMode] + '.ppm', LOut);
      Writeln('  wrote ', LBase + Suffix[LMode] + '.ppm');
    end;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
