{                          ---BEGIN LICENSE BLOCK---                           }
{                                                                              }
{ Hextor - Hexadecimal editor and binary data analyzing toolkit                }
{ Copyright (C) 2019-2022  Grigoriy Mylnikov (DigitalWolF) <info@hextor.net>   }
{ Hextor is a Freeware Source-Available software. See LICENSE.txt for details  }
{                                                                              }
{                           ---END LICENSE BLOCK---                            }

unit uHextorTypes;

interface

uses
  Winapi.Windows, Winapi.ShLwApi, SysUtils, System.Classes, Generics.Collections,
  Vcl.Graphics, System.Math, System.SysConst, System.Variants, superobject,
  System.IOUtils, System.Types, System.Masks,

  uCallbackList;

const
  KByte = 1024;
  MByte = 1024*1024;
  GByte = 1024*1024*1024;
  TerraByte: Int64 = Int64(1024)*1024*1024*1024;
  PetaByte:  Int64 = Int64(1024)*1024*1024*1024*1024;
  ExaByte:   Int64 = Int64(1024)*1024*1024*1024*1024*1024;

  HexCharsSet: TSysCharSet = ['0'..'9', 'A'..'F', 'a'..'f'];

  CharsInvalidInFileName = '/\:*?"<>|';

  // Null character cannot be copied to clipboard. Replace with this value.
  NullCharClipboardReplace = #$FFFD;

  cDay = 1.0;
  cHour = cDay / 24;
  cMinute = cHour / 60;
  cSecond = cMinute / 60;
  cMillisecond = cSecond / 1000;

type
  // Address inside file/data source
  TFilePointer = Int64;

  TFileRange = record
  private
    function GetSize(): TFilePointer; inline;
    procedure SetSize(Value: TFilePointer); inline;
  public
    Start, AEnd: TFilePointer;
    property Size: TFilePointer read GetSize write SetSize;
    function Intersects(const BRange: TFileRange): Boolean; overload; inline;
    function Intersects(BStart, BEnd: TFilePointer): Boolean; overload; inline;
    function Intersects(Value: TFilePointer): Boolean; overload; inline;
    function Intersects2(const BRange: TFileRange): Boolean; overload; inline;
    function Intersects2(BStart, BEnd: TFilePointer): Boolean; overload; inline;
    class operator Equal(const A, B: TFileRange): Boolean; inline;
    class operator NotEqual(const A, B: TFileRange): Boolean; inline;
    class operator Add(const A, B: TFileRange): TFileRange; inline;
    constructor Create(BStart, BEnd: TFilePointer);
  end;

  TVariantRange = record
    AStart, AEnd: Variant;
    constructor Create(AStart, AEnd: Variant);
  end;
  TVariantRanges = record
    Ranges: TArray<TVariantRange>;
    function Contains(const Value: Variant): Boolean;
    function IsEmpty(): Boolean;
  end;

  TValueDisplayNotation = (nnDefault, nnBin, nnOct, nnDec, nnHex, nnAChar, nnWChar);

  EInvalidUserInput = class (Exception);
  ENoActiveEditor = class (EAbort);

  // Bookmarks, Selected range, Structure field etc. marked on data by some tool
  TTaggedDataRegion = class
    Owner: TObject;
    Data: Pointer;
    Range: TFileRange;
//    ZOrder: Integer;
    TextColor, BgColor, FrameColor: TColor;
    //OnGetHint, OnPopup
    constructor Create(AOwner: TObject; ARange: TFileRange;
      ATextColor, ABgColor, AFrameColor: TColor);
    function Accepted(): Boolean;
  end;
  TTaggedDataRegionList = class (TObjectList<TTaggedDataRegion>)
  public
    AcceptRange: TFileRange;
    function AddRegion(Owner: TObject; RangeStart, RangeEnd: TFilePointer; TextColor, BgColor, FrameColor: TColor;
      Data: Pointer = nil; CanAppend: Boolean = false): TTaggedDataRegion;
    constructor Create(); overload;
    constructor Create(const AAcceptRange: TFileRange); overload;
  end;

  // Wrapper around TBytes for scripts
  TByteBuffer = class (TInterfacedObject, IInterface)
  public
    Data: TBytes;
  end;

  IHextorToolFrame = interface
    ['{4AB18488-6B7D-4A9B-9892-EC91DDF81745}']
    procedure OnShown();
    procedure Init();
    procedure Uninit();
  end;

  // Convert structures<==>json  (helper wrapper)
  tJsonRtti = class
    class function ObjectToStr<T>(const obj: T; const ANotWriteEmptyField: boolean = false): string;
    class function StrToObject<T>(const S: string): T;
  end;

  // Manages progress reported by tasks and sub-tasks and passes it to
  // main GUI for display.
  // Any worker can create sub-tasks and define their portions of parent task's work.
  // Sub-tasks will report their own progress. Progress tracker calculates
  // total progress at any time moment.
  TProgressTracker = class
  public type
    TTask = class
      Worker: TObject;
      Portion: Double;     // What portion of parent task this task occupies
      Abortable: Boolean;  // Allow user to abort this task ("False" is inherited by sub-tasks)
      TotalWorkFrom, TotalWorkTo: Double; // What portion of overall work this task occupies
      StartTime: Cardinal;
      Progress: Double;    // Current (relative) progress of this task
    end;
  protected
    TaskStack: TObjectStack<TTask>;
    FTotalProgress: Double;
    FLastText: string;
    LastDisplay: Cardinal;
    FDisplayInterval: Cardinal;
    function GetCurrentTask(): TTask;
  public
    OnTaskStart: TCallbackListP2<{Sender: }TProgressTracker, {Task: }TTask>;  // Called with Task already in stack
    OnTaskEnd: TCallbackListP2<{Sender: }TProgressTracker, {Task: }TTask>;    // Called with Task still in stack
    OnDisplay: TCallbackListP3<{Sender: }TProgressTracker, {TotalProgress: }Double, {Text: }string>;
    OnAborting: TCallbackListP2<{Sender: }TProgressTracker, {CanAbort: }PBoolean>;
    constructor Create();
    destructor Destroy(); override;
    property DisplayInterval: Cardinal read FDisplayInterval write FDisplayInterval;
    procedure TaskStart(Worker: TObject; PortionOfParent: Double = 1.0; Abortable: Boolean = True);
    procedure TaskEnd();
    procedure Show(Pos, Total: TFilePointer; Text: string = '-'); overload;
    procedure Show(AProgress: Double; Text: string = '-'); overload;
    function CurrentTaskLevel(): Integer;
    property CurrentTask: TTask read GetCurrentTask;
    property TotalProgress: Double read FTotalProgress;
  end;

  // Parsed list of file name filter patterns
  // E.g. "*.md;*.txt|CMakeLists.txt" - all MD and TXT files except CMakeLists.txt
  TNameFilter = record
    Include: TArray<string>;
    Exclude: TArray<string>;
    class function FromString(const Text: string): TNameFilter; static;
    function Matches(const Name: string; const FullPath: string = ''): Boolean;
  end;

