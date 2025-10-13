unit uTaskThread;

{ Во время отладки функции ProcessCli исключение EConverError необходимо добавить
  в игнорируемые т.к. оно будет обрабатываться непосредственно в DLL2 }

interface

uses
  ShareMem, System.Classes, System.Types, System.Generics.Collections,
  System.SysUtils, System.SyncObjs, Winapi.Windows, Vcl.Forms, uTask;

type
  // Анонимные процедуры (используются как процедуры обратного вызова)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // Базовый класс потока задачи (для любой функции из DLL).
  TTaskThread = class(TThread)
  private
    // для вывода логов и прогресса выполнения задачи
    fCallBackLog: TCallBackLog;
    fCallBackProgress: TCallBackProgress;

  protected
    // в режиме FreeOnTerminate := True не всегда правильно обновляются
    // свойства Finished и Terminated, поэтому добавил TaskTerminated
    fTaskTerminated: Boolean;

    fOnTaskTerminate: TNotifyEvent;

    StopFlag: Boolean;

  protected
    procedure SetCallBackLog(vCallBackLog: TCallBackLog);
    procedure SetCallBackProgress(vCallBackProgress: TCallBackProgress);

    // вызов обработчика события OnTaskTerminate
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

    // событие завершения работы потока
    property OnTaskTerminate: TNotifyEvent read fOnTaskTerminate
      write fOnTaskTerminate;
  end;

  // Класс потока задачи для функции SearchFiles из DLL1
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

  // Класс потока задачи для функции SearchSequence из DLL1
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

  // Класс потока задачи для функции ProcessCli из DLL2
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

// конструктор для TTaskThread
constructor TTaskThread.Create(vTask: TTask);
begin
  inherited Create(True); // создаем поток приостановленным
  Priority := tpNormal; // приоритет потока

  FreeOnTerminate := True; // деструктор потока будет вызываться автоматически
  StopFlag := False;
  fTaskTerminated := False;

  Task := vTask;

  with Task do
  begin
    // реализация анонимной процедуры TCallBackLog
    fCallBackLog := procedure(LogMessage: string)
      begin
        if LogMessage <> '' then
        begin
          LogMessage := DateTimeToStr(Now) + ' ' + LogMessage;
          ResultLog.Add(LogMessage);
        end;
      end;

    // реализация анонимной процедуры TCallBackProgress
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

// деструктор для TTaskThread
destructor TTaskThread.Destroy;
begin
  Task := nil;

  inherited;
end;

// сеттер для свойства CallBackLog
procedure TTaskThread.SetCallBackLog(vCallBackLog: TCallBackLog);
begin
  fCallBackLog := vCallBackLog;
end;

// сеттер для свойства CallBackProgress
procedure TTaskThread.SetCallBackProgress(vCallBackProgress: TCallBackProgress);
begin
  fCallBackProgress := vCallBackProgress;
end;

// вызов обработчика события OnTaskTerminate
procedure TTaskThread.DoTaskTerminate;
begin
  if Assigned(fOnTaskTerminate) then // проверка, назначен ли обработчик
    fOnTaskTerminate(Self); // вызов события
end;

// ожидание завершения работы потока
procedure TTaskThread.WaitTerminated;
begin
  while (not Terminated) and (not TaskTerminated) do
  begin
    Sleep(20);
    Application.ProcessMessages;
  end;
end;

// остановка выполнения задачи
procedure TTaskThread.StopTask;
var
  CriticalSection: TCriticalSection;
begin
  CriticalSection := TCriticalSection.Create;

  try
    CriticalSection.Enter;

    FreeOnTerminate := False; // деструктор потока будет вызываться вручную
    StopFlag := True;
    // при использовании WaitTerminated нужно
    // закомментировать TaskThread.WaitFor в TAPI.StopTask
    // WaitTerminated;

  finally
    CriticalSection.Leave;
    CriticalSection.Free;
  end;
end;

// --------------------------TTaskSearchFilesThread----------------------------

// конструктор для TTaskSearchFilesThread
constructor TTaskSearchFilesThread.Create(vTaskSearchFiles: TTaskSearchFiles);
begin
  inherited Create(vTaskSearchFiles);

  TaskSearchFiles := vTaskSearchFiles;
end;

// деструктор для TTaskSearchFilesThread
destructor TTaskSearchFilesThread.Destroy;
begin
  TaskSearchFiles := nil;

  inherited;
end;

// описываем метод Execute для TTaskSearchFilesThread
procedure TTaskSearchFilesThread.Execute;
begin
  StartSearchFiles;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // устанавливаем флаг завершения потока (Terminated = True)
end;

