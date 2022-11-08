{                          ---BEGIN LICENSE BLOCK---                           }
{                                                                              }
{ Hextor - Hexadecimal editor and binary data analyzing toolkit                }
{ Copyright (C) 2019-2022  Grigoriy Mylnikov (DigitalWolF) <info@hextor.net>   }
{ Hextor is a Freeware Source-Available software. See LICENSE.txt for details  }
{                                                                              }
{                           ---END LICENSE BLOCK---                            }

unit uSearchResultsTabFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, VirtualTrees, Vcl.ComCtrls,
  System.Math, System.UITypes, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Clipbrd, Vcl.Menus,
  System.StrUtils,

  uEditorForm, uHextorTypes, uHextorDataSources, uEditedData, uHextorGUI;

type
  TSearchResultsTabFrame = class(TFrame)
    ResultsList: TVirtualStringTree;
    Panel1: TPanel;
    LblFoundCount: TLabel;
    ResultsListPopupMenu: TPopupMenu;
    Expandall1: TMenuItem;
    Collapseall1: TMenuItem;
    N1: TMenuItem;
    Copyfilenames1: TMenuItem;
    Copyfounditems1: TMenuItem;
    AsHex1: TMenuItem;
    AsText1: TMenuItem;
    Copyfilenamescount1: TMenuItem;
    procedure ResultsListGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure ResultsListFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure ResultsListNodeDblClick(Sender: TBaseVirtualTree;
      const HitInfo: THitInfo);
    procedure ResultsListDrawText(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
    procedure Expandall1Click(Sender: TObject);
    procedure Collapseall1Click(Sender: TObject);
    procedure Copyfilenames1Click(Sender: TObject);
    procedure AsHex1Click(Sender: TObject);
  private type
    TDisplayedNeedle = array[0..2] of string;  // Text[1] is highlighted needle, Text[0] and Text[2] is short context before and after
    // Data for result list node (both "File name" nodes and "item" leaf nodes)
    TResultTreeNode = record
      DisplayFileName: string;                // Used in root nodes
      FEditor: TEditorForm;                   // Used if "Find in current editor / in open files"
      DataSourceType: THextorDataSourceType;  // Used to re-open file in editor if it's closed now
      DataSourcePath: string;                 //
      Range: TFileRange;
      DisplayHex, DisplayText: TDisplayedNeedle;
    end;
    PResultTreeNode = ^TResultTreeNode;
  private
    { Private declarations }
    FEditor: TEditorForm;  // Not nil if searching in current editor. Nil if searching in multiple files
    procedure EditorClosed(Sender: TEditorForm);
    procedure EditorGetTaggedRegions(Editor: TEditorForm; Start: TFilePointer;
      AEnd: TFilePointer; AData: PByteArray; Regions: TTaggedDataRegionList);
    procedure DataChanged(Sender: TEditedData; Addr: TFilePointer; OldSize, NewSize: TFilePointer; Value: PByteArray);
    procedure LinkNodeToEditor(Node: PVirtualNode; AEditor: TEditorForm);
    procedure UnlinkFromEditor(AEditor: TEditorForm);
    function GetEditorNode(AEditor: TEditorForm): PVirtualNode;
    function GetNodeForData(AData: TEditedData): PVirtualNode;
    function IsGroupNode(Node: PVirtualNode): Boolean;
    procedure AppendItemText(Node: PVirtualNode; sb: TStringBuilder; Sender: TObject);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
    procedure StartList(AEditor: TEditorForm; const ASearchText: string);
    function AddListGroup(AEditor: TEditorForm; AData: TEditedData): Pointer; overload;
    function AddListGroup(AEditor: TEditorForm; const ADisplayName: string;
      ADataSourceType: THextorDataSourceType; ADataSourcePath: string): Pointer; overload;
    procedure AddListItem(AGroupNode: Pointer; AData: TEditedData; const ARange: TFileRange; CodePage: Integer);
    procedure DeleteListGroup(AGroupNode: Pointer);
    procedure EndUpdateList();
    function GetLinkedEditors: TArray<TEditorForm>;
  end;

implementation

uses
  uMainForm;

{$R *.dfm}

function TSearchResultsTabFrame.AddListGroup(AEditor: TEditorForm;
  AData: TEditedData): Pointer;
// Add node group (corresponding to file) and return pointer that can be used later
// to call AddListItem().
// This node keeps pointer to AEditor (as long as this editor is open).
// AEditor can be nil if this is a find-in-files.
// Node does not keeps pointer to AData (during find-in-files, AData can be freed right
// after processing a file). Instead, a path to DataSource is kept to
// open corresponding file when double-clicking on result item.
begin
  Result := AddListGroup(AEditor, AData.DataSource.DisplayName,
    THextorDataSourceType(AData.DataSource.ClassType), AData.DataSource.Path);
end;

function TSearchResultsTabFrame.AddListGroup(AEditor: TEditorForm;
  const ADisplayName: string; ADataSourceType: THextorDataSourceType;
  ADataSourcePath: string): Pointer;
var
  Node: PVirtualNode;
  RNode: PResultTreeNode;
begin
  Node := ResultsList.AddChild(nil);
  RNode := Node.GetData;

  RNode.DisplayFileName := ADisplayName;
  RNode.DataSourceType := ADataSourceType;
  RNode.DataSourcePath := ADataSourcePath;

  LinkNodeToEditor(Node, AEditor);

  Result := Node;
end;

procedure TSearchResultsTabFrame.AddListItem(AGroupNode: Pointer; AData: TEditedData;
  const ARange: TFileRange; CodePage: Integer);
// Add found item to list of search results
const
  ContextBytes = 8;
  MaxValueBytes = 1024;
var
  GroupNode, Node: PVirtualNode;
  RGroupNode, RNode: PResultTreeNode;
  DispRange: TFileRange;
  ABuf: TBytes;
begin
  GroupNode := PVirtualNode(AGroupNode);
  RGroupNode := GroupNode.GetData;
  Node := ResultsList.AddChild(GroupNode);
  RNode := Node.GetData;
  RNode.FEditor := RGroupNode.FEditor;
  RNode.DataSourceType := RGroupNode.DataSourceType;
  RNode.DataSourcePath := RGroupNode.DataSourcePath;
  RNode.Range := ARange;
  // Display some data before/after found item
  DispRange.Start := Max(ARange.Start - ContextBytes, 0);
  DispRange.AEnd := Min(ARange.AEnd + ContextBytes, AData.GetSize());
  ABuf := AData.Get(DispRange.Start, Min(DispRange.Size, MaxValueBytes));
  RNode.DisplayHex[0] := Data2Hex(Copy(ABuf, 0, ARange.Start-DispRange.Start));
  RNode.DisplayHex[1] := Data2Hex(Copy(ABuf, ARange.Start-DispRange.Start, ARange.Size));
  RNode.DisplayHex[2] := Data2Hex(Copy(ABuf, ARange.AEnd-DispRange.Start, MaxInt));
  RNode.DisplayText[0] := RemUnprintable(Data2String(Copy(ABuf, 0, ARange.Start-DispRange.Start), CodePage, True));
  RNode.DisplayText[1] := RemUnprintable(Data2String(Copy(ABuf, ARange.Start-DispRange.Start, ARange.Size), CodePage, True));
  RNode.DisplayText[2] := RemUnprintable(Data2String(Copy(ABuf, ARange.AEnd-DispRange.Start, MaxInt), CodePage, True));
end;

procedure TSearchResultsTabFrame.AppendItemText(Node: PVirtualNode;
  sb: TStringBuilder; Sender: TObject);
var
  RNode: PResultTreeNode;
  s: string;
begin
  RNode := Node.GetData();
  if RNode <> nil then
  begin
    if Sender = AsHex1 then
      s := RNode.DisplayHex[1]
    else
      s := RNode.DisplayText[1];
    sb.Append(s + sLineBreak);
  end;
end;

procedure TSearchResultsTabFrame.AsHex1Click(Sender: TObject);
// Copy selected found items to clipboard.
var
  Node, Child: PVirtualNode;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create();
  try
    for Node in ResultsList.SelectedNodes() do
    begin
      if IsGroupNode(Node) then
      begin
        for Child in ResultsList.ChildNodes(Node) do
          AppendItemText(Child, sb, Sender);
      end
      else
        if not (vsSelected in Node.Parent.States) then
          AppendItemText(Node, sb, Sender);
    end;

    Clipboard.AsText := StrToClipboard(sb.ToString());
  finally
    sb.Free;
  end;
end;

procedure TSearchResultsTabFrame.Collapseall1Click(Sender: TObject);
begin
  ResultsList.FullCollapse();
end;

procedure TSearchResultsTabFrame.Copyfilenames1Click(Sender: TObject);
// Copy selected nodes file names to clipboard.
// Root nodes should be selected, not leaf nodes with individual items
var
  Node: PVirtualNode;
  RNode: PResultTreeNode;
  s: string;
begin
  s := '';
  for Node in ResultsList.SelectedNodes() do
    if IsGroupNode(Node) then
    begin
      RNode := Node.GetData();
      if RNode <> nil then
      begin
        s := s + RNode.DisplayFileName;
        if Sender = Copyfilenamescount1 then
          s := s + #9 + IntToStr(Node.ChildCount);
        s := s + sLineBreak;
      end;
    end;
  Clipboard.AsText := StrToClipboard(s);
end;

constructor TSearchResultsTabFrame.Create(AOwner: TComponent);
begin
  inherited;
  ResultsList.NodeDataSize := SizeOf(TResultTreeNode);

end;

procedure TSearchResultsTabFrame.DataChanged(Sender: TEditedData; Addr, OldSize,
  NewSize: TFilePointer; Value: PByteArray);
var
  EditorNode, ItemNode: PVirtualNode;
begin
  // Adjust position of found items if file data changed (bytes inserted/removed)
  if NewSize = OldSize then Exit;
  EditorNode := GetNodeForData(Sender);
  if EditorNode <> nil then
  begin
    for ItemNode in ResultsList.ChildNodes(EditorNode) do
    begin
      AdjustPositionInData(PResultTreeNode(ItemNode.GetData()).Range, Addr, OldSize, NewSize);
    end;
  end;
end;

procedure TSearchResultsTabFrame.DeleteListGroup(AGroupNode: Pointer);
var
  AEditor: TEditorForm;
begin
  if AGroupNode <> nil then
  begin
    AEditor := PResultTreeNode(PVirtualNode(AGroupNode).GetData()).FEditor;
    ResultsList.DeleteNode(PVirtualNode(AGroupNode));
    if AEditor <> nil then
      UnlinkFromEditor(AEditor);
  end;
end;

destructor TSearchResultsTabFrame.Destroy;
var
  Editors: TArray<TEditorForm>;
  i: Integer;
begin
  Editors := GetLinkedEditors();
  for i:=0 to Length(Editors)-1 do
    UnlinkFromEditor(Editors[i]);
  inherited;
end;

procedure TSearchResultsTabFrame.EditorClosed(Sender: TEditorForm);
begin
  UnlinkFromEditor(Sender);
  // Close if this tab was opened exclusively for this editor.
  if Sender = FEditor then
    // DoAfterEvent?
    Parent.Free;
end;

procedure TSearchResultsTabFrame.EditorGetTaggedRegions(Editor: TEditorForm;
  Start, AEnd: TFilePointer; AData: PByteArray; Regions: TTaggedDataRegionList);
var
  GroupNode, Node: PVirtualNode;
  RNode: PResultTreeNode;
begin
  if not MainForm.ToolFrameVisible(Self) then Exit;

  GroupNode := GetEditorNode(Editor);
  if GroupNode <> nil then
    for Node in ResultsList.ChildNodes(GroupNode) do
    begin
      RNode := Node.GetData;
      Regions.AddRegion(Self, RNode.Range.Start, RNode.Range.AEnd, clNone, Color_FoundItemBg, Color_FoundItemFr);
    end;
end;

procedure TSearchResultsTabFrame.EndUpdateList;
// Called after search is complete
var
  AEditor: TEditorForm;
  FilesCount, ItemsCount: Integer;
begin
  ResultsList.EndUpdate();
  FilesCount := ResultsList.RootNodeCount;
  ItemsCount := ResultsList.TotalCount - ResultsList.RootNodeCount;
  LblFoundCount.Caption := IfThen(ItemsCount > 0, IntToStr(ItemsCount) + ' item(s) in ', '') +
                           IntToStr(FilesCount) + ' file(s)';

  for AEditor in GetLinkedEditors() do
    AEditor.UpdatePanes();
  if ResultsList.RootNodeCount = 1 then
    ResultsList.Expanded[ResultsList.RootNode.FirstChild] := True;
end;

procedure TSearchResultsTabFrame.Expandall1Click(Sender: TObject);
begin
  ResultsList.FullExpand();
end;

function TSearchResultsTabFrame.GetEditorNode(
  AEditor: TEditorForm): PVirtualNode;
// Find tree node corresponding to given editor
var
  Node: PVirtualNode;
  RNode: PResultTreeNode;
begin
  Result := nil;
  if AEditor = nil then Exit;
  for Node in ResultsList.ChildNodes(ResultsList.RootNode) do
  begin
    RNode := Node.GetData;
    if RNode.FEditor = AEditor then
      Exit(Node);
  end;
end;

function TSearchResultsTabFrame.GetLinkedEditors: TArray<TEditorForm>;
// Get list of editors for which we have results here
var
  Node: PVirtualNode;
  RNode: PResultTreeNode;
begin
  Result := nil;
  for Node in ResultsList.ChildNodes(ResultsList.RootNode) do
  begin
    RNode := Node.GetData;
    if RNode.FEditor <> nil then
      Result := Result + [RNode.FEditor];
  end;
end;

function TSearchResultsTabFrame.GetNodeForData(
  AData: TEditedData): PVirtualNode;
// Find tree node corresponding to given EditedData object.
// Works only if AData belongs to some editor which is linked to us.
var
  Node: PVirtualNode;
  RNode: PResultTreeNode;
begin
  Result := nil;
  if AData = nil then Exit;
  for Node in ResultsList.ChildNodes(ResultsList.RootNode) do
  begin
    RNode := Node.GetData;
    if (RNode.FEditor <> nil) and (RNode.FEditor.Data = AData) then
      Exit(Node);
  end;
end;

function TSearchResultsTabFrame.IsGroupNode(Node: PVirtualNode): Boolean;
// True if given node is for file. False if it is for found item.
begin
  Result := (Node.Parent = ResultsList.RootNode);
end;

procedure TSearchResultsTabFrame.LinkNodeToEditor(Node: PVirtualNode;
  AEditor: TEditorForm);
// Link result group node with given editor (used when searching in already open
// editor and when opening new editor on double-clicking result)
var
  GroupNode, ItemNode: PVirtualNode;
begin
  GroupNode := Node;
  if not IsGroupNode(GroupNode) then
    GroupNode := GroupNode.Parent;
  PResultTreeNode(GroupNode.GetData()).FEditor := AEditor;
  // When linking to new open editor on double-click, link child nodes too
  for ItemNode in ResultsList.ChildNodes(GroupNode) do
  begin
    PResultTreeNode(ItemNode.GetData()).FEditor := AEditor;
  end;
  if AEditor <> nil then
  begin
    AEditor.OnClosed.Add(EditorClosed, Self);
    AEditor.OnGetTaggedRegions.Add(EditorGetTaggedRegions, Self);
    AEditor.Data.OnDataChanged.Add(DataChanged, Self);
  end;
end;

procedure TSearchResultsTabFrame.ResultsListDrawText(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  const Text: string; const CellRect: TRect; var DefaultDraw: Boolean);
var
  S: ^TDisplayedNeedle;
  x: Integer;
begin
  if IsGroupNode(Node) then
  begin
    if not (vsSelected in Node.States) then
      TargetCanvas.Font.Color := ColorForCurrentTheme(clNavy);
    Exit;
  end;

  // Found data is shown with bold font, context before/after it with standard font
  case Column of
    1: S := @PResultTreeNode(Sender.GetNodeData(Node))^.DisplayHex;
    2: S := @PResultTreeNode(Sender.GetNodeData(Node))^.DisplayText;
    else Exit;
  end;
  x := CellRect.Left;
  TargetCanvas.Brush.Style := bsClear;
  TargetCanvas.Font.Style := TargetCanvas.Font.Style - [fsBold];
  TargetCanvas.TextRect(CellRect, x, 0, S[0]);
  x := x + TargetCanvas.TextWidth(S[0]);
  TargetCanvas.Font.Style := TargetCanvas.Font.Style + [fsBold];
  TargetCanvas.TextRect(CellRect, x, 0, S[1]);
  x := x + TargetCanvas.TextWidth(S[1]);
  TargetCanvas.Font.Style := TargetCanvas.Font.Style - [fsBold];
  TargetCanvas.TextRect(CellRect, x, 0, S[2]);
  DefaultDraw := False;
end;

procedure TSearchResultsTabFrame.ResultsListFreeNode(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
begin
  Finalize(PResultTreeNode(Sender.GetNodeData(Node))^);
end;

procedure TSearchResultsTabFrame.ResultsListGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: string);
var
  RNode: PResultTreeNode;
begin
  CellText := '';
  RNode := Sender.GetNodeData(Node);
  if Assigned(RNode) then
  begin
    if IsGroupNode(Node) then
    // Group node text (file name)
    begin
      if Column = 0 then
      begin
        CellText := RNode.DisplayFileName;
        if Node.ChildCount > 0 then
          CellText := CellText + '  (' + IntToStr(Node.ChildCount) + ')';
      end;
    end
    else
    // Found item text
    case Column of
      0: CellText := IntToHex(RNode.Range.Start, 8);
      1: CellText := RNode.DisplayHex[0] + RNode.DisplayHex[1] + RNode.DisplayHex[2];
      2: CellText := RNode.DisplayText[0] + RNode.DisplayText[1] + RNode.DisplayText[2];
    end;
  end;
end;

procedure TSearchResultsTabFrame.ResultsListNodeDblClick(
  Sender: TBaseVirtualTree; const HitInfo: THitInfo);
// On doubleclick: Switch to corresponding editor and select found data block
var
  RNode: PResultTreeNode;
  AEditor: TEditorForm;
begin
  if HitInfo.HitNode = nil then Exit;
  RNode := PResultTreeNode(ResultsList.GetNodeData(HitInfo.HitNode));
  if (RNode = nil) then Exit;

  if RNode.FEditor = nil then
  // This node is not linked with any editor
  begin
    // Find if this file is open in some editor
    AEditor := MainForm.FindEditorWithSource(RNode.DataSourceType, RNode.DataSourcePath);
    // Open file in editor if it is not open now
    if AEditor = nil then
      AEditor := MainForm.Open(RNode.DataSourceType, RNode.DataSourcePath);
    LinkNodeToEditor(HitInfo.HitNode, AEditor);
  end
  else
    AEditor := RNode.FEditor;

  MainForm.ActiveEditor := AEditor;
  AEditor.SelectAndShow(RNode.Range.Start, RNode.Range.AEnd);
end;

procedure TSearchResultsTabFrame.StartList(AEditor: TEditorForm;
  const ASearchText: string);
// Prepare list for filling with search results
var
  S: string;
begin
  FEditor := AEditor;
  S := ASearchText;
  if Length(S) > 20 then
    S := Copy(S, Low(S), 20) + '...';
  S := '"' + S + '"';
  if Parent is TTabSheet then
    TTabSheet(Parent).Caption := S;
  ResultsList.BeginUpdate();
  ResultsList.Clear();
end;

procedure TSearchResultsTabFrame.UnlinkFromEditor(AEditor: TEditorForm);
var
  EditorNode, ItemNode: PVirtualNode;
begin
  if AEditor = nil then Exit;
  // Cleanup all pointers to this editor in nodes
  EditorNode := GetEditorNode(AEditor);
  if EditorNode <> nil then
  begin
    PResultTreeNode(EditorNode.GetData()).FEditor := nil;
    for ItemNode in ResultsList.ChildNodes(EditorNode) do
    begin
      PResultTreeNode(ItemNode.GetData()).FEditor := nil;
    end;
  end;
  // Remove editor event handlers
  AEditor.OnClosed.Remove(Self);
  AEditor.OnGetTaggedRegions.Remove(Self);
  AEditor.Data.OnDataChanged.Remove(Self);
  AEditor.UpdatePanes();
end;

end.