function Data2Hex(Data: PByteArray; Size: Integer; InsertSpaces: Boolean = False): string; overload;
function Data2Hex(const Data: TBytes; InsertSpaces: Boolean = False): string; overload;
function Hex2Data(const Text: string): TBytes;
function GetCachedEncoding(CodePage: Integer): TEncoding;
function Data2String(const Data: TBytes; CodePage: Integer = 0; AnsiIfFail: Boolean = False): string;
function String2Data(const Text: string; CodePage: Integer = 0): TBytes; overload;

function MakeValidFileName(const S: string): string;
function CanonicalizePath(const Path: string): string;
function PathIsInside(const InnerPath, OuterPath: string): Boolean;
function SplitPathList(const Text: string): TArray<string>;
function FindFile(const FileMask: string; const Paths: array of string): string;
function GetFileRec(const FileName:string; FullName:boolean=true): TSearchRec;
function GetFileSizeNoOpen(FileName:string):Int64;
function RemUnprintable(const s:UnicodeString; NewChar: WideChar='.'):UnicodeString;
function DivRoundUp(A, B: Int64): Int64; inline;
function NextAlignBoundary(Size, Align: TFilePointer): TFilePointer; overload;
function NextAlignBoundary(BufStart, BufPos, Align: TFilePointer): TFilePointer; overload;
function BoundValue(X, MinX, MaxX: TFilePointer): TFilePointer;
function AdjustPositionInData(var Pos: TFilePointer; Addr, OldSize, NewSize: TFilePointer): Boolean; overload;
function AdjustPositionInData(var Range: TFileRange; Addr, OldSize, NewSize: TFilePointer): Boolean; overload;
function DataEqual(const Data1, Data2: TBytes): Boolean;
function MakeBytes(const Buf; BufSize:integer):tBytes; overload;
function MakeZeroBytes(Size: NativeInt): TBytes;
procedure SwapValues(var Value1, Value2: Integer); inline;
procedure InvertByteOrder(var Buf; BufSize:Integer);
function VariantRange(const AStart, AEnd: Variant): TVariantRange; overload;
function VariantRange(const AValue: Variant): TVariantRange; overload;
function StrToVariantRanges(const S: string): TVariantRanges;
procedure StrToClipboardInplace(var S: string);
procedure StrFromClipboardInplace(var S: string);
function StrToClipboard(const S: string): string;
function StrFromClipboard(const S: string): string;
procedure GetUsedEncodings({out} List: TStrings; OnlySingleByte: Boolean = False);

function TryEvalConst(Expr: string; var Value: Variant): Boolean;
function EvalConstDef(Expr: string): Variant;
function EvalConst(Expr: string): Variant;
function StrToInt64Relative(S: string; OldValue: TFilePointer): TFilePointer;
function TryS2R(s:UnicodeString; var Value:Double):Boolean;
function S2R(s:UnicodeString): Double;
function S2RDef(s:UnicodeString; const Default: Double = 0): Double;
function R2S(X: Double; Digits:integer = 10): string;
function R2Sf(X: Double; Digits:integer): string;
function FileSize2Str(s:Int64; FracDigits:integer=1):UnicodeString;
function Str2FileSize(const s:UnicodeString):Int64;

function GetNanosec():Int64;
function GetAppBuildTime(Instance:THandle = 0):TDateTime;
procedure WriteLog(const LogSrc, Text: string); overload;
procedure WriteLog(const Text: string); overload;
procedure WriteLogFmt(const LogSrc, AFormat: string; const Args: array of const); overload;
procedure WriteLogFmt(const AFormat: string; const Args: array of const); overload;
procedure StartTimeMeasure();
function EndTimeMeasure(const LogStr:string; bWriteLog:boolean=false; LogSrc:string=''):string; overload;

const
  EntireFile: TFileRange = (Start: 0; AEnd: -1);
  NoRange: TFileRange = (Start: -1; AEnd: -1);

var
  bDebugMode: Boolean = False;
  Progress: TProgressTracker = nil;   // Grobal progress tracker instance for all operations
  UsedEncodings: TArray<Integer>;     // Encodings shown in Search dialog etc.
  bRunningUnderWine: Boolean = False; // True if we are now running in Linux under Wine

implementation

function Data2Hex(Data: PByteArray; Size: Integer; InsertSpaces: Boolean = False): string; overload;
const
  Convert: array[0..15] of Char = '0123456789ABCDEF';
var
  i: Integer;
  P: PChar;
