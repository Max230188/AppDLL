unit uTaskThread;

{ �� ����� ������� ������� ProcessCli ���������� EConverError ���������� ��������
  � ������������ �.�. ��� ����� �������������� ��������������� � DLL2 }

interface

uses
  ShareMem, System.Classes, System.Types, System.Generics.Collections,
  System.SysUtils, System.SyncObjs, Winapi.Windows, Vcl.Forms, uTask;

type
  // ��������� ��������� (������������ ��� ��������� ��������� ������)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // ������� ����� ������ ������ (��� ����� ������� �� DLL).
  TTaskThread = class(TThread)
  private
    // ��� ������ ����� � ��������� ���������� ������
    fCallBackLog: TCallBackLog;
    fCallBackProgress: TCallBackProgress;

  protected
    // � ������ FreeOnTerminate := True �� ������ ��������� �����������
    // �������� Finished � Terminated, ������� ������� TaskTerminated
    fTaskTerminated: Boolean;

    fOnTaskTerminate: TNotifyEvent;

    StopFlag: Boolean;

  protected
    procedure SetCallBackLog(vCallBackLog: TCallBackLog);
    procedure SetCallBackProgress(vCallBackProgress: TCallBackProgress);

    // ����� ����������� ������� OnTaskTerminate
    procedure DoTaskTerminate;

  public
    Task: TTask;

  public
    constructor Create(vTask: TTask);
    destructor Destroy; override;

    procedure WaitTerminated;
    procedure StopTask;

  public
    property CallBackLog: TCallBackLog read fCallBackLog write SetCallBackLog;
    property CallBackProcess: TCallBackProgress read fCallBackProgress
      write SetCallBackProgress;
    property TaskTerminated: Boolean read fTaskTerminated;

    // ������� ���������� ������ ������
    property OnTaskTerminate: TNotifyEvent read fOnTaskTerminate
      write fOnTaskTerminate;
  end;

  // ����� ������ ������ ��� ������� SearchFiles �� DLL1
  TTaskSearchFilesThread = class(TTaskThread)
  protected
    procedure Execute; override;

  public
    TaskSearchFiles: TTaskSearchFiles;

  public
    constructor Create(vTaskSearchFiles: TTaskSearchFiles);
    destructor Destroy; override;

    procedure StartSearchFiles;
  end;

  // ����� ������ ������ ��� ������� SearchSequence �� DLL1
  TTaskSearchSequenceThread = class(TTaskThread)
  protected
    procedure Execute; override;

  public
    TaskSearchSequence: TTaskSearchSequence;

  public
    constructor Create(vTaskSearchSequence: TTaskSearchSequence);
    destructor Destroy; override;

    procedure StartSearchSequence;
  end;

  // ����� ������ ������ ��� ������� ProcessCli �� DLL2
  TTaskProcessCliThread = class(TTaskThread)
  protected
    procedure Execute; override;

  public
    TaskProcessCli: TTaskProcessCli;

  public
    constructor Create(vTaskProcessCli: TTaskProcessCli);
    destructor Destroy; override;

    procedure StartProcessCli;
  end;

implementation

// --------------------------------TTaskThread--------------------------------

// ����������� ��� TTaskThread
constructor TTaskThread.Create(vTask: TTask);
begin
  inherited Create(True); // ������� ����� ����������������
  Priority := tpNormal; // ��������� ������

  FreeOnTerminate := True; // ���������� ������ ����� ���������� �������������
  StopFlag := False;
  fTaskTerminated := False;

  Task := vTask;

  with Task do
  begin
    // ���������� ��������� ��������� TCallBackLog
    fCallBackLog := procedure(LogMessage: string)
      begin
        if LogMessage <> '' then
        begin
          LogMessage := DateTimeToStr(Now) + ' ' + LogMessage;
          ResultLog.Add(LogMessage);
        end;
      end;

    // ���������� ��������� ��������� TCallBackProgress
    fCallBackProgress := procedure(Progress, MaxProgress: integer)
      begin
        if Assigned(ProgressBar) then
        begin
          // Synchronize(
          // procedure
          // begin
          ProgressBar.Max := MaxProgress;
          ProgressBar.Position := Progress;
          // end);

          Application.ProcessMessages;
        end;
      end;
  end;
