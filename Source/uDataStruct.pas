{                          ---BEGIN LICENSE BLOCK---                           }
{                                                                              }
{ Hextor - Hexadecimal editor and binary data analyzing toolkit                }
{ Copyright (C) 2019-2021  Grigoriy Mylnikov (DigitalWolF) <info@hextor.net>   }
{ Hextor is a Freeware Source-Available software. See LICENSE.txt for details  }
{                                                                              }
{                           ---END LICENSE BLOCK---                            }

unit uDataStruct;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, Generics.Collections,
  System.Math, Winapi.ActiveX, Variants, ComObj,
  Generics.Defaults,

  uHextorTypes, uValueInterpretors, {uLogFile,} uCallbackList, uActiveScript,
  uOleAutoAPIWrapper;

const
  // Synthetic "case" label for "default" branch
  DSDefaultCaseVariant: string = ':case_default:';

type
  EDSParserError = class (Exception);
  TDSSimpleDataType = string;  // e.g. 'uint16'
  TDSField = class;
  TDSCompoundField = class;
  TDSComWrapper = class;

  TDSDataGetProc = procedure (DataContext: Pointer; Addr, Size: TFilePointer; var Data: TBytes) of Object;
  TDSDataChangeProc = procedure (DataContext: Pointer; Addr, OldSize, NewSize: TFilePointer; Value: PByteArray) of Object;
  TDSChangedCallback = TCallbackListP3<{DataContext:}Pointer, {DS:}TDSField, {Changer:}TObject>;
  TDSInterpretedCallback = TCallbackListP2<{DataContext:}Pointer, {DS:}TDSField>;
  TDSDestroyCallback = TCallbackListP2<{DataContext:}Pointer, {DS:}TDSField>;
  TDSPrepareScriptEnvCallback = TCallbackListP3<{DataContext:}Pointer, {DS:}TDSField, {ScriptEngine:}TActiveScript>;

  // Callbacks which link DataStruct with underlying EditedData and GUI
  TDSEventSet = class
  public
    DataContext: Pointer;                   // TEditedData
    DataGetProc: TDSDataGetProc;            // Read data from source
    DataChangeProc: TDSDataChangeProc;      // Write data to source
    OnChanged: TDSChangedCallback;          // General-purpose callback, called after DS changed
    OnInterpreted: TDSInterpretedCallback;  // Called on every DS field interpreted from data
    OnDestroy: TDSDestroyCallback;          // Called on DS field destruction
    OnPrepareScriptEnv: TDSPrepareScriptEnvCallback;  // Called before every script expression evaluation
  end;

  // Base class for all elements
  TDSField = class
  public type
    TFieldEnumProc = reference to function(DS: TDSField): Boolean;
    TFieldEnumOrder = (eoFromRoot, eoFromLeafs);
  private
    FIndex: Integer;
    FName: string;
    FParent: TDSCompoundField;
//    function RootDS(): TDSField;
    FEventSet: TDSEventSet;
    FErrorText: string;
    function GetName: string;
    procedure SetParent(const Value: TDSCompoundField);
    function GetEventSet(): TDSEventSet;
    procedure SetErrorText(const Value: string);
  public
    BufAddr: TFilePointer;   // Address and size in original data buffer
    BufSize: TFilePointer;
    DescrLineNum: Integer;   // Line number in structure description text
    DisplayFormat: TValueDisplayNotation;
    HintTemplate: string;
    constructor Create(); virtual;
    destructor Destroy(); override;
    procedure Assign(Source: TDSField); virtual;
    property Name: string read GetName;
    property Parent: TDSCompoundField read FParent write SetParent;
    function Duplicate(): TDSField;
    function ToString(): string; reintroduce; virtual;
    function ToQuotedString(): string; virtual;
    function FullName(): string;
    property EventSet: TDSEventSet read GetEventSet write FEventSet;  // Callbacks which link DataStruct with underlying EditedData and GUI
    procedure DoChanged(Changer: TObject);
    function GetFixedSize(): TFilePointer; virtual;
    property ErrorText: string read FErrorText write SetErrorText;    // Parsing error (e.g. "End of buffer" or "Value out of range")
    function Hint(): string;
    function EnumerateFields(const Range: TFileRange; Proc: TFieldEnumProc; Order: TFieldEnumOrder = eoFromRoot): Integer;
    function EnumerateTypeFields(Proc: TFieldEnumProc; Order: TFieldEnumOrder = eoFromRoot): Integer;
  end;
  TDSFieldClass = class of TDSField;
  TArrayOfDSField = array of TDSField;

  // Simple data types - integers, floats
  TDSSimpleField = class (TDSField)
  private
    FInterpretor: TValueInterpretor;
    FValidationStr: string;
    function GetData: TBytes;
    procedure SetData(const Value: TBytes; AChanger: TObject = nil);
    procedure SetValidationStr(const Value: string);
  public
    DataType: TDSSimpleDataType;
    BigEndian: Boolean;
    constructor Create(); override;
    procedure Assign(Source: TDSField); override;
    // Data for field is requested from underlying buffer every time it is needed,
    // using callbacks in EventSet
    property Data: TBytes read GetData;
    property ValidationStr: string read FValidationStr write SetValidationStr;
    function ToVariant(): Variant;
    function ToString(): string; override;
    function ToQuotedString(): string; override;
    procedure SetFromVariant(const V: Variant; AChanger: TObject = nil); virtual;
    function GetInterpretor(RaiseException: Boolean = True): TValueInterpretor;
    function GetFixedSize(): TFilePointer; override;
  end;

  // For arrays and structures
  TDSCompoundField = class (TDSField)
  private type
    // Enumarates named fields, recuresively stepping into unnamed fields
    TNamedFieldsEnumerator = class(TEnumerator<TDSField>)
    private
      FTopLevel: TDSCompoundField;       // Compound field in which we are enumerating
      FCurrentParent: TDSCompoundField;  // We are currently inside this field
      FIndex: Integer;                   // Index of current item in it's parent
      FIndices: TStack<Integer>;         // Indices in previous parents
    protected
      function DoGetCurrent: TDSField; override;
      function DoMoveNext: Boolean; override;
    public
      constructor Create(TopLevelField: TDSCompoundField);
      destructor Destroy(); override;
    end;
    // For auto-refcounting
    INamedFieldsEnumerable = interface(IInterface)
      function GetEnumerator: TNamedFieldsEnumerator;
    end;
    TNamedFieldsEnumerable = class(TInterfacedObject, INamedFieldsEnumerable)
    protected
      FTopLevel: TDSCompoundField;       // Compound field in which we are enumerating
    public
      constructor Create(TopLevelField: TDSCompoundField);
      function GetEnumerator: TNamedFieldsEnumerator;
    end;
  private
    FComWrapper: TDSComWrapper;
    FCurParsedItem: Integer;  // During interpretation process - which item is currently populating
    FFields: TObjectList<TDSField>;
    FHelperVars: TList<TPair<string, Variant>>;
    function GetFields(Index: Integer): TDSField; virtual;
    function GetFieldsCount: Integer; virtual;
    function FindHelperVar(const Name: string): Integer;
    procedure SetHelperVar(const Name: string; const Value: Variant);
  public
    FieldAlign: Integer;  // Alignment of fields relative to structure start
    ChildsWithErrors: Integer;  // Total count of childs (recursively) with non-empty ErrorText
    ChildsWithValidations: Integer;  // Total count of childs (recursively) with "#valid" directive
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Assign(Source: TDSField); override;
    function ToString(): string; override;
    property Fields[Index: Integer]: TDSField read GetFields {write SetFields};
    property FieldsCount: Integer read GetFieldsCount {write SetFieldsCount};
    function AddField(Field: TDSField): Integer;
    function GetComWrapper(): TDSComWrapper;
    function GetFieldAlign(): Integer;
    function NamedFields(): INamedFieldsEnumerable;
    function NamedFieldByIndex(Index: Integer): TDSField;
  end;

  TDSArray = class (TDSCompoundField)
  private
    FRealCount: Integer;  // If "deferred loading" is used, this holds real element count in file
    function GetFieldsCount: Integer; override;
    function GetFields(Index: Integer): TDSField; override;
    procedure AllocateFieldsList(ACount: Integer = -1);
  public
    ACount: string;  // Count as it is written in description. Interpreted during population of structures
    ElementType: TDSField;
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Assign(Source: TDSField); override;
    function ToString(): string; override;
    function ToQuotedString(): string; override;
    function GetFixedSize(): TFilePointer; override;
    procedure SetLength(NewLength: Integer);
  end;

  TDSStruct = class (TDSCompoundField)
  public
    constructor Create(); override;
    function GetFixedSize(): TFilePointer; override;
  end;

  TDSConditional = class (TDSCompoundField)
  // Conditional node placeholder like "if", "switch" etc.
  // Evaluates to different branches according to value of ACondition
  private type
    TBranch = record
      Keys: TVariantRanges;  // Example: case 1, 3, 5..10: {}
      Fields: TArrayOfDSField;
    end;
  public
    ACondition: string;
    Branches: TList<TBranch>;
    constructor Create(); override;
    destructor Destroy(); override;
    procedure Assign(Source: TDSField); override;
    procedure AddBranch(const AKeys: TArray<TVariantRange>; const AFields: TArrayOfDSField);
    function GetFieldsByKey(Key: Variant): TArrayOfDSField;
  end;

  TDSDirective = class (TDSField)
  // Directive that should be processed during structure population,
  // for example "addr" and "align_pos".
  // TDSDirective is not created for directives which are fully processed
  // during DS description parsing, like "bigendian"
  public
    Value: string;
    procedure Assign(Source: TDSField); override;
    function GetFixedSize(): TFilePointer; override;
  end;

  TDSHelperVariable = class (TDSDirective)
  // Helper variable that is used during structure parsing, but is not a part of that structure
  public
  end;

  TDSScriptBlock = class (TDSDirective)
  // Script executed during structure parsing
  // (e.g. function call or assignment to helper variable).
  // Script text is stored in Self.Value
  public
  end;