begin
  if InsertSpaces then
    SetLength(Result, Size * 3)
  else
    SetLength(Result, Size * 2);
  P := @Result[Low(Result)];

  for i:=0 to Size-1 do
  begin
    P^ := Convert[Data[i] shr 4];
    Inc(P);
    P^ := Convert[Data[i] and $F];
    Inc(P);
    if InsertSpaces then
    begin
      P^ := ' ';
      Inc(P);
    end;
  end;
end;

function Data2Hex(const Data: TBytes; InsertSpaces: Boolean = False): string; overload;
begin
  Result := Data2Hex(@Data[0], Length(Data), InsertSpaces);
end;

const
  H2BValidSet = ['0'..'9','A'..'F','a'..'f'];
  H2BConvert: array['0'..'f'] of SmallInt =
    ( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1,
     -1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
     -1,10,11,12,13,14,15);

function Hex2Data(const Text: string): TBytes;
var
  i, j, k: Integer;
begin
  j:=-1; k := -1;
  SetLength(Result, Length(Text) div 2);
  for i:=Low(Text) to High(Text) do
  begin
    if not CharInSet(Text[i], H2BValidSet) then Continue;  // Skip invalid chars
    Inc(j);  // Index among valid source chars
    k := j div 2;  // Index of result byte
    if k >= Length(Result) then Break;  // Odd char count
    if (j mod 2) = 0 then
      Result[k] := H2BConvert[Text[i]] shl 4
    else
      Result[k] := Result[k] + H2BConvert[Text[i]];
  end;
  if k+1 < Length(Result) then
    SetLength(Result, k+1);
end;

threadvar
  EncodingsCache: TObjectDictionary<Integer, TEncoding>;
  // TODO: Prevent reported "Memory leak" for threads other then main

function GetCachedEncoding(CodePage: Integer): TEncoding;
// Returns TEncoding object with specified CodePage.
// Creates only one instance for every CodePage value
begin
  if EncodingsCache = nil then
    EncodingsCache := TObjectDictionary<Integer, TEncoding>.Create([doOwnsValues]);
  if EncodingsCache.TryGetValue(CodePage, Result) then Exit;
  try
    Result := TEncoding.GetEncoding(CodePage);
  except
    Exit(nil);
  end;
  EncodingsCache.AddOrSetValue(CodePage, Result);
end;

function Data2String(const Data: TBytes; CodePage: Integer = 0; AnsiIfFail: Boolean = False): string;
// Convert data in specified encoding to WideString
begin
  try
    Result := GetCachedEncoding(CodePage).GetString(Data);
  except
    if AnsiIfFail then
      Result := GetCachedEncoding(TEncoding.Default.CodePage).GetString(Data)
    else
      raise;
  end;
end;

function String2Data(const Text: string; CodePage: Integer = 0): TBytes; overload;
begin
  Result := GetCachedEncoding(CodePage).GetBytes(Text);
end;

function ReplaceAllChars(const Text:string; const OldChars:string; NewChar:Char): string; overload;
// Replace all chars in Text from OldChars with NewChar
var
  i:integer;
begin
  Result := Text;
  for i := Low(Result) to High(Result) do
    if OldChars.IndexOf(Result[i]) >= 0 then Result[i]:=NewChar;
end;

function MakeValidFileName(const S: string): string;
begin
  Result := ReplaceAllChars(S, CharsInvalidInFileName, '_');
end;

function CanonicalizePath(const Path: string): string;
// Simplifies a path by removing navigation elements
// such as "." and ".." to produce a direct, well-formed path
var
  S: string;
begin
  SetLength(S, MAX_PATH);
  PathCanonicalize(PChar(S), PChar(Path));
  Result := PChar(S);
end;

function PathIsInside(const InnerPath, OuterPath: string): Boolean;
// Check if InnerPath describes a file/directory inside OuterPath
// (does not checks file/dir existance)
var
  Inner, Outer: string;
begin
  Inner := IncludeTrailingPathDelimiter(CanonicalizePath(InnerPath));
  Outer := IncludeTrailingPathDelimiter(CanonicalizePath(OuterPath));
  Result := SameFileName(Outer, Copy(Inner, Low(Inner), Length(Outer)));
end;

function SplitPathList(const Text: string): TArray<string>;
// Split ';'-separated and '"'-quoted list of paths to string array
var
  sl: TStringList;
  i, j: Integer;
begin
  sl := TStringList.Create();
  try
    sl.Delimiter := PathSep;
    sl.StrictDelimiter := True;
    sl.QuoteChar := '"';
    sl.DelimitedText := Text;
    Result := sl.ToStringArray();
    // Trim spaces
    for i:=Length(Result)-1 downto 0 do
    begin
      Result[i] := Trim(Result[i]);
      if Result[i] = '' then
        Delete(Result, i, 1);
    end;
    // Remove duplicates
    for i:=Length(Result)-1 downto 1 do
    begin
      for j:=i-1 downto 0 do
        if SameFileName(Result[j], Result[i]) then
        begin
          Delete(Result, i, 1);
          Break;
        end;
    end;
  finally
    sl.Free;
  end;
end;

function FindFile(const FileMask: string; const Paths: array of string): string;
// Search Paths for a file that matches FileMask (recursive)
var
  i: Integer;
  Files: TStringDynArray;
begin
  for i:=0 to Length(Paths)-1 do
  begin
    Files := TDirectory.GetFiles(Paths[i], FileMask, TSearchOption.soAllDirectories);
    if Length(Files) > 0 then
      Exit(Files[0]);
  end;
  Result := '';
end;

function GetFileRec(const FileName:string; FullName:boolean=true):TSearchRec;
// Returns TSearchRec for specified file
var
  r:integer;
begin
  ZeroMemory(@Result, SizeOf(Result));
  r:=FindFirst(FileName,faAnyFile,Result);
  SysUtils.FindClose(Result);
  if r<>0 then Result.Name:=''
  else
    if FullName then Result.Name:=ExtractFilePath(FileName)+Result.Name;