end;

// ���������� ��� TTaskThread
destructor TTaskThread.Destroy;
begin
  Task := nil;

  inherited;
end;

// ������ ��� �������� CallBackLog
procedure TTaskThread.SetCallBackLog(vCallBackLog: TCallBackLog);
begin
  fCallBackLog := vCallBackLog;
end;

// ������ ��� �������� CallBackProgress
procedure TTaskThread.SetCallBackProgress(vCallBackProgress: TCallBackProgress);
begin
  fCallBackProgress := vCallBackProgress;
end;

// ����� ����������� ������� OnTaskTerminate
procedure TTaskThread.DoTaskTerminate;
begin
  if Assigned(fOnTaskTerminate) then // ��������, �������� �� ����������
    fOnTaskTerminate(Self); // ����� �������
end;

// �������� ���������� ������ ������
procedure TTaskThread.WaitTerminated;
begin
  while (not Terminated) and (not TaskTerminated) do
  begin
    Sleep(20);
    Application.ProcessMessages;
  end;
end;

// ��������� ���������� ������
procedure TTaskThread.StopTask;
var
  CriticalSection: TCriticalSection;
begin
  CriticalSection := TCriticalSection.Create;

  try
    CriticalSection.Enter;

    FreeOnTerminate := False; // ���������� ������ ����� ���������� �������
    StopFlag := True;
    // ��� ������������� WaitTerminated �����
    // ���������������� TaskThread.WaitFor � TAPI.StopTask
    // WaitTerminated;

  finally
    CriticalSection.Leave;
    CriticalSection.Free;
  end;
end;

// --------------------------TTaskSearchFilesThread----------------------------

// ����������� ��� TTaskSearchFilesThread
constructor TTaskSearchFilesThread.Create(vTaskSearchFiles: TTaskSearchFiles);
begin
  inherited Create(vTaskSearchFiles);

  TaskSearchFiles := vTaskSearchFiles;
end;

// ���������� ��� TTaskSearchFilesThread
destructor TTaskSearchFilesThread.Destroy;
begin
  TaskSearchFiles := nil;

  inherited;
end;

// ��������� ����� Execute ��� TTaskSearchFilesThread
procedure TTaskSearchFilesThread.Execute;
begin
  StartSearchFiles;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // ������������� ���� ���������� ������ (Terminated = True)
end;

// ������ ������� SearchFiles �� DLL1
procedure TTaskSearchFilesThread.StartSearchFiles;
type
  // ��������� �������� ������������� �������
  TSearchFiles = function(App: TApplication; SourcePath, MaskFiles: String;
    CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
    var StopFlag: Boolean; out FilesPath: TStringList): integer; stdcall;
var
  SearchFiles: TSearchFiles;
  hLib: THandle;
  dwError: DWord;
  CriticalSection: TCriticalSection;