// запуск функции SearchFiles из DLL1
procedure TTaskSearchFilesThread.StartSearchFiles;
type
  // объявляем прототип импортируемой функции
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

    // загружаем DLL в память
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // получаем адрес функции из DLL
        SearchFiles := GetProcAddress(hLib, PWideChar(NameTask));
        if @SearchFiles <> nil then
        begin
          // запускаем функцию на выполнение
          ResultInt := SearchFiles(Application, SourcePath, MaskFiles,
            CallBackLog, CallBackProcess, StopFlag, ResultStringList);
        end
        else
        begin
          // обрабатываем ошибки
          dwError := GetLastError();
          raise Exception.CreateFmt('Ошибка подключения к функции %s, код %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // выгружаем DLL из памяти
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // обрабатываем ошибки
      dwError := GetLastError();
      raise Exception.CreateFmt('Ошибка библиотеки %s, код %d',
        [NameDLL, dwError]);
    end;
  end;
end;

// --------------------------TTaskSearchSequenceThread------------------------

// конструктор для TTaskSearchSequenceThread
constructor TTaskSearchSequenceThread.Create(vTaskSearchSequence
  : TTaskSearchSequence);
begin
  inherited Create(vTaskSearchSequence);

  TaskSearchSequence := vTaskSearchSequence;
end;

// деструктор для TTaskSearchSequenceThread
destructor TTaskSearchSequenceThread.Destroy;
begin
  TaskSearchSequence := nil;

  inherited;
end;

// описываем метод Execute для TTaskSearchSequenceThread
procedure TTaskSearchSequenceThread.Execute;
begin
  StartSearchSequence;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // устанавливаем флаг завершения потока (Terminated = True)
end;

// запуск функции SearchSequence из DLL1
procedure TTaskSearchSequenceThread.StartSearchSequence;
type
  // объявляем прототип импортируемой функции
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

    // загружаем DLL в память
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // получаем адрес функции из DLL
        SearchSequence := GetProcAddress(hLib, PWideChar(NameTask));
        if @SearchSequence <> nil then
        begin
          // запускаем функцию на выполнение
          ResultInt := SearchSequence(Application, SourceFile, Sequence,
            CallBackLog, CallBackProcess, StopFlag, ResultDictionary);
        end
        else
        begin
          // обрабатываем ошибки
          dwError := GetLastError();
          raise Exception.CreateFmt('Ошибка подключения к функции %s, код %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // выгружаем DLL из памяти
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // обрабатываем ошибки
      dwError := GetLastError();
      raise Exception.CreateFmt('Ошибка библиотеки %s, код %d',
        [NameDLL, dwError]);
    end;
  end;
end;

// ----------------------------TTaskProcessCliThread--------------------------

// конструктор для TTaskProcessCliThread
constructor TTaskProcessCliThread.Create(vTaskProcessCli: TTaskProcessCli);
begin
  inherited Create(vTaskProcessCli);

  TaskProcessCli := vTaskProcessCli;
end;

// деструктор для TTaskProcessCliThread
destructor TTaskProcessCliThread.Destroy;
begin
  TaskProcessCli := nil;

  inherited;
end;

// описываем метод Execute для TTaskProcessCliThread
procedure TTaskProcessCliThread.Execute;
begin
  StartProcessCli;
  Synchronize(DoTaskTerminate);
  fTaskTerminated := True;
  Terminate; // устанавливаем флаг (Terminated) завершения потока
end;

// запуск функции ProcessCli из DLL2
procedure TTaskProcessCliThread.StartProcessCli;
type
  // объявляем прототип импортируемой функции
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

    // загружаем DLL в память
    hLib := LoadLibrary(PWideChar(NameDLL));

    if hLib <> 0 then
    begin
      CriticalSection := TCriticalSection.Create;

      try
        CriticalSection.Enter;

        // получаем адрес функции из DLL
        ProcessCli := GetProcAddress(hLib, PWideChar(NameTask));
        if @ProcessCli <> nil then
        begin
          // запускаем функцию на выполнение
          ResultInt := ProcessCli(Application, SourcePath, CallBackLog,
            CallBackProcess, StopFlag, ResultString);
        end
        else
        begin
          // обрабатываем ошибки
          dwError := GetLastError();
          raise Exception.CreateFmt('Ошибка подключения к функции %s, код %d',
            [NameTask, dwError]);
        end;
      finally
        CriticalSection.Leave;
        CriticalSection.Free;

        // выгружаем DLL из памяти
        FreeLibrary(hLib);
      end;
    end
    else
    begin
      // обрабатываем ошибки
      dwError := GetLastError();
      raise Exception.CreateFmt('Ошибка библиотеки %s, код %d',
        [NameDLL, dwError]);
    end;
  end;
end;

end.