end;

function GetFileSizeNoOpen(FileName:string):Int64;
// Returns file size, without opening file handle
begin
  Result:=GetFileRec(FileName).Size;
end;

function RemUnprintable(const s: string; NewChar: Char='.'): string;
// Replace unprintable characters with dots
var
  i: integer;
begin
  Result := s;
  for i:=Low(Result) to High(Result) do
    if Result[i] < ' ' then Result[i] := NewChar;
end;

function DivRoundUp(A, B: Int64): Int64; inline;
begin
  Result := (A-1) div B + 1;
end;

function NextAlignBoundary(Size, Align: TFilePointer): TFilePointer; overload;
// Aligns Size upwards to Align block size
begin
  if Align = 0 then
    Result := Size
  else
    Result := ((Size - 1) div Align + 1) * Align;
end;

function NextAlignBoundary(BufStart, BufPos, Align: TFilePointer): TFilePointer; overload;
// Given buffer start address, current position and alignment block size,
// returns next alignment boundary after current position (may be equal to current position)
begin
  if Align = 0 then
    Result := BufPos
  else
    Result := BufStart + ((BufPos - BufStart - 1) div Align + 1) * Align;
end;

function BoundValue(X, MinX, MaxX: TFilePointer): TFilePointer;
// Bound X by range [MinX,MaxX]
begin
  Result:=X;
  if MaxX > MinX then
  begin
    if Result < MinX then Result := MinX;
    if Result > MaxX then Result := MaxX;
  end
  else
  begin
    if Result < MaxX then Result := MaxX;
    if Result > MinX then Result := MinX;
  end;
end;

function AdjustPositionInData(var Pos: TFilePointer; Addr, OldSize, NewSize: TFilePointer): Boolean; overload;
// Adjust position Pos according to operation that changed block of data at position Addr
// from size OldSize to NewSize.
var
  OpSize: TFilePointer;
begin
  if NewSize = OldSize then Exit(False);
  if Pos < Addr then Exit(False);
  OpSize := NewSize - OldSize;
  Pos := Max(Pos + OpSize, Addr);  // Works for both deletion and insertion
  Result := True;
end;

function AdjustPositionInData(var Range: TFileRange; Addr, OldSize, NewSize: TFilePointer): Boolean; overload;
// Adjust start and end of Range according to operation that changed block of data at position Addr
// from size OldSize to NewSize.
begin
  if NewSize = OldSize then Exit(False);
  Result := AdjustPositionInData(Range.Start, Addr, OldSize, NewSize);
  Result := AdjustPositionInData(Range.AEnd, Addr, OldSize, NewSize) or Result;
end;

function DataEqual(const Data1, Data2: TBytes): Boolean;
begin
  Result := (Length(Data1) = Length(Data2)) and
            (CompareMem(@Data1[0], @Data2[0], Length(Data1)));
end;

function MakeBytes(const Buf; BufSize:integer):tBytes; overload;
// Create TBytes from given buffer
begin
  SetLength(Result,BufSize);
  Move(Buf,Result[0],BufSize);
end;

function MakeZeroBytes(Size: NativeInt): TBytes;
begin
  SetLength(Result, Size);
  FillChar(Result[0], Size, 0);
end;

procedure SwapValues(var Value1, Value2: Integer); inline;
var
  Tmp: Integer;
begin
  Tmp := Value1;
  Value1 := Value2;
  Value2 := Tmp;
end;

procedure InvertByteOrder(var Buf; BufSize:Integer);
// Invert order of bytes in buffer
var
  i:Integer;
  b:Byte;
begin
  for i:=0 to (BufSize div 2)-1 do
  begin
    b:=PByteArray(@Buf)^[i];
    PByteArray(@Buf)^[i]:=PByteArray(@Buf)^[BufSize-i-1];
    PByteArray(@Buf)^[BufSize-i-1]:=b;
  end;
end;

function VariantRange(const AStart, AEnd: Variant): TVariantRange; overload;
begin
  Result.AStart := AStart;
  Result.AEnd := AEnd;
end;

function VariantRange(const AValue: Variant): TVariantRange; overload;
begin
  Result.AStart := AValue;
  Result.AEnd := AValue;
end;

function StrToVariantRanges(const S: string): TVariantRanges;
// Parse string like '1, 3, 5..10' to array of variant ranges
var
  a: TArray<string>;
  a1, a2: string;
  i, p: Integer;
  Range: TVariantRange;
begin
  a := S.Split([',']);
  Result.Ranges := nil;
  for i:=0 to Length(a)-1 do
  begin
    p := a[i].IndexOf('..');
    if p >= 0 then
    begin
      a1 := Copy(a[i], Low(a[i]), p);
      a2 := Copy(a[i], Low(a[i]) + p + 2, MaxInt);
      Range.AStart := EvalConst(a1);
      Range.AEnd := EvalConst(a2);
    end
    else
    begin
      Range.AStart := EvalConst(a[i]);
      Range.AEnd := Range.AStart;
    end;
    Result.Ranges := Result.Ranges + [Range];
  end;
end;

procedure StrToClipboardInplace(var S: string);
// Replace #0 with #$FFFD that can be safely stored to clipboard
var
  i: Integer;
begin
  for i := Low(S) to High(S) do
    if S[i] = #0 then
      S[i] := NullCharClipboardReplace;
end;

procedure StrFromClipboardInplace(var S: string);
// Replace #$FFFD back to #0
var
  i: Integer;
begin
  for i := Low(S) to High(S) do
    if S[i] = NullCharClipboardReplace then
      S[i] := #0;
end;

function StrToClipboard(const S: string): string;
// Replace #0 with #$FFFD that can be safely stored to clipboard
begin
  Result := S;
  StrToClipboardInplace(Result);