begin
  FreeOnTerminate := True;
  StopFlag := False;

  with TaskSearchFiles do
  begin
    ProgressBar.Position := 0;
    ResultLog.Clear;
    ResultStringList.Clear;

    // ��������� DLL � ������
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // �������� ����� ������� �� DLL
        SearchFiles := GetProcAddress(hLib, PWideChar(NameTask));
        if @SearchFiles <> nil then
        begin
          // ��������� ������� �� ����������
          ResultInt := SearchFiles(Application, SourcePath, MaskFiles,
            CallBackLog, CallBackProcess, StopFlag, ResultStringList);
        end
        else
        begin
          // ������������ ������
          dwError := GetLastError();
          raise Exception.CreateFmt('������ ����������� � ������� %s, ��� %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // ��������� DLL �� ������
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // ������������ ������
      dwError := GetLastError();
      raise Exception.CreateFmt('������ ���������� %s, ��� %d',
        [NameDLL, dwError]);
    end;
  end;
end;

// --------------------------TTaskSearchSequenceThread------------------------

// ����������� ��� TTaskSearchSequenceThread
constructor TTaskSearchSequenceThread.Create(vTaskSearchSequence
  : TTaskSearchSequence);
begin
  inherited Create(vTaskSearchSequence);

  TaskSearchSequence := vTaskSearchSequence;
end;

// ���������� ��� TTaskSearchSequenceThread
destructor TTaskSearchSequenceThread.Destroy;
begin
  TaskSearchSequence := nil;

  inherited;
end;

// ��������� ����� Execute ��� TTaskSearchSequenceThread
procedure TTaskSearchSequenceThread.Execute;
begin
  StartSearchSequence;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // ������������� ���� ���������� ������ (Terminated = True)
end;

// ������ ������� SearchSequence �� DLL1
procedure TTaskSearchSequenceThread.StartSearchSequence;
type
  // ��������� �������� ������������� �������
  TSearchSequence = function(App: TApplication; SourceFile, Sequence: string;
    CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
    var StopFlag: Boolean; out PosSequence: TDictionary<String, String>)
    : integer; stdcall;
var
  SearchSequence: TSearchSequence;
  hLib: THandle;
  dwError: DWord;
  CriticalSection: TCriticalSection;
begin
  FreeOnTerminate := True;
  StopFlag := False;

  with TaskSearchSequence do
  begin
    ProgressBar.Position := 0;
    ResultLog.Clear;
    ResultDictionary.Clear;

    // ��������� DLL � ������
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // �������� ����� ������� �� DLL
        SearchSequence := GetProcAddress(hLib, PWideChar(NameTask));
        if @SearchSequence <> nil then
        begin
          // ��������� ������� �� ����������
          ResultInt := SearchSequence(Application, SourceFile, Sequence,
            CallBackLog, CallBackProcess, StopFlag, ResultDictionary);
        end
        else
        begin
          // ������������ ������
          dwError := GetLastError();
          raise Exception.CreateFmt('������ ����������� � ������� %s, ��� %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // ��������� DLL �� ������
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // ������������ ������
      dwError := GetLastError();
      raise Exception.CreateFmt('������ ���������� %s, ��� %d',
        [NameDLL, dwError]);
    end;
  end;
end;

// ----------------------------TTaskProcessCliThread--------------------------

// ����������� ��� TTaskProcessCliThread
constructor TTaskProcessCliThread.Create(vTaskProcessCli: TTaskProcessCli);
begin
  inherited Create(vTaskProcessCli);

  TaskProcessCli := vTaskProcessCli;
end;

// ���������� ��� TTaskProcessCliThread
destructor TTaskProcessCliThread.Destroy;
begin
  TaskProcessCli := nil;

  inherited;
end;

// ��������� ����� Execute ��� TTaskProcessCliThread
procedure TTaskProcessCliThread.Execute;
begin
  StartProcessCli;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // ������������� ���� (Terminated) ���������� ������
end;

// ������ ������� ProcessCli �� DLL2
procedure TTaskProcessCliThread.StartProcessCli;
type
  // ��������� �������� ������������� �������
  TProcessCli = function(App: TApplication; SourcePath: string;
    CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
    var StopFlag: Boolean; out ResultMessage: string): integer; stdcall;
var
  ProcessCli: TProcessCli;
  hLib: THandle;
  dwError: DWord;
  CriticalSection: TCriticalSection;
begin
  FreeOnTerminate := True;
  StopFlag := False;

  with TaskProcessCli do
  begin
    ProgressBar.Position := 0;
    ResultLog.Clear;

    // ��������� DLL � ������
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // �������� ����� ������� �� DLL
        ProcessCli := GetProcAddress(hLib, PWideChar(NameTask));
        if @ProcessCli <> nil then
        begin
          // ��������� ������� �� ����������
          ResultInt := ProcessCli(Application, SourcePath, CallBackLog,
            CallBackProcess, StopFlag, ResultString);
        end
        else
        begin
          // ������������ ������
          dwError := GetLastError();
          raise Exception.CreateFmt('������ ����������� � ������� %s, ��� %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // ��������� DLL �� ������
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // ������������ ������
      dwError := GetLastError();
      raise Exception.CreateFmt('������ ���������� %s, ��� %d',
        [NameDLL, dwError]);
    end;
  end;
end;

end.