// I can use this class to make typedef's bound to specific visibility scope
//  TDSTypedef = class (TDSField)
//  // User type definition
//  public
//    ATypes: TObjectList<TDSField>;
//    procedure Assign(Source: TDSField); override;
//    function GetFixedSize(): TFilePointer; override;
//    constructor Create();
//    destructor Destroy(); override;
//  end;

  IDSComWrapper = interface
    ['{A3BF1107-670C-47EF-90D6-F0F7EF927A27}']
    function GetWrappedField(): TDSField;
  end;

  // DS wrapper for scripts
  TDSComWrapper = class(TInterfacedObject, IDSComWrapper, IDispatch)
  private const
    DISPID_INDEX  = -1;  // "index" pseudo-field of arrays
    DISPID_LENGTH = -2;  // "length" pseudo-field of arrays
    DISPID_HELPERVARS_FIRST = $7F000000;
  private
    DSField: TDSField;
  public
    function GetIDsOfNames(const IID: TGUID; Names: Pointer;
      NameCount: Integer; LocaleID: Integer; DispIDs: Pointer): HRESULT;
      virtual; stdcall;
    function GetTypeInfo(Index: Integer; LocaleID: Integer;
      out TypeInfo): HRESULT; stdcall;
    function GetTypeInfoCount(out Count: Integer): HRESULT; stdcall;
    function Invoke(DispID: Integer; const IID: TGUID; LocaleID: Integer;
      Flags: Word; var Params; VarResult: Pointer; ExcepInfo: Pointer;
      ArgErr: Pointer): HRESULT; virtual; stdcall;
    function GetWrappedField(): TDSField;
  end;

  // Class for parsing structure description to DS's
  TDSParser = class
  private
    BufStart, BufEnd, Ptr: PChar;
    CurStruct: TDSCompoundField;  // Innermost currently parsed structure (this is a type, not an instance)
    CurLineNum: Integer;
    CurBigEndian: Boolean;  // Currently in big-endian mode
    LastStatementFields: TArrayOfDSField;  // e.g. for #valid
    Typedefs: TObjectDictionary<string, TDSField>;  // User-defined types
    function CharValidInName(C: Char): Boolean;
    function IsReservedWord(const S: string): Boolean;
    function IsTypeName(const S: string): Boolean;
    procedure CheckValidName(const S: string);
    function ReadChar(): Char;
    procedure PutBack();
    function ReadLexem(): string;
    function PeekLexem(): string;
    function ReadExpectedLexem(const Expected: array of string): string;
    function ReadExpressionStr(StopAtChars: TSysCharSet = [';']): string;
    function ReadLine(): string;
    function ReadType(var ShouldFree: Boolean): TDSField;
    function ReadFieldsDeclaration(): TArrayOfDSField;
    function ReadStatement(): TArrayOfDSField;
    function ReadStruct(): TDSStruct;
    function ReadIfStatement(): TDSConditional;
    function ReadSwitchStatement(): TDSConditional;
    function ReadBreakStatement(): TDSDirective;
    function ReadHelperVar(): TDSHelperVariable;
    function ReadDirective(): TDSDirective;
    function ReadScriptBlock(): TDSScriptBlock;
    procedure ReadTypedef();
    function MakeArray(AType: TDSField; const ACount: string): TDSArray;
    procedure EraseComments(var Buf: string);
    procedure CheckNestingValidity(DS: TDSField);
  public
    function ParseStruct(const Descr: string): TDSStruct;
    constructor Create();
    destructor Destroy(); override;
  end;

  TOnDSInterpretorGetData = reference to procedure (Addr, Size: TFilePointer; var Data: TBytes{; var AEndOfData: Boolean});

  // Class for populating DataStructure from binary buffer
  TDSInterpretor = class
  private type
    TBreakStatementType = (bsNone, bsContinue, bsBreak);
  private
    FStartAddr, FMaxSize: TFilePointer;  // Starting address of analysed struct in original file
    FCurAddr: TFilePointer;    // Current
    EndOfData: Boolean;        // End of input data reached
    ActiveBreakStatement: TBreakStatementType;  // Indicates that we encountered "break" or "continue" and now skipping rest of current structure
    FieldsProcessed: Integer;  // To show some progress
    APIEnv: TAPIEnvironment;
    procedure Seek(Addr: TFilePointer);
    function GetFieldSize(DS: TDSSimpleField): Integer;
    procedure InterpretSimple(DS: TDSSimpleField);
    procedure InterpretStruct(DS: TDSStruct);
    procedure InterpretArray(DS: TDSArray);
    procedure InterpretConditional(DS: TDSConditional);
    procedure ProcessHelperVar(DS: TDSHelperVariable);
    procedure ProcessDirective(DS: TDSDirective);
    procedure ProcessScriptBlock(DS: TDSScriptBlock);
    procedure InternalInterpret(DS: TDSField);
    procedure ValidateField(DS: TDSSimpleField);
  public
    procedure Interpret(DS: TDSField; Addr, MaxSize: TFilePointer);
    constructor Create();
    destructor Destroy(); override;
    [API]
    property Cur_Addr: TFilePointer read FCurAddr;
//    procedure CheckParent(DS: TDSField);
    class procedure DbgDescribe(DS: TDSField; Text: TStrings; Indent: string; AParent: TDSField);
    class function DbgDescr(DS: TDSField): string;
  end;

implementation

function SameName(const Name1, Name2: string): Boolean;
begin
  Result := (Trim(Name1) = Trim(Name2));
end;

function DuplicateDSFieldArray(const AFields: TArrayOfDSField): TArrayOfDSField;
var
  i: Integer;
begin
  SetLength(Result, Length(AFields));
  for i:=0 to Length(AFields)-1 do
    Result[i] := AFields[i].Duplicate();
end;

procedure FreeDSFieldArray(const AFields: TArrayOfDSField);
var
  i: Integer;
begin
  for i:=0 to Length(AFields)-1 do
    AFields[i].Free;
end;

type
  // Expression evaluator for DS module. Use class function Eval() and EvalConst()
  TDSExprEvaluator = class
  protected
    ScriptEngine: TActiveScript;
    class procedure ForceEvaluator();
    procedure PrepareScriptEnv(CurField: TDSField; DSInterpretor: TDSInterpretor);
    function Evaluate(Expr: string; CurField: TDSField; DSInterpretor: TDSInterpretor;
      RequireResult: Boolean = True): Variant;
  public
    class function Eval(Expr: string; CurField: TDSField; DSInterpretor: TDSInterpretor;
      RequireResult: Boolean = True): Variant;
    constructor Create();
    destructor Destroy(); override;
  end;

var
  FDSExprEvaluator: TDSExprEvaluator = nil;         // Not thread-safe

{ TDSParser }

function TDSParser.CharValidInName(C: Char): Boolean;
begin
  Result := (IsCharAlphaNumeric(C)) or (C='_');
end;

procedure TDSParser.CheckNestingValidity(DS: TDSField);
begin
  // Check that all "break"/"continue" are inside arrays/loops
  DS.EnumerateTypeFields(
    function (DS: TDSField): Boolean
    begin
      if DS is TDSArray then Exit(False);
      if (DS is TDSDirective) and
         (SameName(DS.Name, 'continue') or SameName(DS.Name, 'break')) then
      begin
        CurLineNum := DS.DescrLineNum;
        raise EDSParserError.Create('"' + DS.Name + '" not inside array or loop');
      end;
      Result := True;
    end);
end;

procedure TDSParser.CheckValidName(const S: string);
var
  i: Integer;
begin
  if S = '' then  raise EDSParserError.Create('Empty name');
  if IsReservedWord(S) then  raise EDSParserError.Create('Invalid name: ' + S);
//  if not IsCharAlpha(S[Low(S)]) then raise EDSParserError.Create('Invalid name: ' + S);
  for i:=Low(S) to High(S) do
  begin
    if (not CharValidInName(S[i])) or
       ((i = Low(S)) and (CharInSet(S[i], ['0'..'9']))) then  raise EDSParserError.Create('Invalid name: ' + S);
  end;
end;

constructor TDSParser.Create;
begin
  inherited;
  Typedefs := TObjectDictionary<string, TDSField>.Create([doOwnsValues]);
end;

destructor TDSParser.Destroy;
begin
  Typedefs.Free;
  inherited;
end;

procedure TDSParser.EraseComments(var Buf: string);
// Replace comments with spaces.
// Supports  //...  and  /*...*/
var
  i: Integer;
  InLineComment, InBlockComment: Boolean;