end;

function StrFromClipboard(const S: string): string;
// Replace #$FFFD back to #0
begin
  Result := S;
  StrFromClipboardInplace(Result);
end;

procedure GetUsedEncodings({out} List: TStrings; OnlySingleByte: Boolean = False);
var
  i: Integer;
  Enc: TEncoding;
begin
  if not Assigned(UsedEncodings) then Exit;
  List.Clear();
  for i := 0 to Length(UsedEncodings) - 1 do
  begin
    Enc := GetCachedEncoding(UsedEncodings[i]);
    if Enc = nil then Continue;
    if (OnlySingleByte) and (not Enc.IsSingleByte) then Continue;
    List.AddObject(Enc.EncodingName, Pointer(Enc.CodePage));
  end;
end;

function TryEvalConst(Expr: string; var Value: Variant): Boolean;
// Evaluate simple constant expression that does not requires Script Engine
var
  N: Integer;
  N64: Int64;
  F: Double;
begin
  Expr := Trim(Expr);

  // Integer number
  if TryStrToInt(Expr, N) then
  begin
    Value := N;
    Exit(True);
  end;

  // 64-bit Integer number
  if TryStrToInt64(Expr, N64) then
  begin
    Value := N64;
    Exit(True);
  end;

  // Floating-point number
  if TryS2R(Expr, F) then
  begin
    Value := F;
    Exit(True);
  end;

  // Character
  if (Length(Expr) = 3) and (Expr[Low(Expr)] = '''') and
     (Expr[High(Expr)] = '''') then
  begin
    Value := Char(Expr[Low(Expr)+1]);
    Exit(True);
  end;

  // String
  if (Length(Expr) >= 2) and (Expr[Low(Expr)] = '"') and
     (Expr[High(Expr)] = '"') then
  begin
    Value := Copy(Expr, Low(Expr) + 1, Length(Expr) - 2);
    Exit(True);
  end;

  Result := False;
end;

function EvalConstDef(Expr: string): Variant;
// Evaluate simple constant expression that does not requires Script Engine
begin
  if not TryEvalConst(Expr, Result) then
    VarClear(Result);
end;

function EvalConst(Expr: string): Variant;
// Evaluate simple constant expression that does not requires Script Engine
begin
  if not TryEvalConst(Expr, Result) then
    raise EConvertError.CreateFmt('"%s" is not a valid value', [Expr]);
end;

function StrToInt64Relative(S: string; OldValue: TFilePointer): TFilePointer;
// if S includes '-' or '+', it is treated as relative to OldValue
begin
  S := Trim(S);
  Result := StrToInt64(S);
  if CharInSet(S[Low(S)], ['-','+']) then
    Result := OldValue + Result;
end;

function TryS2R(s:UnicodeString; var Value:Double):Boolean;
// Convert string to floating-point number
// Treats both '.' and ',' as decimal separator
var
  i:integer;
begin
  s:=Trim(UpperCase(s));
  if s='NAN' then
  begin
    Value:=NaN;
    Exit(True);
  end;
  if s='INF' then
  begin
    Value:=Infinity;
    Exit(True);
  end;
  if s='-INF' then
  begin
    Value:=NegInfinity;
    Exit(True);
  end;

  for i:=Low(S) to High(s) do
    if s[i]=',' then s[i]:='.';
  Val(s,Value,i);
  Result:=(i=0);
end;

function S2R(s:UnicodeString): Double;
// Convert string to floating-point number
// Treats both '.' and ',' as decimal separator
begin
  if not TryS2R(s, Result) then
    raise EConvertError.CreateResFmt(@SInvalidFloat, [s]);
end;

function S2RDef(s:UnicodeString; const Default: Double = 0): Double;
// Convert string to floating-point number
// Treats both '.' and ',' as decimal separator
begin
  if not TryS2R(s, Result) then
    Result := Default;
end;

function R2S(X: Double; Digits:integer = 10): string;
// Convert number to string with no more than "Digits" digits after dot
var
  i, j, LowStr: Integer;
  S: ShortString;
begin
  if Digits < 0 then
  begin
    X := RoundTo(X, -Digits);
    Digits := 0;
  end;
  Str(x:1:Digits, S);
  Result := string(S);
  LowStr:=Low(Result);
  i:=Pos('.', Result);
  if i>=LowStr then  // Trim unsignificant zero's at right
  begin
    j:=High(Result);
    while (j>=LowStr) and (Result[j]='0') do Dec(j);
    if (j>=LowStr) and (Result[j]='.') then Dec(j);
    if j<>High(Result) then SetLength(Result, j+(1-LowStr));
  end;
//  if (i>=Low(Result)) and (i<=High(Result)) and (R2SSystemSep) then
//    Result[i]:=FormatSettings.DecimalSeparator;
end;

function R2Sf(X: Double; Digits:integer): string;
// Convert number to string with exactly "Digits" digits after dot
var
  S: ShortString;
begin
  Str(x:1:Digits, S);
  Result := string(S);
end;

function FileSize2Str(s: TFilePointer; FracDigits:integer=1): string;
// String representation of data size "10 B", "1.2 KB", "23.45 MB"
begin
  if s<KByte then
    Result:=IntToStr(s)+' B'
  else if s<MByte then
    Result:=R2S(s/KByte, FracDigits)+' KB'
  else if s<GByte then
    Result:=R2S(s/(MByte), FracDigits)+' MB'
  else if s<TerraByte then
    Result:=R2S(s/GByte, FracDigits)+' GB'
  else if s<PetaByte then
    Result:=R2S(s/TerraByte, FracDigits)+' TB'
  else if s<ExaByte then
    Result:=R2S(s/PetaByte, FracDigits)+' PB'
  else
    Result:=R2S(s/ExaByte, FracDigits)+' EB';
end;

function Str2FileSize(const s: string): TFilePointer;
// Convert a string like "10.5 MB", " 12 kbytes" etc. to number of bytes
var
  i, L: integer;
  Mult: Int64;
  s1: UnicodeString;
begin
  Mult := 1; L := Length(s) + 1;
  for i:=1 to Length(s) do
  begin
    if not CharInSet(s[i],['0'..'9','.',',',' ',#9]) then
    begin
      if CharInSet(s[i],['b','B','�','�']) then Mult:=1
      else
      if CharInSet(s[i],['k','K','�','�']) then Mult:=KByte
      else
      if CharInSet(s[i],['m','M','�','�']) then Mult:=MByte
      else
      if CharInSet(s[i],['g','G','�','�']) then Mult:=GByte
      else
      if CharInSet(s[i],['t','T','�','�']) then Mult:=TerraByte
      else
      if CharInSet(s[i],['p','P','�','�']) then Mult:=PetaByte
      else
      if CharInSet(s[i],['e','E','�','�']) then Mult:=ExaByte
      else raise EConvertError.CreateFmt('"%s" is not a valid size', [s]);
      L:=i;
      break;
    end;
  end;
  s1:=Trim(Copy(s,1,L-1));
  Result:=Round(S2R(s1)*Mult);
end;

var
  PerfFreq: Int64 = 0;  // Result of QueryPerformanceFrequency()

function GetNanosec():Int64;
// Current time in nanoseconds
{$IFDEF MSWINDOWS}
begin
  if PerfFreq=0 then QueryPerformanceFrequency(PerfFreq);
  QueryPerformanceCounter(Result);
  Result:=Round(Result/PerfFreq*1000000000);
end;
{$ENDIF}
{$IFDEF LINUX}
var
  ts:TTimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC,@ts);
  Result:=Int64(ts.tv_sec)*1000000000+Int64(ts.tv_nsec);
end;
{$ENDIF}

function GetAppBuildTime(Instance:THandle = 0):TDateTime;
// Returns application build time from PE file header
var
  Offset: Cardinal;
  FD: LongRec;
  Date, Time: TDateTime;
begin
  Result:=0;
  if Instance=0 then Instance:=HInstance;
  Offset:=PImageNtHeaders(Instance+DWORD(PImageDosHeader(Instance)._lfanew))
           .OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_RESOURCE].VirtualAddress;
  if Offset<>0 then begin
    Integer(FD):=PInteger(Offset+Instance+4)^;
    if TryEncodeDate(FD.Hi shr 9+1980,FD.Hi shr 5 and 15,FD.Hi and 31,Date)
      and TryEncodeTime(FD.Lo shr 11,FD.Lo shr 5 and 63,FD.Lo and 31 shl 1,0,Time) then
      Result:=Date+Time;
  end;
end;

procedure WriteLog(const LogSrc, Text: string); overload;
var
  fn, ws: string;
  S: AnsiString;
  Now_: TDateTime;
  fs: TFileStream;
begin
  if not bDebugMode then Exit;
  Now_ := Now();

  DateTimeToString(fn, 'yymmdd', Now_);
  fn := ExtractFilePath(ParamStr(0)) + 'Log\' + fn + '\' + LogSrc + '.log';

  DateTimeToString(ws, 'hh:nn:ss.zzz', Now_);
  S := AnsiString(ws) + ' | ' + AnsiString(Text) + sLineBreak;

  ForceDirectories(ExtractFilePath(fn));
  if FileExists(fn) then
    fs := TFileStream.Create(fn, fmOpenReadWrite or fmShareDenyWrite)
  else
    fs := TFileStream.Create(fn, fmCreate);
  try
    fs.Seek(0, soEnd);
    fs.WriteBuffer(S[Low(S)], Length(S) * SizeOf(S[Low(S)]));
  finally
    fs.Free;
  end;
end;

procedure WriteLog(const Text: string); overload;
begin
  WriteLog('Log', Text);
end;

procedure WriteLogFmt(const LogSrc, AFormat: string; const Args: array of const); overload;
begin
  WriteLog(LogSrc, Format(AFormat, Args));
end;

procedure WriteLogFmt(const AFormat: string; const Args: array of const); overload;
begin
  WriteLog(Format(AFormat, Args));
end;

ThreadVar
  TimeSt: array [0..100] of Int64;
  TimeStCnt: Integer;

procedure StartTimeMeasure();
begin
  if TimeStCnt>100 then Exit;
  TimeSt[TimeStCnt]:=GetNanosec();
  inc(TimeStCnt);
end;

function EndTimeMeasure(const LogStr:string; bWriteLog:boolean=false; LogSrc:string=''):string; overload;
var
  t:Int64;
begin
  if TimeStCnt=0 then Exit;
  dec(TimeStCnt);
  t:=GetNanosec()-TimeSt[TimeStCnt];
  Result := R2Sf(t / 1000000, 3) + ' ms'; //NanoSec2Str(t);
  Result := StringOfChar(' ', TimeStCnt) + LogStr + ' ' + Result;
  if LogSrc = '' then LogSrc := 'Timing';
  WriteLog(LogSrc, Result);
end;

{ TFileRange }

class operator TFileRange.Add(const A, B: TFileRange): TFileRange;
begin
  if (A = NoRange) then Exit(B);
  if (B = NoRange) then Exit(A);
  if (A = EntireFile) or (B = EntireFile) then Exit(EntireFile);
  Result.Start := Min(A.Start, B.Start);
  Result.AEnd := Max(A.AEnd, B.AEnd);
end;

constructor TFileRange.Create(BStart, BEnd: TFilePointer);
begin
  Start := BStart;
  AEnd := BEnd;
end;

class operator TFileRange.Equal(const A, B: TFileRange): Boolean;
begin
  Result := (A.Start = B.Start) and (A.AEnd = B.AEnd);
end;

function TFileRange.GetSize: TFilePointer;
begin
  Result := AEnd-Start;
end;

function TFileRange.Intersects(Value: TFilePointer): Boolean;
begin
  Result := (Value >= Start) and (Value < AEnd);
end;

function TFileRange.Intersects2(const BRange: TFileRange): Boolean;
// Also accept zero-length regions on the ends of this range
begin
  Result := Intersects2(BRange.Start, BRange.AEnd);
end;

function TFileRange.Intersects2(BStart, BEnd: TFilePointer): Boolean;
// Also accept zero-length regions on the ends of this range
begin
  Result := ((BEnd > Start) and (BStart < AEnd)) or
            ((BStart = BEnd) and ((BStart = Start) or (BStart = AEnd)));
end;

function TFileRange.Intersects(BStart, BEnd: TFilePointer): Boolean;
begin
  Result := (BEnd > Start) and (BStart < AEnd);
end;

class operator TFileRange.NotEqual(const A, B: TFileRange): Boolean;
begin
  Result := (A.Start <> B.Start) or (A.AEnd <> B.AEnd);
end;

function TFileRange.Intersects(const BRange: TFileRange): Boolean;
begin
  Result := (BRange.AEnd > Start) and (BRange.Start < AEnd);
end;

procedure TFileRange.SetSize(Value: TFilePointer);
begin
  AEnd := Start + Value;
end;

{ TVariantRange }

constructor TVariantRange.Create(AStart, AEnd: Variant);
begin
  Self.AStart := AStart;
  Self.AEnd := AEnd;
end;

{ TVariantRanges }

function TypesCompatible(const v1, v2: Variant): Boolean;
begin
  Result := (VarIsNumeric(v1) and VarIsNumeric(v2)) or
            (VarIsStr(v1) and VarIsStr(v2));
end;

function VarLessOrEqual(const Value1, Value2: Variant; VarType: TVarType): Boolean;
begin
  // Compare using appropriate accuracy
  case VarType of
    varSingle:
      begin
        if IsNaN(Single(Value1)) or IsNaN(Single(Value2)) then Exit(False);
        Result := (CompareValue(Single(Value1), Single(Value2)) <= 0);
      end;
    varDouble:
      begin
        if IsNaN(Double(Value1)) or IsNaN(Double(Value2)) then Exit(False);
        Result := (CompareValue(Double(Value1), Double(Value2)) <= 0);
      end
    else
      Result := (Value1 <= Value2);
  end;
end;

function TVariantRanges.Contains(const Value: Variant): Boolean;
var
  i: Integer;
  VarType: TVarType;
begin
  VarType := FindVarData(Value)^.VType;
  for i:=0 to Length(Ranges)-1 do
    if (TypesCompatible(Value, Ranges[i].AStart)) and
       (TypesCompatible(Value, Ranges[i].AEnd)) and
       (VarLessOrEqual(Ranges[i].AStart, Value, VarType)) and (VarLessOrEqual(Value, Ranges[i].AEnd, VarType)) then
      Exit(True);
  Result := False;
end;

function TVariantRanges.IsEmpty: Boolean;
begin
  Result := (Ranges = nil);
end;

{ tJsonRtti }

class function tJsonRtti.ObjectToStr<T>(const obj: T; const ANotWriteEmptyField: boolean = false): string;
var
  ctx: TSuperRttiContext;
begin
  ctx := TSuperRttiContext.Create;
  ctx.NotWriteEmptyField := ANotWriteEmptyField;
  Result := ctx.AsJson<T>(obj).AsJson(true, False);
  ctx.Free;
end;

class function tJsonRtti.StrToObject<T>(const S: string): T;
var
  ctx: TSuperRttiContext;
begin
  ctx := TSuperRttiContext.Create;
  Result := ctx.AsType<T>(SO(S));
  ctx.Free;
end;

{ TTaggedDataRegion }

function TTaggedDataRegion.Accepted: Boolean;
// Dirty hack to be able to write like this:
//
// with Regions.Add(...) do
// if Accepted() then
// begin
//   OnClick := TagClick;
// end;
begin
  Result := Assigned(Self);
end;

constructor TTaggedDataRegion.Create(AOwner: TObject; ARange: TFileRange; ATextColor, ABgColor,
  AFrameColor: TColor);
begin
  inherited Create();
  Owner := AOwner;
  Range := ARange;
  TextColor := ATextColor;
  BgColor := ABgColor;
  FrameColor := AFrameColor;
end;

{ TTaggedDataRegionList }

function TTaggedDataRegionList.AddRegion(Owner: TObject; RangeStart, RangeEnd: TFilePointer;
  TextColor, BgColor, FrameColor: TColor; Data: Pointer = nil; CanAppend: Boolean = false): TTaggedDataRegion;
// Add region to list if it intersects current accepted range.
// CanAppend: region can be appended to last region with identical properties
begin
  if (AcceptRange = EntireFile) or (AcceptRange.Intersects2(RangeStart, RangeEnd)) then
  begin
    if (CanAppend) and (Count > 0) then
    begin
      Result := Last();
      if (Owner = Result.Owner) and (RangeStart = Result.Range.AEnd) and
         (TextColor = Result.TextColor) and (BgColor = Result.BgColor) and (FrameColor = Result.FrameColor) and
         (Data = Result.Data) then
      begin
        Result.Range.AEnd := RangeEnd;
        Exit;
      end;
    end;
    Result := TTaggedDataRegion.Create(Owner, TFileRange.Create(RangeStart, RangeEnd), TextColor, BgColor, FrameColor);
    Result.Data := Data;
    Add(Result);
  end
  else
    Result := nil;
end;

constructor TTaggedDataRegionList.Create(const AAcceptRange: TFileRange);
begin
  inherited Create(True);
  AcceptRange := AAcceptRange;
end;

constructor TTaggedDataRegionList.Create;
begin
  Create(EntireFile);
end;

{ TProgressTracker }

constructor TProgressTracker.Create;
begin
  inherited;
  TaskStack := TObjectStack<TTask>.Create();
  FDisplayInterval := 100;
end;

function TProgressTracker.GetCurrentTask: TTask;
begin
  if TaskStack.Count = 0 then
    Result := nil
  else
    Result := TaskStack.Peek;
end;

function TProgressTracker.CurrentTaskLevel: Integer;
begin
  Result := TaskStack.Count;
end;

destructor TProgressTracker.Destroy;
begin
  TaskStack.Free;
  inherited;
end;

procedure TProgressTracker.Show(AProgress: Double; Text: string);
// Task calls this to report it's own progress.
// '-' => do not change text.
// Must be surrounded by TaskStart() / TaskEnd()
var
  ATotalProgress: Double;
  CurTask: TTask;
begin
  CurTask := CurrentTask;
  if CurTask = nil then Exit;

  if Text <> '-' then
    FLastText := Text;

  with CurTask do
  begin
    Progress := AProgress;
    if Progress >= 0 then
      ATotalProgress := TotalWorkFrom + (TotalWorkTo - TotalWorkFrom) * Progress
    else
      ATotalProgress := Progress;
  end;
  FTotalProgress := ATotalProgress;

  // Pass to GUI once in 100 ms.
  // If overall task takes less then 100 ms, progress window will not be displayed
  if LastDisplay = 0 then LastDisplay := GetTickCount();
  if (GetTickCount() - LastDisplay > DisplayInterval) then
  begin
    LastDisplay := GetTickCount();

    OnDisplay.Call(Self, FTotalProgress, FLastText);
  end;
end;

procedure TProgressTracker.Show(Pos, Total: TFilePointer; Text: string = '-');
var
  AProgress: Double;
begin
  if Total > 0 then
    AProgress := Pos/Total
  else
    AProgress := 0;
  Show(AProgress, Text);
end;

procedure TProgressTracker.TaskEnd;
var
  Task: TTask;
begin
  if CurrentTaskLevel = 0 then
  begin
    Assert(False, 'Unbalanced Progress.TaskStart/TaskEnd');
    Exit;
  end;
  Show(1.0);
  Task := TaskStack.Peek();
  OnTaskEnd.Call(Self, Task);
  if CurrentTaskLevel = 1 then
    WriteLogFmt('Progress', 'TaskEnd: %s (%d ms)', [Task.Worker.ClassName, GetTickCount() - Task.StartTime]);
  TaskStack.Pop();
end;

procedure TProgressTracker.TaskStart(Worker: TObject; PortionOfParent: Double = 1.0; Abortable: Boolean = True);
var
  Task, ParentTask: TTask;
begin
  if (PortionOfParent <> 1.0) and (CurrentTask = nil) then
    raise Exception.Create('Top-level task thould have a portion equal to 1.0');
  if CurrentTask = nil then
    WriteLogFmt('Progress', 'TaskStart: %s', [Worker.ClassName]);
  Task := TTask.Create();
  Task.Worker := Worker;
  Task.Portion := PortionOfParent;
  Task.Abortable := Abortable;
  Task.StartTime := GetTickCount();
  ParentTask := CurrentTask;
  if ParentTask = nil then
  begin
    Task.TotalWorkFrom := 0.0;
    Task.TotalWorkTo := 1.0;
    LastDisplay := 0;
    FLastText := '';
  end
  else
  begin
    Task.TotalWorkFrom := TotalProgress;
    Task.TotalWorkTo := Task.TotalWorkFrom + (ParentTask.TotalWorkTo - ParentTask.TotalWorkFrom) * PortionOfParent;
    Task.Abortable := Task.Abortable and ParentTask.Abortable;
  end;
  TaskStack.Push(Task);
  OnTaskStart.Call(Self, Task);
  Show(0.0);
end;

{ TNameFilter }

class function TNameFilter.FromString(const Text: string): TNameFilter;
var
  i: Integer;
begin
  i := Pos('|', Text);
  if i > 0 then
  begin
    Result.Include := SplitPathList(Copy(Text, 1, i - 1));
    Result.Exclude := SplitPathList(Copy(Text, i + 1, MaxInt));
  end
  else
  begin
    Result.Include := SplitPathList(Text);
    Result.Exclude := nil;
  end;
end;

function TNameFilter.Matches(const Name: string; const FullPath: string = ''): Boolean;
// Returns True if given name matches one of Include masks and does not matches
// any of Exclude masks.
// If some mask contains a path delimiter char, then this mask is matched against
// FullPath (if specified).

  function MatchesMask2(const AMask: string): Boolean;
  begin
    if (FullPath <> '') and (AMask.IndexOf(PathDelim) >= 0) then
      Result := MatchesMask(FullPath, AMask)
    else
      Result := MatchesMask(Name, AMask);
  end;

var
  s: string;
begin
  if Exclude <> nil then
  begin
    for s in Exclude do
      if MatchesMask2(s) then Exit(False);
  end;
  if Include = nil then Exit(True);
  for s in Include do
    if MatchesMask2(s) then Exit(True);
  Result := False;
end;

procedure CheckForWine();
// Check if we are running under Wine
var
  hntdll: HMODULE;
begin
  hntdll := GetModuleHandle('ntdll.dll');
  if hntdll <> 0 then
  begin
    if GetProcAddress(hntdll, 'wine_get_version') <> nil then
      bRunningUnderWine := True;
  end;
end;

initialization
  Progress := TProgressTracker.Create();
  CheckForWine();
finalization
  FreeAndNil(Progress);
  FreeAndNil(EncodingsCache);
end.
