unit uTask;

interface

uses
  ShareMem, System.Classes, System.Types, System.Generics.Collections,
  System.SysUtils, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Forms;

type
  // ������� ����� ������ (��� ����� ������� �� DLL).
  TTask = class
  private
    fID: Word;
    fNameDLL: string;
    fNameTask: String;

    fProgressBar: TProgressBar;

  protected
    procedure SetNameDLL(vNameDLL: string);
    procedure SetNameTask(vNameTask: string);
    procedure SetProgressBar(vProgressBar: TProgressBar);

  public
    ResultLog: TStringList;

  public
    constructor Create(vID: Word; vNameDLL, vNameTask: string;
      vProgressBar: TProgressBar);
    destructor Destroy; override;

    procedure SaveLogToMemo(Memo: TMemo);
    procedure SaveLogToFile(FolderPath: string);

    procedure SaveResultToMemo(Memo: TMemo); virtual; abstract;

  public
    property ID: Word read fID write fID;
    property NameDLL: string read fNameDLL write SetNameDLL;
    property NameTask: string read fNameTask write SetNameTask;

    property ProgressBar: TProgressBar read fProgressBar write SetProgressBar;
  end;

  // ����� ������ ��� ������� SearchFiles �� DLL1
  TTaskSearchFiles = class(TTask)
  public
    SourcePath, MaskFiles: String;
    ResultInt: integer;
    ResultStringList: TStringList;

  public
    constructor Create(vID: Word; vNameDLL, vNameTask: string;
      vProgressBar: TProgressBar);
    destructor Destroy; override;

    procedure SaveResultToMemo(Memo: TMemo); override;
  end;

  // ����� ������ ��� ������� SearchSequence �� DLL1
  TTaskSearchSequence = class(TTask)
  public
    SourceFile, Sequence: string;
    ResultInt: integer;
    ResultDictionary: TDictionary<String, String>;

  public
    constructor Create(vID: Word; vNameDLL, vNameTask: string;
      vProgressBar: TProgressBar);
    destructor Destroy; override;

    procedure SaveResultToMemo(Memo: TMemo); override;
  end;

  // ����� ������ ��� ������� ProcessCli �� DLL2
  TTaskProcessCli = class(TTask)
  public
    SourcePath: string;
    ResultInt: integer;
    ResultString: string;

  public
    procedure SaveResultToMemo(Memo: TMemo); override;
  end;

implementation

// -----------------------------TTask---------------------------------------

// ����������� ��� TTask
constructor TTask.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  fID := vID;
  fNameDLL := vNameDLL;
  fNameTask := vNameTask;

  fProgressBar := vProgressBar;

  ResultLog := TStringList.Create;
end;

// ���������� ��� TTask
destructor TTask.Destroy;
begin
  ResultLog.Free;

  inherited;
end;

// ������ ��� �������� NameDLL
procedure TTask.SetNameDLL(vNameDLL: string);
begin
  fNameDLL := vNameDLL;
end;

// ������ ��� �������� NameTask
procedure TTask.SetNameTask(vNameTask: string);
begin
  fNameTask := vNameTask;
end;

// ������ ��� �������� ProgressBar
procedure TTask.SetProgressBar(vProgressBar: TProgressBar);
begin
  fProgressBar := vProgressBar;
end;

// ���������� ����� ���������� ������ � Memo
procedure TTask.SaveLogToMemo(Memo: TMemo);
var
  S: string;
begin
  Memo.Lines.Clear;

  for S in ResultLog do
  begin
    Memo.Lines.Add(S);
    Application.ProcessMessages;
  end;
end;

// ���������� ����� ���������� ������ � ����
procedure TTask.SaveLogToFile(FolderPath: string);
begin
  ResultLog.SaveToFile(FolderPath + '\' + NameTask + '_Log.txt');
end;

// --------------------------TTaskSearchFiles----------------------------------

// ����������� ��� TTaskSearchFiles
constructor TTaskSearchFiles.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  inherited Create(vID, vNameDLL, vNameTask, vProgressBar);

  ResultStringList := TStringList.Create;
end;

// ���������� ��� TTaskSearchFiles
destructor TTaskSearchFiles.Destroy;
begin
  ResultStringList.Free;

  inherited;
end;

// ���������� ����������� ���������� ������� SearchFiles � Memo
procedure TTaskSearchFiles.SaveResultToMemo(Memo: TMemo);
var
  S: string;
begin
  Memo.Lines.Clear;

  for S in ResultStringList do
  begin
    Memo.Lines.Add(S);
    Application.ProcessMessages;
  end;
  Memo.Lines.Add('���������� ��������� ������: ' + ResultInt.ToString);
end;

// --------------------------TTaskSearchSequence-------------------------------

// ����������� ��� TTaskSearchSequence
constructor TTaskSearchSequence.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  inherited Create(vID, vNameDLL, vNameTask, vProgressBar);

  ResultDictionary := TDictionary<String, String>.Create;
end;

// ���������� ��� TTaskSearchSequence
destructor TTaskSearchSequence.Destroy;
begin
  ResultDictionary.Free;

  inherited;
end;

// ���������� ����������� ���������� ������� SearchSequence � Memo
procedure TTaskSearchSequence.SaveResultToMemo(Memo: TMemo);
var
  Key: string;
begin
  Memo.Lines.Clear;

  Memo.Lines.Add('���������� ��������� ���������: ' + ResultInt.ToString);
  for Key in ResultDictionary.Keys do
    Memo.Lines.Add(Key + ':' + ResultDictionary.Items[Key]);
end;

// ----------------------------TTaskProcessCli---------------------------------

// ���������� ����������� ���������� ������� ProcessCli � Memo
procedure TTaskProcessCli.SaveResultToMemo(Memo: TMemo);
begin
  Memo.Lines.Clear;

  if ResultString <> '' then
  begin
    Memo.Lines.Add('��� ����������: ' + ResultInt.ToString);
    Memo.Lines.Add(ResultString);
  end;
end;

end.