begin
  InLineComment := False;
  InBlockComment := False;
  for i:=Low(Buf) to High(Buf) do
  begin
    if (InLineComment or InBlockComment) then
    begin
      // Find comment end
      if (InLineComment) and (i <= High(Buf) - 2) and (Buf[i+1] = #13) and (Buf[i+2] = #10) then
        InLineComment := False;  // Up to, but not including, line break
      if (InBlockComment) and (i <= High(Buf) - 1) and (Buf[i] = '*') and (Buf[i+1] = '/') then
      begin  // Up to "*/" inclusive
        InBlockComment := False;
        Buf[i+1] := ' ';
      end;
      // Replace comments with spaces
      Buf[i] := ' ';
    end
    else
    begin
      // Find comment start
      if (i <= High(Buf) - 1) and (Buf[i] = '/') and (Buf[i+1] = '/') then
      begin
        InLineComment := True;
        Buf[i] := ' ';
      end;
      if (i <= High(Buf) - 1) and (Buf[i] = '/') and (Buf[i+1] = '*') then
      begin
        InBlockComment := True;
        Buf[i] := ' ';
      end;
    end;
  end;
end;

function TDSParser.IsReservedWord(const S: string): Boolean;
begin
  Result := SameName(S, 'if') or
            SameName(S, 'else') or
            SameName(S, 'switch') or
            SameName(S, 'case') or
            SameName(S, 'default') or
            SameName(S, 'break') or
            SameName(S, 'continue') or
            SameName(S, 'var') or
            SameName(S, 'typedef');
end;

function TDSParser.IsTypeName(const S: string): Boolean;
begin
  Result := (ValueInterpretors.FindInterpretor(S) <> nil) or (Typedefs.ContainsKey(S));
end;

function TDSParser.MakeArray(AType: TDSField; const ACount: string): TDSArray;
// Create Array of Count elements of type AType
begin
  Result := TDSArray.Create();
  Result.ElementType := AType.Duplicate();
  Result.ElementType.Parent := Result;
  Result.ACount := ACount;
end;

function TDSParser.ParseStruct(const Descr: string): TDSStruct;
var
  Buffer: string;
begin
  Typedefs.Clear();

  if Descr = '' then
    raise EDSParserError.Create('Empty struct description');

  Buffer := Descr;
  EraseComments(Buffer);

  BufStart := @Buffer[Low(Buffer)];
  BufEnd := @Buffer[High(Buffer)+1];
  Ptr := BufStart;
  CurLineNum := 1;
  CurBigEndian := False;

  try
    Result := ReadStruct();

    CheckNestingValidity(Result);
  except
    on E: Exception do
    begin
      E.Message := 'Line #' + IntToStr(CurLineNum) + ':' + sLineBreak + E.Message;
      raise;
    end;
  end;
end;

function TDSParser.PeekLexem: string;
// Returns next lexem without moving current pointer
var
  OldPtr: PChar;
  OldLnNum: Integer;
begin
  OldPtr := Ptr;
  OldLnNum := CurLineNum;
  try
    Result := ReadLexem();
  finally
    Ptr := OldPtr;
    CurLineNum := OldLnNum;
  end;
end;

procedure TDSParser.PutBack;
begin
  if Ptr > BufStart then
  begin
    Dec(Ptr);
    if Ptr^ = #10 then
      Dec(CurLineNum);
  end;
end;

function TDSParser.ReadBreakStatement: TDSDirective;
// Read "continue"/"break" statement.
// They are saved as "directives"
var
  S: string;
begin
  S := ReadLexem();
  Result := TDSDirective.Create();
  Result.FName := S;
  Result.DescrLineNum := CurLineNum;
end;

function TDSParser.ReadChar: Char;
begin
  if Ptr = BufEnd then Exit(#0);
  Result := Ptr^;
  Inc(Ptr);
  if Result = #10 then Inc(CurLineNum);
end;

function TDSParser.ReadDirective(): TDSDirective;
// Read parser directive #... until end of line
var
  DirName, Value: string;
  i, ALineNum: Integer;
  Notation: TValueDisplayNotation;
  Field: TDSField;
begin
  Result := nil;
  DirName := ReadLexem();

  if SameName(DirName, 'bigendian') then
  begin
    CurBigEndian := True;
    ReadLine();
    Exit;
  end;

  if SameName(DirName, 'littleendian') then
  begin
    CurBigEndian := False;
    ReadLine();
    Exit;
  end;

  if SameName(DirName, 'valid') then
  begin
    Value := Trim(ReadLine());
    if Value = '' then
      raise EDSParserError.Create('Validation statement expected');
    if LastStatementFields = nil then
      raise EDSParserError.Create('"#valid" directive should be right after validated fields');
    for i:=0 to Length(LastStatementFields)-1 do
      (LastStatementFields[i] as TDSSimpleField).ValidationStr := Value;
    Exit;
  end;

  if SameName(DirName, 'format') then
  begin
    Value := LowerCase(Trim(ReadLine()));
    if Value = 'bin' then
      Notation := nnBin
    else
    if Value = 'dec' then
      Notation := nnDec
    else
    if Value = 'hex' then
      Notation := nnHex
    else
      raise EDSParserError.Create('Format specifier expected');
    if LastStatementFields = nil then
      raise EDSParserError.Create('"#format" directive should be right after affected fields');
    for i:=0 to Length(LastStatementFields)-1 do
      LastStatementFields[i].DisplayFormat := Notation;
    Exit;
  end;

  if SameName(DirName, 'hint') then
  begin
    Value := Trim(ReadLine());
    if LastStatementFields = nil then
      raise EDSParserError.Create('"#hint" directive should be right after affected fields');
    for i:=0 to Length(LastStatementFields)-1 do
      LastStatementFields[i].HintTemplate := Value;
    Exit;
  end;

  if SameName(DirName, 'itemhint') then
  begin
    Value := Trim(ReadLine());
    if LastStatementFields = nil then
      raise EDSParserError.Create('"#itemhint" directive should be right after affected fields');
    for i:=0 to Length(LastStatementFields)-1 do
    begin
      if LastStatementFields[i] is TDSArray then
        TDSArray(LastStatementFields[i]).ElementType.HintTemplate := Value
      else
      if LastStatementFields[i] is TDSCompoundField then
      begin
        for Field in TDSCompoundField(LastStatementFields[i]).NamedFields do
          Field.HintTemplate := Value;
      end
      else
        raise EDSParserError.Create('"#itemhint" directive not applicable to this field');
    end;
    Exit;
  end;

  if (SameName(DirName, 'addr')) or (SameName(DirName, 'align_pos')) then
  begin
    ALineNum := CurLineNum;
    Value := Trim(ReadLine());
    if Value = '' then
      raise EDSParserError.Create('Value expected');
    Result := TDSDirective.Create();
    Result.DescrLineNum := ALineNum;
    Result.FName := DirName;
    Result.Value := Value;
    Exit;
  end;

  if SameName(DirName, 'align') then
  begin
    Value := Trim(ReadLine());
    if Value = '' then
      raise EDSParserError.Create('Value expected');
    if CurStruct = nil then
      raise EDSParserError.Create('"#align" directive not inside structure');
    CurStruct.FieldAlign := EvalConst(Value);
    Exit;
  end;

  raise EDSParserError.Create('Unknown parser directive: ' + DirName);
end;

function TDSParser.ReadExpectedLexem(const Expected: array of string): string;
// Read lexem and check if it is one from expected list
var
  i: Integer;
  s: string;
begin
  Result := ReadLexem();
  for i:=0 to High(Expected) do
    if Expected[i] = Result then Exit;
  // Generate error message
  s := '';
  if Length(Expected) = 0 then
  begin
  end
  else
  begin
    for i:=0 to Length(Expected)-2 do
    begin
      s := s + '"' + Expected[i] + '"';
      if i < Length(Expected)-2 then
        s := s + ', '
      else
        s := s + ' or ';
    end;
    s := s + '"' + Expected[High(Expected)] + '"';
  end;
  raise EDSParserError.Create(s + ' expected');
end;

function TDSParser.ReadExpressionStr(StopAtChars: TSysCharSet = [';']): string;
// Read expression text until closing bracket or one of specified chars found at level 0
var
  Level: Integer;
  C: Char;
begin
  Result := '';
  Level := 0;

  repeat
    C := ReadChar();
    case C of
      '[', '(', '{': Inc(Level);
      ']', ')', '}': Dec(Level);
    end;
    if (Level < 0) or (C = #0) then Break;
    if (Level = 0) and (CharInSet(C, StopAtChars)) then Break;

    Result := Result + C;
  until False;

  if C <> #0 then PutBack();
end;

function TDSParser.ReadFieldsDeclaration(): TArrayOfDSField;
// Read data type followed by field names
var
  S, AName, ACount: string;
  AType, AInstance: TDSField;
  ShouldFreeType: Boolean;
begin
  Result := nil;
  // Read type description
  AType := ReadType(ShouldFreeType);

  // Read field names
  try
    AType.DescrLineNum := CurLineNum;

    repeat
      S := PeekLexem();
      if (S = ';') or (S = '') or (S = '}') or (SameName(S, 'else')) then
        AName := ''
      else
      begin
        AName := ReadLexem();
        CheckValidName(AName);
      end;

      S := PeekLexem();
      if S = '[' then  // It is array
      begin
        ReadLexem();
        // Read array size
        ACount := ReadExpressionStr();
        ReadExpectedLexem([']']);
        // Create array of Count elements of given type
        AInstance := MakeArray(AType, ACount);
        AInstance.DescrLineNum := CurLineNum;

        S := PeekLexem();  // "," or ";"
      end
      else
      begin
        AInstance := AType.Duplicate();
      end;

      AInstance.FName := AName;
      Result := Result + [AInstance];

  //      WriteLogF('Struct', AnsiString(AInstance.ClassName+' '+AInstance.Name));

      if S = ',' then  // Next name
      begin
        ReadLexem();
        Continue;
      end;
      if S = ';' then  // End of statement
      begin
        Break;
      end;
      if SameName(S, 'else') then  // End of statement
      begin
        Break;
      end;
      if (S = '') or (S = '}') then Exit;       // End of description

      raise EDSParserError.Create('";" or "," expected');
    until False;

  finally
    if ShouldFreeType then
      AType.Free;
    LastStatementFields := Result;
  end;
end;

procedure TDSParser.ReadTypedef;
// typedef type_definition names_list;
var
  Items: TArrayOfDSField;
  Item: TDSField;
begin
//  Result := TDSTypedef.Create();
//  try
//    Items := ReadFieldsDeclaration();
//    Result.ATypes.AddRange(Items);
//  except
//    Result.Free;
//    raise;
//  end;

  Items := ReadFieldsDeclaration();
  // typedef's currently have global scope
  for Item in Items do
    Typedefs.AddOrSetValue(Item.Name, Item);
end;

function TDSParser.ReadHelperVar: TDSHelperVariable;
// var name = expression;
var
  VarName: string;
begin
  Result := TDSHelperVariable.Create();
  try
    Result.DescrLineNum := CurLineNum;
    // Name
    VarName := ReadLexem();
    CheckValidName(VarName);
    Result.FName := VarName;

    ReadExpectedLexem(['=']);

    // Value (expression)
    Result.Value := ReadExpressionStr();
  except
    Result.Free;
    raise;
  end;
end;

function TDSParser.ReadIfStatement: TDSConditional;
// if (Value) Statement;
var
  S: string;
  AFields, AElseFields: TArrayOfDSField;
  i: Integer;
begin
  Result := TDSConditional.Create();
  Result.DescrLineNum := CurLineNum;

  // Read Condition
  ReadExpectedLexem(['(']);
  S := ReadExpressionStr();
  ReadExpectedLexem([')']);
  Result.ACondition := S;

  // Read If Statement
  AFields := ReadStatement();
  for i:=0 to Length(AFields)-1 do
    AFields[i].Parent := Result;

  // Read Else Statement
  if SameName(PeekLexem(), 'else') then
  begin
    ReadLexem();
    AElseFields := ReadStatement();
    for i:=0 to Length(AElseFields)-1 do
      AElseFields[i].Parent := Result;
  end;

  // "if" branch
  Result.AddBranch([VariantRange(True)], AFields);
  // "else" branch
  if AElseFields <> nil then
    Result.AddBranch([VariantRange(DSDefaultCaseVariant)], AElseFields);
end;

function TDSParser.ReadLexem: string;
// Lexem: identifier, number or operator/punctuation
var
  First, C: Char;
begin
  // Skip spaces
  repeat
    First := ReadChar();
  until not CharInSet(First, [#9, #10, #13, ' ']);
  if First = #0 then Exit('');

  Result := First;
  // All punctuation is single-char
  if not CharValidInName(First) then Exit;

  // Read all digits and letters
  while True do
  begin
    C := ReadChar();
    if not CharValidInName(C) then Break;
    Result := Result + C;
  end;
  if C <> #0 then
    PutBack();
end;

function TDSParser.ReadLine: string;
// Read until line break
var
  C: Char;
begin
  Result := '';
  repeat
    C := ReadChar();
    if C = #0 then Exit;
    if C = #13 then
    begin
      C := ReadChar();
      if C <> #10 then PutBack();
      Exit;
    end;
    Result := Result + C;
  until False;
end;

function TDSParser.ReadScriptBlock: TDSScriptBlock;
// Some script inside of structure definition
begin
  Result := TDSScriptBlock.Create();
  try
    Result.DescrLineNum := CurLineNum;
    // Script text
    Result.Value := ReadExpressionStr();
  except
    Result.Free;
    raise;
  end;
end;

function TDSParser.ReadStatement: TArrayOfDSField;
// Statement is Type + list of names until ;
// It also may be conditional block like "if"
var
  AInstance: TDSField;
  S: string;
begin
  Result := nil;

  S := PeekLexem();

  try

    if S = ';' then
    // Empty statement
    begin
      Exit;
    end;

    while S = '#' do
    // Parser directive
    begin
      ReadLexem();
      AInstance := ReadDirective();
      // Some directives are turned into fields and are treated as full-fledged statemants
      if AInstance <> nil then
      begin
        Result := [AInstance];
        Exit;
      end;
      S := PeekLexem();
    end;

    if SameName(S, 'if') then
    // if (Value) Statement
    begin
      ReadLexem();
      Result := [ReadIfStatement()];
      Exit;
    end;

    if SameName(S, 'switch') then
    // switch (Expr) { case Value1: Statement1; ... }
    begin
      ReadLexem();
      Result := [ReadSwitchStatement()];
      Exit;
    end;

    if SameName(S, 'break') or SameName(S, 'continue') then
    begin
      Result := [ReadBreakStatement()];
      Exit;
    end;

    if SameName(S, 'var') then
    // var name = expression;
    begin
      ReadLexem();
      Result := [ReadHelperVar()];
      Exit;
    end;

    if SameName(S, 'typedef') then
    // typedef type_definition name;
    begin
      ReadLexem();
      //Result := [ReadTypedef()];
      ReadTypedef();
      Exit;
    end;

    if S = '}' then
    // End of strict
    begin
      Exit;
    end;

    if (S = '{') or (IsTypeName(S)) then
    // Type name + Field list
    begin
      Result := ReadFieldsDeclaration();
      Exit;
    end;

    // Everything else is treated as scripts
    Result := [ReadScriptBlock()];

  finally
    if PeekLexem() = ';' then
      ReadLexem();
  end;
end;

function TDSParser.ReadStruct: TDSStruct;
// Read structure fields
var
  i: Integer;
  Fields: TArrayOfDSField;
  PrevCurStruct: TDSCompoundField;
begin
  Result := TDSStruct.Create();
  PrevCurStruct := CurStruct;
  CurStruct := Result;
  try
    try
      while (Ptr < BufEnd) do
      begin
        if PeekLexem() = '}' then Break;
        Fields := ReadStatement();
        for i:=0 to Length(Fields)-1 do
        begin
          Result.AddField(Fields[i]);
        end;
      end;
    finally
      LastStatementFields := nil;  // "#valid" works only inside same struct
      CurStruct := PrevCurStruct;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TDSParser.ReadSwitchStatement: TDSConditional;
//switch (expression) {
//  case cond1: statement1;
//  case cond2: statement2;
//  default: statementD;
//}
var
  S, ACond, ACase: string;
  AKeys: TVariantRanges;
  AFields: TArrayOfDSField;
  i: Integer;
begin
  // Read Condition
  ReadExpectedLexem(['(']);
  ACond := ReadExpressionStr();
  ReadExpectedLexem([')']);

  ReadExpectedLexem(['{']);

  Result := TDSConditional.Create();
  Result.DescrLineNum := CurLineNum;
  Result.ACondition := ACond;
  try
    // Read cases
    while True do
    begin
      S := ReadLexem();
      if SameName(S, 'case') then
      begin
        ACase := ReadExpressionStr([';', ':']);
        AKeys := StrToVariantRanges(ACase);
      end
      else
      if SameName(S, 'default') then
      begin
        AKeys.Ranges := [VariantRange(DSDefaultCaseVariant)];
      end
      else
      if S = '}' then
        Break
      else
        raise EDSParserError.Create('"case", "default" or "}" expected');

      ReadExpectedLexem([':']);
      // Read Statement
      AFields := ReadStatement();
      for i:=0 to Length(AFields)-1 do
        AFields[i].Parent := Result;
      Result.AddBranch(AKeys.Ranges, AFields);
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TDSParser.ReadType(var ShouldFree: Boolean): TDSField;
var
  S: string;
begin
  S := ReadLexem;
  if S = '{' then
  begin
    Result := ReadStruct();
    ReadExpectedLexem(['}']);
    ShouldFree := True;
  end
  else
  if Typedefs.TryGetValue(S, Result) then
  begin
    ShouldFree := False;
  end
  else
  begin
    CheckValidName(S);
    Result := TDSSimpleField.Create();
    TDSSimpleField(Result).DataType := S;
    TDSSimpleField(Result).BigEndian := CurBigEndian;
    ShouldFree := True;
  end;
end;

{ TDSSimpleField }

procedure TDSSimpleField.Assign(Source: TDSField);
begin
  inherited;
  if Source is TDSSimpleField then
  begin
    DataType := TDSSimpleField(Source).DataType;
    BigEndian := TDSSimpleField(Source).BigEndian;
    ValidationStr := TDSSimpleField(Source).ValidationStr;
  end;
end;

constructor TDSSimpleField.Create;
begin
  inherited;
end;

function TDSSimpleField.GetData: TBytes;
// Get field data from underlying data source (edited file buffer)
begin
  with EventSet do
    DataGetProc(DataContext, BufAddr, BufSize, Result);
end;

function TDSSimpleField.GetFixedSize: TFilePointer;
var
  Intr: TValueInterpretor;
begin
  Intr := GetInterpretor();
  if Intr = nil then
    Result := -1
  else
    Result := Intr.MinSize;
end;

function TDSSimpleField.GetInterpretor(
  RaiseException: Boolean): TValueInterpretor;
begin
  if FInterpretor = nil then
    FInterpretor := ValueInterpretors.FindInterpretor(DataType);
  Result := FInterpretor;
  if (Result = nil) and (RaiseException) then
    raise EDSParserError.Create('Unknown type name: ' + DataType);
end;

procedure TDSSimpleField.SetData(const Value: TBytes; AChanger: TObject = nil);
// Write new field data to underlying data source (edited file buffer)
begin
  if Length(Value) <> BufSize then
    raise EDSParserError.Create('Cannot change field size');
  with EventSet do
    DataChangeProc(DataContext, BufAddr, BufSize, BufSize, @Value[0]);
  // Notify subscribed listeners
  DoChanged(AChanger);
end;

procedure TDSSimpleField.SetFromVariant(const V: Variant; AChanger: TObject = nil);
var
  Intr: TValueInterpretor;
  AData: TBytes;
begin
  Intr := GetInterpretor();
  if BufSize <> Intr.MinSize then
    // Field size may have been changed by manually changing data in file
    raise EDSParserError.Create('Invalid field size');
  SetLength(AData, BufSize);
  Intr.FromVariant(V, AData[0], Length(AData));
  if BigEndian then
    InvertByteOrder(AData[0], Length(AData));
  SetData(AData, AChanger);
end;

procedure TDSSimpleField.SetValidationStr(const Value: string);
var
  DS: TDSCompoundField;
  d: integer;
begin
  if FValidationStr <> Value then
  begin
    // Update "Childs with validation" count in parents
    if (Value <> '') and (FValidationStr = '') then d := 1
    else if (Value = '') and (FValidationStr <> '') then d := -1
    else d := 0;
    if d <> 0 then
    begin
      DS := Self.Parent;
      while DS <> nil do
      begin
        Inc(DS.ChildsWithValidations, d);
        DS := DS.Parent;
      end;
    end;

    FValidationStr := Value;
  end;
end;

function TDSSimpleField.ToQuotedString(): string;
begin
  Result := ToString();
  if (DataType = 'ansi') or (DataType = 'unicode') then
    Result := '''' + Result + '''';
end;

function TDSSimpleField.ToString(): string;
var
  Value: Variant;
begin
  Value := ToVariant();
  if VarIsOrdinal(Value) then
  begin
    // Apply format specifier
    case DisplayFormat of
      nnBin: Exit('0b' + IntToBin(Value, {Length(AData)}BufSize * 8));
      nnDec: Exit(IntToStr(Value));
      nnHex: Exit('0x' + IntToHex(Value, 1));
    end;
  end;
  Result := Value;
end;

function TDSSimpleField.ToVariant: Variant;
var
  AData: TBytes;
  Intr: TValueInterpretor;
begin
  AData := Data;
  Intr := GetInterpretor(True);
  if BufSize <> Intr.MinSize then
  // Field size may have been changed by manually changing data in file
  begin
    VarClear(Result);
    Exit;
  end;
  if BigEndian then
    InvertByteOrder(AData[0], Length(AData));
  Result := Intr.ToVariant(AData[0], Length(AData));
end;

{ TDSCompoundField }

function TDSCompoundField.AddField(Field: TDSField): Integer;
begin
  Field.Parent := Self;
  Result := FFields.Add(Field);
  Field.FIndex := Result;
end;

procedure TDSCompoundField.Assign(Source: TDSField);
var
  i: Integer;
begin
  inherited;
  if Source is TDSCompoundField then
  begin
    FFields.Clear();
    for i:=0 to TDSCompoundField(Source).FieldsCount-1 do
    begin
      AddField( TDSCompoundField(Source).Fields[i].Duplicate() );
    end;
    FieldAlign := TDSCompoundField(Source).FieldAlign;
    ChildsWithErrors := TDSCompoundField(Source).ChildsWithErrors;
    ChildsWithValidations := TDSCompoundField(Source).ChildsWithValidations;
    if TDSCompoundField(Source).FHelperVars = nil then
      FreeAndNil(FHelperVars)
    else
    begin
      if FHelperVars = nil then
        FHelperVars := TList<TPair<string, Variant>>.Create();
      FHelperVars.Clear();
      FHelperVars.AddRange(TDSCompoundField(Source).FHelperVars);
    end;
  end;
end;

constructor TDSCompoundField.Create;
begin
  inherited;
  FFields := TObjectList<TDSField>.Create(True);
end;

destructor TDSCompoundField.Destroy;
begin
  if Assigned(FComWrapper) then
    FComWrapper._Release();
  FFields.Free;
  FHelperVars.Free;
  inherited;
end;

function TDSCompoundField.FindHelperVar(const Name: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  if FHelperVars = nil then Exit;
  for i := 0 to FHelperVars.Count - 1 do
    if SameName(Name, FHelperVars[i].Key) then
      Exit(i);
end;

function TDSCompoundField.GetComWrapper: TDSComWrapper;
begin
  if FComWrapper = nil then
  begin
    FComWrapper := TDSComWrapper.Create();
    FComWrapper.DSField := Self;
    FComWrapper._AddRef();
  end;
  Result := FComWrapper;
end;

function TDSCompoundField.GetFieldAlign: Integer;
// Get field alignment. It may be inherited from parent structure.
var
  DS: TDSCompoundField;
begin
  if FieldAlign > 0 then
    Exit(FieldAlign);
  // Find nearest parent with non-zero field alignment.
  // Save result into FieldAlign of this structure to not search next time.
  DS := Self;
  while (DS.FieldAlign <= 0) and (DS.Parent <> nil) do
    DS := DS.Parent;
  if DS.FieldAlign = 0 then  // Stopped at Root DS
    Result := 1
  else
    Result := DS.FieldAlign;
  Self.FieldAlign := Result;
end;

function TDSCompoundField.GetFields(Index: Integer): TDSField;
begin
  Result := FFields[Index];
end;

function TDSCompoundField.GetFieldsCount: Integer;
begin
  Result := FFields.Count;
end;

function TDSCompoundField.NamedFieldByIndex(Index: Integer): TDSField;
// Slow for non-arrays
begin
  if (Self is TDSArray) then
  begin
    if (Index >= 0) and (Index < FieldsCount) then
      Result := Fields[Index]
    else
      Result := nil;
    Exit;
  end;
  for Result in NamedFields do
  begin
    Dec(Index);
    if Index < 0 then Exit;
  end;
  Result := nil;
end;

function TDSCompoundField.NamedFields: INamedFieldsEnumerable;
begin
  Result := TNamedFieldsEnumerable.Create(Self);
end;

procedure TDSCompoundField.SetHelperVar(const Name: string;
  const Value: Variant);
var
  i: Integer;
begin
  if FHelperVars = nil then
    FHelperVars := TList<TPair<string, Variant>>.Create();
  i := FindHelperVar(Name);
  if i >= 0 then
    FHelperVars[i] := TPair<string, Variant>.Create(Name, Value)
  else
    FHelperVars.Add(TPair<string, Variant>.Create(Name, Value));
end;

function TDSCompoundField.ToString(): string;
const
  MaxDispLen = 100;
var
  i: Integer;
begin
  Result := '(';
  for i:=0 to FieldsCount-1 do
  begin
    if Fields[i] is TDSDirective then Continue;
    if Length(Result) >= MaxDispLen then
    begin
      Result := Result + '...';
      Break;
    end;
    if Length(Result) > 1 then
      Result := Result + ', ';
    Result := Result + Fields[i].ToQuotedString();
  end;
  Result := Result + ')';
end;

{ TDSArray }

procedure TDSArray.AllocateFieldsList(ACount: Integer = -1);
// If deferred loading is used, make sure we have allocated pointers to at least
// ACount first elements (by default - all elements)
begin
  if FRealCount < 0 then Exit;
  if ACount < 0 then ACount := FRealCount;

  // Simple optimization for a case when we need only few first elements
  // (e.g. to show in structure tree view)
  if (ACount <= 1024) and (FRealCount > 1024) then
    FFields.Count := 1024
  else
  begin
    FFields.Count := FRealCount;
    FRealCount := -1;
  end;
end;

procedure TDSArray.Assign(Source: TDSField);
begin
  inherited;
  if Source is TDSArray then
  begin
    ElementType := TDSArray(Source).ElementType.Duplicate();
    ElementType.Parent := Self;
    ACount := TDSArray(Source).ACount;
  end;

end;

constructor TDSArray.Create;
begin
  inherited;
  FRealCount := -1;
end;

destructor TDSArray.Destroy;
begin
  ElementType.Free;
  inherited;
end;

function TDSArray.GetFields(Index: Integer): TDSField;
var
  Interpretor: TDSInterpretor;
  Sz: TFilePointer;
begin
  // Deferred loading: allocate memory for items
  AllocateFieldsList(Index + 1);

  Result := inherited;

  if Result = nil then
  // If this element is not created, create it now
  begin
    Sz := ElementType.GetFixedSize();
    if Sz < 0 then
      raise EDSParserError.Create('Cannot dynamically load array with variable-sized elements');
    Interpretor := TDSInterpretor.Create();
    try
      Result := ElementType.Duplicate();
      Result.Parent := Self;
      FFields[Index] := Result;
      Result.FIndex := Index;
      FCurParsedItem := Index;
      Interpretor.Interpret(Result, BufAddr + Sz * Index, Sz);
    finally
      Interpretor.Free;
    end;
  end;
end;

function TDSArray.GetFieldsCount: Integer;
begin
  if FRealCount >= 0 then  // Deferred loading
    Result := FRealCount
  else
    Result := inherited;
end;

function TDSArray.GetFixedSize: TFilePointer;
// Array data size is fixed if it has fixed length and fixed-size elements
var
  V: Variant;
  Len: Integer;
  Sz: TFilePointer;
begin
  V := EvalConstDef(ACount);
  if VarIsOrdinal(V) then Len := V
                     else Exit(-1);
  Sz := ElementType.GetFixedSize();
  if Sz < 0 then Exit(-1);
  Result := Sz * Len;
end;

procedure TDSArray.SetLength(NewLength: Integer);
// Insert/remove bytes in underlying data buffer according to new array size
var
  Sz: TFilePointer;
  OldLength, i: Integer;
  Buf: TBytes;
  Interpretor: TDSInterpretor;
  Element: TDSField;
begin
  if NewLength < 0 then
    raise EDSParserError.Create('Invalid array length');
  OldLength := FieldsCount;
  if NewLength = OldLength then Exit;
  Sz := ElementType.GetFixedSize();
  if Sz < 0 then
    raise EDSParserError.Create('Cannot resize array with variable-sized elements');

  AllocateFieldsList();  // Just to simplify logic

  if NewLength < OldLength then
  begin  // Delete elements
    FFields.Count := NewLength;

    with EventSet do
      DataChangeProc(DataContext, BufAddr + Sz * NewLength, Sz * (OldLength - NewLength), 0, nil);
  end
  else
  begin  // Add elements, filled with zero
    // Insert block of zero bytes to underlying data
    System.SetLength(Buf, (NewLength - OldLength) * Sz);
    with EventSet do
      DataChangeProc(DataContext, BufAddr + Sz * OldLength, 0, Length(Buf), @Buf[0]);
    // Initialyze elements from this data
    FFields.Capacity := NewLength;
    Interpretor := TDSInterpretor.Create();
    Progress.TaskStart(Self);
    try
      Interpretor.FStartAddr := BufAddr + Sz * OldLength;
      Interpretor.FMaxSize := Length(Buf);
      Interpretor.FCurAddr := Interpretor.FStartAddr;
      Interpretor.EndOfData := (Interpretor.FMaxSize = 0);

      for i:=OldLength to NewLength-1 do
      begin
        Element := ElementType.Duplicate();
        FCurParsedItem := AddField(Element);
        Interpretor.InternalInterpret(Element);
      end;
    finally
      Progress.TaskEnd();
      Interpretor.Free;
    end;
  end;

  DoChanged(nil);
end;

function TDSArray.ToQuotedString(): string;
begin
  Result := ToString();
  if (ElementType is TDSSimpleField) and (
      ((ElementType as TDSSimpleField).DataType = 'ansi') or
      ((ElementType as TDSSimpleField).DataType = 'unicode')) then
  begin
    Result := '"' + Result + '"';
  end;
end;

function TDSArray.ToString(): string;
const
  MaxDispLen = 100;
var
  i: Integer;
begin
  if (ElementType is TDSSimpleField) and (
      ((ElementType as TDSSimpleField).DataType = 'ansi') or
      ((ElementType as TDSSimpleField).DataType = 'unicode')) then
  begin
    Result := '';
    for i:=0 to Min(FieldsCount, MaxDispLen)-1 do
      Result := Result + Fields[i].ToString();
    if FieldsCount > MaxDispLen then
      Result := Result + '...';
  end
  else
    Result := inherited;
end;

{ TDSStruct }

constructor TDSStruct.Create;
begin
  inherited;

end;

function TDSStruct.GetFixedSize: TFilePointer;
// Structure size is defined if all child fields are fixed size
var
  i: Integer;
  Sz: TFilePointer;
begin
  Result := 0;
  for i:=0 to FieldsCount-1 do
  begin
    Sz := Fields[i].GetFixedSize();
    if Sz < 0 then Exit(-1);
    Result := Result + Sz;
  end;
end;

{ TDSField }

procedure TDSField.Assign(Source: TDSField);
begin
  FIndex := Source.FIndex;
  FName := Source.FName;
  Parent := Source.Parent;
  DescrLineNum := Source.DescrLineNum;
  DisplayFormat := Source.DisplayFormat;
  FEventSet := Source.FEventSet;
  ErrorText := Source.ErrorText;
  HintTemplate := Source.HintTemplate;
end;

constructor TDSField.Create;
begin
  inherited;
  FIndex := -1;
end;

destructor TDSField.Destroy;
begin
  if EventSet <> nil then
    with EventSet do
      OnDestroy.Call(DataContext, Self);
  // Root DS is responsible for freeing EventSet
  if Parent = nil then
    FreeAndNil(FEventSet);
  inherited;
end;

procedure TDSField.DoChanged(Changer: TObject);
begin
  with EventSet do
    OnChanged.Call(DataContext, Self, Changer);
  if Parent <> nil then
    Parent.DoChanged(Changer);
end;

function TDSField.Duplicate(): TDSField;
begin
  Result := TDSFieldClass(Self.ClassType).Create();
  Result.Assign(Self);
end;

function TDSField.FullName: string;
var
  ParentFullName: string;
begin
  Result := Name;
  if Parent <> nil then
    ParentFullName := Parent.FullName()
  else
    ParentFullName := '';
  if Result = '' then
    Result := ParentFullName
  else
  if ParentFullName <> '' then
  begin
    if Parent is TDSArray then
      Result := ParentFullName + '[' + Result + ']'
    else
      Result := ParentFullName + '.' + Result;
  end;
end;

function TDSField.GetFixedSize: TFilePointer;
// For fixed-size fields, returns estimated size
// For variable-size fields (e.g. conditional or variable-length arrays), returns -1
begin
  Result := -1;
end;

function TDSField.GetEventSet: TDSEventSet;
// Get Event set. It may be inherited from parent structure.
var
  DS: TDSField;
begin
  // Find nearest parent with defined event set.
  DS := Self;
  while (DS.FEventSet = nil) and (DS.Parent <> nil) do
    DS := DS.Parent;
  Result := DS.FEventSet;
  // Save result into FEventSet of this structure to not search next time.
  if DS <> Self then
    Self.FEventSet := Result;
end;

function TDSField.GetName: string;
begin
  if FName <> '' then
    Result := FName
  else
    if (Parent <> nil) and (Parent is TDSArray) then
      Result := IntToStr(FIndex)
    else
      Result := '';
end;

function TDSField.Hint: string;
begin
  if HintTemplate = '' then Result := ''
  else Result := TDSExprEvaluator.Eval(HintTemplate, Self, nil);
end;

procedure TDSField.SetErrorText(const Value: string);
var
  DS: TDSCompoundField;
  d: integer;
begin
  if FErrorText <> Value then
  begin
    // Update error count in parents
    if (Value <> '') and (FErrorText = '') then d := 1
    else if (Value = '') and (FErrorText <> '') then d := -1
    else d := 0;
    if d <> 0 then
    begin
      DS := Self.Parent;
      while DS <> nil do
      begin
        Inc(DS.ChildsWithErrors, d);
        DS := DS.Parent;
      end;
    end;

    FErrorText := Value;
  end;
end;

procedure TDSField.SetParent(const Value: TDSCompoundField);
begin
  if FParent <> Value then
  begin
    FParent := Value;
  end;
end;

function TDSField.ToQuotedString(): string;
begin
  Result := ToString();
end;

function TDSField.ToString(): string;
begin
  Result := '';
end;

function TDSField.EnumerateFields(const Range: TFileRange;
  Proc: TFieldEnumProc; Order: TFieldEnumOrder = eoFromRoot): Integer;
// Pass DS and its childs recuresively to procedure Proc.
// Only process fields which intersect specified range.
// Can enumerate in different order: from root to leafs or from leafs to root.
// When enumerating from root, you can stop enumeration at any level, but
// you can't change fields' addresses during enumeration because it will break
// subsequent child field enumeration if Range is specified
var
  i, n1, n2: Integer;
  ElemSize: TFilePointer;
begin
  Result := 0;
  // Check within requested address range
  if Range <> EntireFile then
    if (Self.BufAddr >= Range.AEnd) or (Self.BufAddr + Self.BufSize <= Range.Start) then Exit;

  if Order = eoFromRoot then
  begin
    if not Proc(Self) then Exit;
    Inc(Result);
  end;

  // Add childs
  if (Self is TDSCompoundField) and (TDSCompoundField(Self).FieldsCount > 0) then
  begin
    n1 := 0;
    n2 := TDSCompoundField(Self).FieldsCount - 1;
    // For arrays with fixed-size elements, we can calculate exact item range
    if (Self is TDSArray) then
    begin
      ElemSize := (Self as TDSArray).ElementType.GetFixedSize();
      if ElemSize > 0 then
      begin
        n1 := BoundValue( (Range.Start - Self.BufAddr) div ElemSize, 0, (Self as TDSArray).FieldsCount - 1);
        n2 := BoundValue( DivRoundUp(Range.AEnd - Self.BufAddr, ElemSize) - 1, 0, (Self as TDSArray).FieldsCount - 1);
      end;
    end;

    for i:=n1 to n2 do
      Inc(Result, TDSCompoundField(Self).Fields[i].EnumerateFields(Range, Proc, Order));
  end;

  if Order = eoFromLeafs then
  begin
    if not Proc(Self) then Exit;
    Inc(Result);
  end;
end;

function TDSField.EnumerateTypeFields(Proc: TFieldEnumProc;
  Order: TFieldEnumOrder): Integer;
// Like EnumerateFields(), but enumerates not an instance, but type fields
// (ElementType fields for arrays, all branches for conditional fields)
var
  i, j: Integer;
begin
  Result := 0;

  if Order = eoFromRoot then
  begin
    if not Proc(Self) then Exit;
    Inc(Result);
  end;


  if Self is TDSArray then
    Inc(Result, TDSArray(Self).ElementType.EnumerateTypeFields(Proc, Order))

  else
  if Self is TDSConditional then
  with TDSConditional(Self) do
  begin
    for i := 0 to Branches.Count-1 do
      for j := 0 to Length(Branches[i].Fields)-1 do
        Inc(Result, Branches[i].Fields[j].EnumerateTypeFields(Proc, Order));
  end

  else
    if Self is TDSCompoundField then
      for i := 0 to TDSCompoundField(Self).FieldsCount-1 do
        Inc(Result, TDSCompoundField(Self).Fields[i].EnumerateTypeFields(Proc, Order));


  if Order = eoFromLeafs then
  begin
    if not Proc(Self) then Exit;
    Inc(Result);
  end;
end;

{ TDSConditional }

procedure TDSConditional.AddBranch(const AKeys: TArray<TVariantRange>;
  const AFields: TArrayOfDSField);
var
  Branch: TBranch;
begin
  Branch.Keys.Ranges := AKeys;
  Branch.Fields := AFields;
  Branches.Add(Branch);
end;

procedure TDSConditional.Assign(Source: TDSField);
var
  ABranch, Branch: TBranch;
  i: Integer;
begin
  inherited;
  if Source is TDSConditional then
  begin
    ACondition := TDSConditional(Source).ACondition;
    Branches.Clear();
    // Clone all conditional branches
    for ABranch in TDSConditional(Source).Branches do
    begin
      Branch.Keys.Ranges := Copy(ABranch.Keys.Ranges);
      Branch.Fields := DuplicateDSFieldArray(ABranch.Fields);
      for i:=0 to Length(Branch.Fields)-1 do
        Branch.Fields[i].Parent := Self;
      Branches.Add(Branch);
    end;
  end;
end;

constructor TDSConditional.Create;
begin
  inherited;
  Branches := TList<TBranch>.Create();
end;

destructor TDSConditional.Destroy;
var
  i: Integer;
begin
  for i:=0 to Branches.Count-1 do
    FreeDSFieldArray(Branches[i].Fields);
  Branches.Free;
  inherited;
end;

function TDSConditional.GetFieldsByKey(Key: Variant): TArrayOfDSField;
// Get a set of fields corresponding to specified Key value
var
  n: Integer;
begin
  for n:=0 to Branches.Count-1 do
  begin
    if Branches[n].Keys.Contains(Key) then
      Exit(Branches[n].Fields);
  end;
  Result := nil;
end;

{ TDSInterpretor }

//procedure TDSInterpretor.CheckParent(DS: TDSField);
//var
//  i: Integer;
//begin
//  if DS is TDSCompoundField then
//  begin
//    for i:=0 to (DS as TDSCompoundField).Fields.Count-1 do
//    begin
//      if (DS as TDSCompoundField).Fields[i].Parent <> DS then
//        WriteLogF('Check', DS.Name+' '+(DS as TDSCompoundField).Fields[i].Name+' '+(DS as TDSCompoundField).Fields[i].Parent.Name);
//      CheckParent((DS as TDSCompoundField).Fields[i]);
//    end;
//  end;
//end;

constructor TDSInterpretor.Create;
begin
  inherited;
//  DSStack := TStack<TDSField>.Create();
  APIEnv := TAPIEnvironment.Create();
end;

class function TDSInterpretor.DbgDescr(DS: TDSField): string;
var
  sl: TStringList;
begin
  sl := TStringList.Create();
  try
    DbgDescribe(DS, sl, '', DS.Parent);
    Result := sl.Text;
  finally
    sl.Free;
  end;
end;

class procedure TDSInterpretor.DbgDescribe(DS: TDSField; Text: TStrings;
  Indent: string; AParent: TDSField);
var
  i: Integer;
  s: string;
begin
  s := Indent + IntToHex(UIntPtr(DS), SizeOf(UIntPtr)*2) + ') ' + DS.ClassName + ' ' + DS.Name;
  if DS is TDSSimpleField then
    s := s + ' ' + DS.ToString();
  s := s + ' ^' + IntToHex(UIntPtr(DS.Parent), SizeOf(UIntPtr)*2);
  if DS.Parent <> AParent then
    s := s + '!!!';
  Text.Add(s);
  if DS is TDSCompoundField then
  begin
    for i:=0 to (DS as TDSCompoundField).FieldsCount-1 do
      DbgDescribe((DS as TDSCompoundField).Fields[i], Text, Indent + '  ', DS);
  end;
end;

destructor TDSInterpretor.Destroy;
begin
//  DSStack.Free;
  APIEnv.ObjectDestroyed(Self);
  APIEnv.Free;
  inherited;
end;



function TDSInterpretor.GetFieldSize(DS: TDSSimpleField): Integer;
var
  Intr: TValueInterpretor;
begin
  Intr := DS.GetInterpretor();
  Result := Intr.MinSize;
end;

procedure TDSInterpretor.InternalInterpret(DS: TDSField);
begin
  DS.BufAddr := FCurAddr;

  // Real structure size is unknown, so suppose buffer size
  Progress.Show(FCurAddr - FStartAddr, FMaxSize, IntToStr(FieldsProcessed) + ' fields processed');
  try
    try
      if DS is TDSSimpleField then
        InterpretSimple(TDSSimpleField(DS))
      else
      if DS is TDSStruct then
        InterpretStruct(TDSStruct(DS))
      else
      if DS is TDSArray then
        InterpretArray(TDSArray(DS))
      else
      if DS is TDSConditional then
        InterpretConditional(TDSConditional(DS))
      else
      if DS is TDSHelperVariable then
        ProcessHelperVar(TDSHelperVariable(DS))
      else
      if DS is TDSScriptBlock then
        ProcessScriptBlock(TDSScriptBlock(DS))
      else
      if DS is TDSDirective then
        ProcessDirective(TDSDirective(DS))
      else
        raise EParserError.Create('Invalid class of field '+DS.Name);
  //    WriteLogF('Struct_Intepret', AnsiString(DS.ClassName+' '+DS.Name+' = '+DS.ToString));
    except
      on E: Exception do
      begin
        if not E.Message.StartsWith('Line #') then
          E.Message := 'Line #' + IntToStr(DS.DescrLineNum) + ', Addr ' + IntToStr(DS.BufAddr) + ':' + sLineBreak + E.Message;
        DS.ErrorText := E.Message;
        raise;
      end;
    end;
  finally
    DS.BufSize := FCurAddr - DS.BufAddr;
    Inc(FieldsProcessed);
  end;

  if DS is TDSSimpleField then
    ValidateField(TDSSimpleField(DS));

  with DS.EventSet do
    OnInterpreted.Call(DataContext, DS);
end;

procedure TDSInterpretor.Interpret(DS: TDSField; Addr, MaxSize: TFilePointer);
begin
  FStartAddr := Addr;
  FMaxSize := MaxSize;
  FCurAddr := Addr;
  EndOfData := (MaxSize = 0);
  ActiveBreakStatement := bsNone;
  FieldsProcessed := 0;
//  WriteLogF('Struct_Intepret', 'Start');
  Progress.TaskStart(Self);
  try
    InternalInterpret(DS);
  finally
    Progress.TaskEnd();
  end;
end;

procedure TDSInterpretor.InterpretArray(DS: TDSArray);
var
  Count: Integer;
  i: Integer;
  Element: TDSField;
  ElementSize: TFilePointer;
  BufferLeft: TFilePointer;
  NeedsValidation: Boolean;
begin
  ElementSize := DS.ElementType.GetFixedSize();
  // Calculate element count
  if Trim(DS.ACount) = '' then  // Till end of buffer
  begin
    BufferLeft := (FStartAddr + FMaxSize - FCurAddr);
    if ElementSize < 0 then  // Cannot pre-calculate array size with variable-sized elements
      Count := -1
    else
    if BufferLeft = 0 then
      Count := 0
    else
    begin
      if ElementSize = 0 then
        raise EDSParserError.CreateFmt('Array of zero-length elements cannot have size %d', [BufferLeft]);
      if (BufferLeft mod ElementSize) <> 0 then
        raise EDSParserError.CreateFmt('Buffer size (%d) is not a multiplier of element size (%d)', [BufferLeft, ElementSize]);
      Count := BufferLeft div ElementSize;
    end;
  end
  else
    Count := TDSExprEvaluator.Eval(DS.ACount, DS, Self);

  DS.FFields.Clear();

  // This field or some of its childs has "#valid" directive
  NeedsValidation := ((DS.ElementType is TDSSimpleField) and (TDSSimpleField(DS.ElementType).ValidationStr <> '')) or
                     ((DS.ElementType is TDSCompoundField) and (TDSCompoundField(DS.ElementType).ChildsWithValidations > 0));

  if (ElementSize >= 0) and (Count >= 0) and (not NeedsValidation) then
  begin
    // If we know element size and array length, we can optimize loading by deferring
    // actual element creation until they are used by someone
    DS.FRealCount := Count;

    Seek(FCurAddr + Count * ElementSize);
  end
  else
  begin
    DS.FRealCount := -1;
    i := 0;
    if Count > 0 then
      DS.FFields.Capacity := Count;
    while True do
    begin
      if Count >= 0 then
      begin
        if (i >= Count) then Break;
      end
      else
      begin
        // If empty count specified "[]", parse this array until end of buffer
        if EndOfData then Break;
      end;
      Element := DS.ElementType.Duplicate();
      DS.FCurParsedItem := DS.AddField(Element);
      InternalInterpret(Element);
      Inc(i);
      // We encountered "break" command?
      if ActiveBreakStatement = bsBreak then
      begin
        ActiveBreakStatement := bsNone;
        Break;
      end;
      if ActiveBreakStatement = bsContinue then
      begin
        ActiveBreakStatement := bsNone;
        Continue;
      end;
    end;
  end;
end;

procedure TDSInterpretor.InterpretConditional(DS: TDSConditional);
// Conditional statement like "if" or "switch"
var
  ExprValue: Variant;
  AFields: TArrayOfDSField;
  AField: TDSField;
  i: Integer;
begin
  // Calculate condition
  ExprValue := TDSExprEvaluator.Eval(DS.ACondition, DS, Self);

  AFields := nil;
  // Find fields corresponding to condition value
  AFields := DS.GetFieldsByKey(ExprValue);
  if AFields = nil then
    // If no branch for that value, find "default" branch
    AFields := DS.GetFieldsByKey(DSDefaultCaseVariant);

  if AFields <> nil then
  begin
    for i:=0 to Length(AFields)-1 do
    begin
      AField := AFields[i].Duplicate();
      DS.FCurParsedItem := DS.AddField(AField);
      InternalInterpret(AField);
    end;
  end;
end;

procedure TDSInterpretor.InterpretStruct(DS: TDSStruct);
var
  i: Integer;
begin
  for i:=0 to DS.FieldsCount-1 do
  begin
    DS.FCurParsedItem := i;
    InternalInterpret(DS.Fields[i]);
    // On "break"/"continue" statement, skip the rest of structure
    if ActiveBreakStatement <> bsNone then Break;
  end;
end;

procedure TDSInterpretor.ProcessDirective(DS: TDSDirective);
var
  Addr, Align: TFilePointer;
  Field: TDSField;
begin
  if SameName(DS.Name, 'addr') then
  // Jump to absolute address in file
  begin
    Addr := TDSExprEvaluator.Eval(DS.Value, DS, Self);
    Seek(Addr);
    DS.BufAddr := Addr;
    // If #addr directive is a first field of a structure, adjust starting address
    // of entire structure (and it's parent, recursively) - do not leave 
    // a "gap" in the beginning of structure
    Field := DS;
    while (Field.Parent <> nil) and (Field.Parent.Fields[0] = Field) do
    begin
      Field.Parent.BufAddr := Addr;
      Field := Field.Parent;
    end;
    Exit;
  end;

  if SameName(DS.Name, 'align_pos') then
  // Align next field to specified boundary relative to parent structure start
  begin
    Align := TDSExprEvaluator.Eval(DS.Value, DS, Self);
    if DS.Parent <> nil then
      Addr := DS.Parent.BufAddr
    else
      Addr := 0;
    Addr := NextAlignBoundary(Addr, DS.BufAddr, Align);
    Seek(Addr);
    DS.BufAddr := Addr;
    Exit;
  end;

  if SameName(DS.Name, 'break') or SameName(DS.Name, 'continue') then
  // Break out of innermost array declaration
  begin
    if SameName(DS.Name, 'break') then
      ActiveBreakStatement := bsBreak
    else
      ActiveBreakStatement := bsContinue;
    Exit;
  end;

end;

procedure TDSInterpretor.ProcessHelperVar(DS: TDSHelperVariable);
var
  Value: Variant;
begin
  Value := TDSExprEvaluator.Eval(DS.Value, DS, Self);
  DS.Parent.SetHelperVar(DS.Name, Value);
end;

procedure TDSInterpretor.ProcessScriptBlock(DS: TDSScriptBlock);
begin
  TDSExprEvaluator.Eval(DS.Value, DS, Self, False);
end;

procedure TDSInterpretor.Seek(Addr: TFilePointer);
begin
  if Addr > FStartAddr + FMaxSize then
    raise EDSParserError.Create('End of buffer');
  FCurAddr := Addr;
  EndOfData := (FCurAddr = FStartAddr + FMaxSize);
end;

procedure TDSInterpretor.ValidateField(DS: TDSSimpleField);
// Check field value against "#valid" directive and set DS.ErrorText
var
  V: string;
  Value: Variant;
  ValidRanges: TVariantRanges;
begin
  // Parse field validation str to list of ranges
  V := DS.ValidationStr;
  if V = '' then Exit;
  ValidRanges := StrToVariantRanges(V);

  // Field value
  Value := DS.ToVariant();

  if not ValidRanges.Contains(Value) then
    DS.ErrorText := 'Value out of range';
end;

procedure TDSInterpretor.InterpretSimple(DS: TDSSimpleField);
var
  Size, Align: Integer;
  AlignBoundary: TFilePointer;
begin
  Size := GetFieldSize(DS);
  // Apply field alignment
  if (DS.Parent <> nil) then
  begin
    Align := DS.Parent.GetFieldAlign();
    if (Align > 1) then
    begin
      AlignBoundary := NextAlignBoundary(DS.Parent.BufAddr, FCurAddr, Align);
      if (FCurAddr < AlignBoundary) and (FCurAddr + Size > AlignBoundary) then
      begin
        Seek(AlignBoundary);
        DS.BufAddr := AlignBoundary;
      end;
    end;
  end;
  Seek(FCurAddr + Size);

end;

{ TDSComWrapper }

function TDSComWrapper.GetIDsOfNames(const IID: TGUID; Names: Pointer;
  NameCount, LocaleID: Integer; DispIDs: Pointer): HRESULT;
type
  PNames = ^TNames;
  TNames = array[0..100] of POleStr;
  PDispIDs = ^TDispIDs;
  TDispIDs = array[0..100] of Integer;
var
  i: Integer;
  AName: string;
  Child: TDSField;
begin
  AName := PNames(Names)^[0];
  if DSField is TDSArray then
  begin
    if SameText('index', AName) then
    // ArrayName.index = current index in array
    begin
      PInteger(DispIDs)^ := DISPID_INDEX;
      Exit(S_OK);
    end;
    if SameText('length', AName) then
    // ArrayName.length = length of array
    begin
      PInteger(DispIDs)^ := DISPID_LENGTH;
      Exit(S_OK);
    end;
    if (TryStrToInt(AName, i)) and (i >= 0) and (i < (DSField as TDSArray).FieldsCount) then
    begin
      PInteger(DispIDs)^ := i;
      Exit(S_OK);
    end;
  end;
  if DSField is TDSCompoundField then
    with (DSField as TDSCompoundField) do
    begin
      // Parsed fields
      i := 0;
      for Child in NamedFields do
      begin
        if SameText(Child.Name, AName) then
        begin
          PInteger(DispIDs)^ := i;
          Exit(S_OK);
        end;
        Inc(i);
      end;
      // Helper variables
      i := FindHelperVar(AName);
      if i >= 0 then
      begin
        PInteger(DispIDs)^ := DISPID_HELPERVARS_FIRST + i;
        Exit(S_OK);
      end;
    end;
  Result := DISP_E_UNKNOWNNAME;
end;

function TDSComWrapper.GetTypeInfo(Index, LocaleID: Integer;
  out TypeInfo): HRESULT;
begin
  Result := E_NOTIMPL;
end;

function TDSComWrapper.GetTypeInfoCount(out Count: Integer): HRESULT;
begin
  Result := E_NOTIMPL;
end;

function TDSComWrapper.GetWrappedField: TDSField;
begin
  Result := DSField;
end;

function TDSComWrapper.Invoke(DispID: Integer; const IID: TGUID;
  LocaleID: Integer; Flags: Word; var Params; VarResult, ExcepInfo,
  ArgErr: Pointer): HRESULT;
var
  Field: TDSField;
  SimpleField: TDSSimpleField;
  CompoundField: TDSCompoundField;
  LoggedName{, LoggedValue}: string;
  Put: Boolean;
  V: Variant;
  N: Integer;
begin
  Result := DISP_E_MEMBERNOTFOUND;
  // Must be a compound field
  if not (DSField is TDSCompoundField) then
    Exit(DISP_E_MEMBERNOTFOUND);
  CompoundField := TDSCompoundField(DSField);
  // No methods here
  if ((Flags and DISPATCH_METHOD) <> 0) then
    Exit(DISP_E_MEMBERNOTFOUND);

  Put := ((Flags and (DISPATCH_PROPERTYPUT or DISPATCH_PROPERTYPUTREF)) <> 0);

//  LoggedValue := '';
  try
    // "index" pseudo-field = current index in array
    if DispID = DISPID_INDEX then
    begin
      if not (DSField is TDSArray) then
        Exit(DISP_E_MEMBERNOTFOUND);
      if Put then
        Exit(DISP_E_BADVARTYPE);
      LoggedName := 'index';
      POleVariant(VarResult)^ := (DSField as TDSArray).FCurParsedItem;
      Exit(S_OK);
    end;
    // "length" pseudo-field = length of array
    if DispID = DISPID_LENGTH then
    begin
      if not (DSField is TDSArray) then
        Exit(DISP_E_MEMBERNOTFOUND);
      LoggedName := 'length';
      if Put then
        (DSField as TDSArray).SetLength(Variant(TDispParams(Params).rgvarg[0]))
      else
        POleVariant(VarResult)^ := (DSField as TDSArray).FieldsCount;
      Exit(S_OK);
    end;

    // Helper variables
    if DispID >= DISPID_HELPERVARS_FIRST then
    begin
      N := DispID - DISPID_HELPERVARS_FIRST;
      if Put then
        CompoundField.FHelperVars[N] := TPair<string, Variant>.Create(
          CompoundField.FHelperVars[N].Key, Variant(TDispParams(Params).rgvarg[0]))
      else
        POleVariant(VarResult)^ := CompoundField.FHelperVars[N].Value;
      Exit(S_OK);
    end;

    // Unknown DispID
    if (DispID < 0) then
      Exit(DISP_E_MEMBERNOTFOUND);

    Result := S_OK;
    Field := (DSField as TDSCompoundField).NamedFieldByIndex(DispID);
    if Field = nil then
      Exit(DISP_E_MEMBERNOTFOUND);
    LoggedName := Field.FullName();

    if Field is TDSCompoundField then
    // For compound field - return wrapper object
    begin
      if Put then
        Exit(DISP_E_BADVARTYPE);
      POleVariant(VarResult)^ := (Field as TDSCompoundField).GetComWrapper() as IDispatch;
//      LoggedValue := Field.ToString();
    end
    else
    if Field is TDSSimpleField then
    // For simple field - return or change value
    begin
      SimpleField := TDSSimpleField(Field);
      if Put then
      begin
        // Assign new value and update source data
        V := Variant(TDispParams(Params).rgvarg[0]);
        SimpleField.SetFromVariant(V);
      end
      else
        // Return current value
        POleVariant(VarResult)^ := (Field as TDSSimpleField).ToVariant();
    end
    else
      Result := DISP_E_BADVARTYPE;
  finally
    if (Result = S_OK) and (not Put) then
    begin
//      if LoggedValue = '' then
//        LoggedValue := string(POleVariant(VarResult)^);
//      WriteLogF('Struct_Intepret', LoggedName + ' = ' + LoggedValue);
    end;
  end;
end;

{ TDSDirective }

procedure TDSDirective.Assign(Source: TDSField);
begin
  inherited;
  if Source is TDSDirective then
  begin
    Value := TDSDirective(Source).Value;
  end;
end;

function TDSDirective.GetFixedSize: TFilePointer;
// For now, assume that any persistent directive inside structure makes its size not-fixed
begin
  Result := -1;
end;

{ TDSCompoundField.TNamedFieldsEnumerator }

constructor TDSCompoundField.TNamedFieldsEnumerator.Create(
  TopLevelField: TDSCompoundField);
begin
  inherited Create();
  FTopLevel := TopLevelField;
  if FTopLevel.FieldsCount = 0 then
  begin
    FCurrentParent := nil;
    Exit;
  end;
  FCurrentParent := FTopLevel;
  FIndex := -1;
  FIndices := TStack<Integer>.Create();
end;

destructor TDSCompoundField.TNamedFieldsEnumerator.Destroy;
begin
  FIndices.Free;
  inherited;
end;

function TDSCompoundField.TNamedFieldsEnumerator.DoGetCurrent: TDSField;
begin
  Result := FCurrentParent.Fields[FIndex];
end;

function TDSCompoundField.TNamedFieldsEnumerator.DoMoveNext: Boolean;
var
  FItem: TDSField;
begin
  if FCurrentParent = nil then Exit(False);
  // Move to next sibling
  Inc(FIndex);
  // Skip unnamed fields
  repeat
    if FIndex >= FCurrentParent.FieldsCount then
    // No more fields in current parent
    begin
      if FCurrentParent = FTopLevel then
      // This was originally requested parent field - enumetation finished
      begin
        FCurrentParent := nil;
        Exit(False);
      end
      else
      // Go one level up
      begin
        FCurrentParent := FCurrentParent.Parent;
        if FCurrentParent = nil then
          raise Exception.Create('Something went wrong in NamedFields');
        FIndex := FIndices.Pop();
        Inc(FIndex);
      end;
    end
    else
    begin
      FItem := FCurrentParent.Fields[FIndex];
      if (FItem.Name = '') and (FItem is TDSCompoundField) then
      // Found unnamed structure - step into it
      begin
        FCurrentParent := FItem as TDSCompoundField;
        FIndices.Push(FIndex);
        FIndex := 0;
      end
      else
      if (FItem.Name <> '') and ((FItem is TDSSimpleField) or (FItem is TDSCompoundField)) then
      // Found named field - return it.
        Exit(True)
      else
      // Directives etc.
        Inc(FIndex);
    end;
  until False;
end;

{ TDSCompoundField.TNamedFieldsEnumerable }

constructor TDSCompoundField.TNamedFieldsEnumerable.Create(
  TopLevelField: TDSCompoundField);
begin
  inherited Create();
  FTopLevel := TopLevelField;
end;

function TDSCompoundField.TNamedFieldsEnumerable.GetEnumerator: TNamedFieldsEnumerator;
begin
  Result := TNamedFieldsEnumerator.Create(FTopLevel);
end;

{ TDSExprEvaluator }

constructor TDSExprEvaluator.Create;
begin
  inherited;
  ScriptEngine := TActiveScript.Create(nil);
end;

destructor TDSExprEvaluator.Destroy;
begin
  ScriptEngine.Free;
  inherited;
end;

function TDSExprEvaluator.Evaluate(Expr: string; CurField: TDSField; DSInterpretor: TDSInterpretor;
  RequireResult: Boolean = True): Variant;
begin
//  WriteLogF('Struct_Intepret', 'Expression: ' + Expr);
  try
    Expr := Trim(Expr);

    if TryEvalConst(Expr, Result) then
      Exit;

    PrepareScriptEnv(CurField, DSInterpretor);
    Result := ScriptEngine.Eval(Expr);

    if (RequireResult) and (VarIsEmpty(Result)) then
      raise EDSParserError.Create('Cannot calculate expression: "'+Expr+'"');

  finally
//    WriteLogF('Struct_Intepret', 'Result: ' + string(Result));
  end;
end;

class function TDSExprEvaluator.Eval(Expr: string; CurField: TDSField; DSInterpretor: TDSInterpretor;
  RequireResult: Boolean = True): Variant;
begin
  // Make sure evaluator instance created and use it to calculate expression
  ForceEvaluator();
  Result := FDSExprEvaluator.Evaluate(Expr, CurField, DSInterpretor, RequireResult);
end;

class procedure TDSExprEvaluator.ForceEvaluator;
// Create evaluator instance
begin
  if FDSExprEvaluator = nil then
    FDSExprEvaluator := TDSExprEvaluator.Create();
end;

procedure TDSExprEvaluator.PrepareScriptEnv(CurField: TDSField; DSInterpretor: TDSInterpretor);
// Populate ScriptEngine with already parsed fields to use them in expressions.
// Innermost have higher precedence.
var
  DS: TDSField;
begin
  ScriptEngine.Reset();
  // Additional functions provided by environment
  if CurField <> nil then
    CurField.EventSet.OnPrepareScriptEnv.Call(CurField.EventSet.DataContext, CurField, ScriptEngine);
  if DSInterpretor <> nil then
    ScriptEngine.AddObject('interpretor', DSInterpretor.APIEnv.GetAPIWrapper(DSInterpretor), True);
  DS := CurField;
  while DS <> nil do
  begin
    if DS is TDSCompoundField then
      ScriptEngine.AddObject({DS.Name}'f' + IntToHex(UIntPtr(DS)), (DS as TDSCompoundField).GetComWrapper(), True);
    DS := DS.Parent;
  end;
end;

//{ TDSTypedef }
//
//procedure TDSTypedef.Assign(Source: TDSField);
//var
//  i: Integer;
//begin
//  inherited;
//  if Source is TDSTypedef then
//  begin
//    ATypes.Clear();
//    for i := 0 to TDSTypedef(Source).ATypes.Count - 1 do
//    begin
//      ATypes.Add( TDSTypedef(Source).ATypes[i].Duplicate() );
//    end;
//  end;
//end;
//
//constructor TDSTypedef.Create;
//begin
//  inherited;
//  ATypes := TObjectList<TDSField>.Create(True);
//end;
//
//destructor TDSTypedef.Destroy;
//begin
//  ATypes.Free;
//  inherited;
//end;
//
//function TDSTypedef.GetFixedSize: TFilePointer;
//begin
//  // Typedef statement itself does not corresponds to bytes in file
//  Result := 0;
//end;

initialization

finalization
  FreeAndNil(FDSExprEvaluator);
end.
