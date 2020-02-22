unit uScriptFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.Buttons,
  Vcl.StdCtrls, Vcl.OleCtrls, MSScriptControl_TLB, Vcl.ComCtrls,

  uUtil, SynEdit;

type
  TScriptFrame = class(TFrame)
    ToolPanel: TPanel;
    BtnRun: TSpeedButton;
    ScriptControl1: TScriptControl;
    Timer1: TTimer;
    Splitter1: TSplitter;
    OutputPanel: TPanel;
    MemoOutput: TRichEdit;
    OutputToolPanel: TPanel;
    BtnClearOutput: TSpeedButton;
    ScriptEdit: TSynEdit;
    procedure BtnRunClick(Sender: TObject);
    procedure BtnClearOutputClick(Sender: TObject);
  private
    { Private declarations }
    procedure PrepareScriptEnv();
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
    procedure Init();
    procedure Uninit();
  end;

implementation

uses
  uMainForm, uDataStruct;

{$R *.dfm}

procedure TScriptFrame.BtnRunClick(Sender: TObject);
var
  AText: string;
  Res: OleVariant;
begin
  AText := ScriptEdit.Text;

  AppSettings.Script.Text := AText;
  MainForm.SaveSettings();

  PrepareScriptEnv();

  Res := ScriptControl1.Eval(AText);  // <--

  MemoOutput.Lines.Add(Res);
  ShowMemoCaret(MemoOutput, True);
end;

constructor TScriptFrame.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TScriptFrame.Destroy;
begin
  inherited;
end;

procedure TScriptFrame.Init;
begin
  ScriptEdit.Text := AppSettings.Script.Text;
end;

procedure TScriptFrame.PrepareScriptEnv;
begin
  ScriptControl1.Reset();
  // Main application object
  ScriptControl1.AddObject('app', MainForm.APIEnv.GetAPIWrapper(MainForm), True);
  // Utility functions
  ScriptControl1.AddObject('utils', MainForm.APIEnv.GetAPIWrapper(MainForm.Utils), True);
  // Parsed structure from StructFrame
  if (MainForm.StructFrame.ShownDS <> nil) and
     (MainForm.StructFrame.ShownDS is TDSCompoundField) then
  ScriptControl1.AddObject('ds', (MainForm.StructFrame.ShownDS as TDSCompoundField).GetComWrapper(), False);
end;

procedure TScriptFrame.BtnClearOutputClick(Sender: TObject);
begin
  MemoOutput.Lines.Clear();
end;

procedure TScriptFrame.Uninit;
begin
  AppSettings.Script.Text := ScriptEdit.Text;
end;

end.
