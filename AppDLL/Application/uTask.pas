unit uTask;

interface

uses
  ShareMem, System.Classes, System.Types, System.Generics.Collections,
  System.SysUtils, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.Forms;

type
  // Базовый класс задачи (для любой функции из DLL).
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

  // Класс задачи для функции SearchFiles из DLL1
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

  // Класс задачи для функции SearchSequence из DLL1
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

  // Класс задачи для функции ProcessCli из DLL2
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

// конструктор для TTask
constructor TTask.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  fID := vID;
  fNameDLL := vNameDLL;
  fNameTask := vNameTask;

  fProgressBar := vProgressBar;

  ResultLog := TStringList.Create;
end;

// деструктор для TTask
destructor TTask.Destroy;
begin
  ResultLog.Free;

  inherited;
end;

// сеттер для свойства NameDLL
procedure TTask.SetNameDLL(vNameDLL: string);
begin
  fNameDLL := vNameDLL;
end;

// сеттер для свойства NameTask
procedure TTask.SetNameTask(vNameTask: string);
begin
  fNameTask := vNameTask;
end;

// сеттер для свойства ProgressBar
procedure TTask.SetProgressBar(vProgressBar: TProgressBar);
begin
  fProgressBar := vProgressBar;
end;

// сохранение логов выполнения задачи в Memo
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

// сохранение логов выполнения задачи в файл
procedure TTask.SaveLogToFile(FolderPath: string);
begin
  ResultLog.SaveToFile(FolderPath + '\' + NameTask + '_Log.txt');
end;

// --------------------------TTaskSearchFiles----------------------------------

// конструктор для TTaskSearchFiles
constructor TTaskSearchFiles.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  inherited Create(vID, vNameDLL, vNameTask, vProgressBar);

  ResultStringList := TStringList.Create;
end;

// деструктор для TTaskSearchFiles
destructor TTaskSearchFiles.Destroy;
begin
  ResultStringList.Free;

  inherited;
end;

// сохранение результатов выполнения функции SearchFiles в Memo
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
  Memo.Lines.Add('Количество найденных файлов: ' + ResultInt.ToString);
end;

// --------------------------TTaskSearchSequence-------------------------------

// конструктор для TTaskSearchSequence
constructor TTaskSearchSequence.Create(vID: Word; vNameDLL, vNameTask: string;
  vProgressBar: TProgressBar);
begin
  inherited Create(vID, vNameDLL, vNameTask, vProgressBar);

  ResultDictionary := TDictionary<String, String>.Create;
end;

// деструктор для TTaskSearchSequence
destructor TTaskSearchSequence.Destroy;
begin
  ResultDictionary.Free;

  inherited;
end;

// сохранение результатов выполнения функции SearchSequence в Memo
procedure TTaskSearchSequence.SaveResultToMemo(Memo: TMemo);
var
  Key: string;
begin
  Memo.Lines.Clear;

  Memo.Lines.Add('Количество найденных вхождений: ' + ResultInt.ToString);
  for Key in ResultDictionary.Keys do
    Memo.Lines.Add(Key + ':' + ResultDictionary.Items[Key]);
end;

// ----------------------------TTaskProcessCli---------------------------------

// сохранение результатов выполнения функции ProcessCli в Memo
procedure TTaskProcessCli.SaveResultToMemo(Memo: TMemo);
begin
  Memo.Lines.Clear;

  if ResultString <> '' then
  begin
    Memo.Lines.Add('Код результата: ' + ResultInt.ToString);
    Memo.Lines.Add(ResultString);
  end;
end;

end.
