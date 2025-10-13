unit uAPI;

interface

uses
  ShareMem, System.Classes, System.Types, System.Generics.Collections,
  System.SysUtils, System.UITypes, System.IniFiles, Vcl.StdCtrls, Vcl.ComCtrls,
  Vcl.Forms, Vcl.Dialogs, Winapi.Windows, ShellApi, ShlObj, uTask, uTaskThread,
  uInfoDLL, uTaskParams, uTaskResult, uTaskLog;

type
  // ����� ����������� API ��� ������ � DLL
  TAPI = class
  private
    frmTaskParameters: TfrmTaskParams;
    frmTaskResults: TfrmTaskResult;
    frmTaskLogs: TfrmTaskLog;

    TaskParametersINI: TIniFile;

    TaskList: TObjectList<TTask>;
    TaskThreadList: TObjectList<TTaskThread>;

  private
    function SearchTask(TaskID: Word): TTask;
    function SearchTaskThread(TaskID: Word): TTaskThread;

    function SearchFilesSetParams(var TaskSearchFiles
      : TTaskSearchFiles): Boolean;
    function StartSearchFiles(TaskID: Word; NameDLL, NameTask: string;
      ProgressBar: TProgressBar): Boolean;

    function SearchSequenceSetParams(var TaskSearchSequence
      : TTaskSearchSequence): Boolean;
    function StartSearchSequence(TaskID: Word; NameDLL, NameTask: string;
      ProgressBar: TProgressBar): Boolean;

    function ProcessCliSetParams(var TaskProcessCli: TTaskProcessCli): Boolean;
    function StartProcessCli(TaskID: Word; NameDLL, NameTask: string;
      ProgressBar: TProgressBar): Boolean;

    function GetDialogSelectFolder: string;

  public
    constructor Create;
    destructor Destroy; override;

    function StartTask(TaskID: Word; NameDLL, NameTask: string;
      ProgressBar: TProgressBar): Boolean;
    procedure StopTask(TaskThread: TTaskThread); overload;
    procedure StopTask(TaskID: Word); overload;
    procedure StopAllTask;

    procedure DeleteTaskFromList(TaskID: Word);
    procedure DeleteTaskThreadFromList(TaskThread: TTaskThread);

    procedure GetTaskResult(TaskID: Word);
    procedure GetTaskLog(TaskID: Word);

    procedure GetInfoDLL(TreeView: TTreeView);
  end;

implementation

uses uMain;

// -----------------------------TAPI---------------------------------------

// ����������� ��� TAPI
constructor TAPI.Create;
begin
  frmTaskParameters := TfrmTaskParams.Create(Application.MainForm);
  frmTaskResults := TfrmTaskResult.Create(Application.MainForm);
  frmTaskLogs := TfrmTaskLog.Create(Application.MainForm);

  TaskParametersINI := TIniFile.Create(ExtractFilePath(ParamStr(0)) +
    'TaskParameters.ini');

  TaskList := TObjectList<TTask>.Create;
  TaskThreadList := TObjectList<TTaskThread>.Create;
  TaskThreadList.OwnsObjects := False;
end;

// ���������� ��� TAPI
destructor TAPI.Destroy;
begin
  frmTaskParameters.Release;
  frmTaskResults.Release;
  frmTaskLogs.Release;

  TaskParametersINI.Free;

  StopAllTask;
  TaskThreadList.Free;

  // ��� ������� TaskList ����� ���������� ������������� (�.�. OwnsObjects = True)
  TaskList.Clear;
  TaskList.Free;

  inherited;
end;

// ����� ������ � ������ TaskList �� ID
function TAPI.SearchTask(TaskID: Word): TTask;
var
  Task: TTask;
begin
  Result := nil;

  for Task in TaskList do
    if Task.ID = TaskID then
    begin
      Result := Task;
      break;
    end;
end;

// ����� ������ ���������� ������ � TaskThreadList �� ID
function TAPI.SearchTaskThread(TaskID: Word): TTaskThread;
var
  TaskThread: TTaskThread;
begin
  Result := nil;

  for TaskThread in TaskThreadList do
    if TaskThread.Task.ID = TaskID then
    begin
      Result := TaskThread;
      break;
    end;
end;

// ��������� �������� ���������� ��� ������� SearchFiles
function TAPI.SearchFilesSetParams(var TaskSearchFiles
  : TTaskSearchFiles): Boolean;
var
  Path, Mask: string;
begin
  Result := False;

  with TaskParametersINI do
  begin
    Path := ReadString('SearchFiles', 'Path', 'D:\');
    Mask := ReadString('SearchFiles', 'Mask',
      '*.txt, *.bin, *.dat, *.dll, *.exe');
  end;

  with frmTaskParameters.vleParameters do
  begin
    Strings.Clear;
    Strings.BeginUpdate;
    InsertRow('Path', Path, True);
    InsertRow('Mask', Mask, True);
    Strings.EndUpdate;
  end;

  with frmTaskParameters do
    if ShowModal = mrOk then
    begin
      Path := vleParameters.Values['Path'];
      Mask := vleParameters.Values['Mask'];

      TaskSearchFiles.SourcePath := Path;
      TaskSearchFiles.MaskFiles := Mask;

      with TaskParametersINI do
      begin
        WriteString('SearchFiles', 'Path', Path);
        WriteString('SearchFiles', 'Mask', Mask);
      end;

      Result := True;
    end;
end;

// ������ ������� SearchFiles �� DLL1
function TAPI.StartSearchFiles(TaskID: Word; NameDLL, NameTask: string;
  ProgressBar: TProgressBar): Boolean;
var
  TaskSearchFiles: TTaskSearchFiles;
  TaskSearchFilesThread: TTaskSearchFilesThread;
begin
  Result := False;

  TaskSearchFiles := TTaskSearchFiles.Create(TaskID, 'DLL1', 'SearchFiles',
    ProgressBar);
  if SearchFilesSetParams(TaskSearchFiles) then
  begin
    TaskSearchFilesThread := TTaskSearchFilesThread.Create(TaskSearchFiles);

    // TaskSearchFilesThread.OnTerminate := frmMain.TaskThreadTerminate;
    TaskSearchFilesThread.OnTaskTerminate := frmMain.TaskThreadTerminate;

    TaskList.Add(TaskSearchFiles);
    TaskThreadList.Add(TaskSearchFilesThread);

    TaskSearchFilesThread.Start;
    // ��� ������ ��� ����� ����� ���������������� TaskSearchFilesThread.Start,
    // WaitTerminated � TTaskThread.StopTask � TaskThread.WaitFor � TAPI.StopTask,
    // � ����� ����������������� TaskSearchFilesThread.StartSearchFiles
    // TaskSearchFilesThread.StartSearchFiles;

    Result := True;
  end
  else
    TaskSearchFiles.Free;
end;

// ��������� �������� ���������� ��� ������� SearchSequence
function TAPI.SearchSequenceSetParams(var TaskSearchSequence
  : TTaskSearchSequence): Boolean;
var
  FilePath, Sequence: string;
begin
  Result := False;

  with TaskParametersINI do
  begin
    FilePath := ReadString('SearchSequence', 'File',
      'C:\Users\Max\Desktop\My\test5.bin');
    Sequence := ReadString('SearchSequence', 'Sequence',
      'PA3, ���, Object, class, ������');
  end;

  with frmTaskParameters.vleParameters do
  begin
    Strings.Clear;
    Strings.BeginUpdate;
    InsertRow('File', FilePath, True);
    InsertRow('Sequence', Sequence, True);
    Strings.EndUpdate;
  end;

  with frmTaskParameters do
    if ShowModal = mrOk then
    begin
      FilePath := vleParameters.Values['File'];
      Sequence := vleParameters.Values['Sequence'];

      TaskSearchSequence.SourceFile := FilePath;
      TaskSearchSequence.Sequence := Sequence;

      with TaskParametersINI do
      begin
        WriteString('SearchSequence', 'File', FilePath);
        WriteString('SearchSequence', 'Sequence', Sequence);
      end;

      Result := True;
    end;
end;

// ������ ������� SearchSequence �� DLL1
function TAPI.StartSearchSequence(TaskID: Word; NameDLL, NameTask: string;
  ProgressBar: TProgressBar): Boolean;
var
  TaskSearchSequence: TTaskSearchSequence;
  TaskSearchSequenceThread: TTaskSearchSequenceThread;
begin
  Result := False;

  TaskSearchSequence := TTaskSearchSequence.Create(TaskID, 'DLL1',
    'SearchSequence', ProgressBar);
  if SearchSequenceSetParams(TaskSearchSequence) then
  begin
    TaskSearchSequenceThread := TTaskSearchSequenceThread.Create
      (TaskSearchSequence);

    // TaskSearchSequenceThread.OnTerminate := frmMain.TaskThreadTerminate;
    TaskSearchSequenceThread.OnTaskTerminate := frmMain.TaskThreadTerminate;

    TaskList.Add(TaskSearchSequence);
    TaskThreadList.Add(TaskSearchSequenceThread);

    TaskSearchSequenceThread.Start;
    // ��� ������ ��� ����� ����� ���������������� TaskSearchSequenceThread.Start,
    // WaitTerminated � TTaskThread.StopTask � TaskThread.WaitFor � TAPI.StopTask,
    // � ����� ����������������� TaskSearchSequenceThread.StartSearchSequence
    // TaskSearchSequenceThread.StartSearchSequence;

    Result := True;
  end
  else
    TaskSearchSequence.Free;
end;

// ��������� �������� ���������� ��� ������� ProcessCli
function TAPI.ProcessCliSetParams(var TaskProcessCli: TTaskProcessCli): Boolean;
var
  Path: string;
begin
  Result := False;

  with TaskParametersINI do
  begin
    Path := ReadString('ProcessCli', 'Path',
      'C:\Users\Max\Desktop\Archive\New');
  end;

  with frmTaskParameters.vleParameters do
  begin
    Strings.Clear;
    Strings.BeginUpdate;
    InsertRow('Path', Path, True);
    Strings.EndUpdate;
  end;

  with frmTaskParameters do
    if ShowModal = mrOk then
    begin
      Path := vleParameters.Values['Path'];

      TaskProcessCli.SourcePath := Path;

      with TaskParametersINI do
      begin
        WriteString('ProcessCli', 'Path', Path);
      end;

      Result := True;
    end;
end;

// ������ ������� ProcessCli �� DLL1
function TAPI.StartProcessCli(TaskID: Word; NameDLL, NameTask: string;
  ProgressBar: TProgressBar): Boolean;
var
  TaskProcessCli: TTaskProcessCli;
  TaskProcessCliThread: TTaskProcessCliThread;
begin
  Result := False;

  TaskProcessCli := TTaskProcessCli.Create(TaskID, 'DLL2', 'ProcessCli',
    ProgressBar);
  if ProcessCliSetParams(TaskProcessCli) then
  begin
    TaskProcessCliThread := TTaskProcessCliThread.Create(TaskProcessCli);

    // TaskProcessCliThread.OnTerminate := frmMain.TaskThreadTerminate;
    TaskProcessCliThread.OnTaskTerminate := frmMain.TaskThreadTerminate;

    TaskList.Add(TaskProcessCli);
    TaskThreadList.Add(TaskProcessCliThread);

    TaskProcessCliThread.Start;
    // ��� ������ ��� ����� ����� ���������������� TaskProcessCliThread.Start,
    // WaitTerminated � TTaskThread.StopTask � TaskThread.WaitFor � TAPI.StopTask,
    // � ����� ����������������� TaskProcessCliThread.StartProcessCli
    // TaskProcessCliThread.StartProcessCli;

    Result := True;
  end
  else
    TaskProcessCli.Free;
end;

// ������ ������ �� ����������
function TAPI.StartTask(TaskID: Word; NameDLL, NameTask: string;
  ProgressBar: TProgressBar): Boolean;
begin
  Result := False;

  if NameDLL = 'DLL1.dll' then
  begin
    if NameTask = 'SearchFiles' then
      Result := StartSearchFiles(TaskID, NameDLL, NameTask, ProgressBar);

    if NameTask = 'SearchSequence' then
      Result := StartSearchSequence(TaskID, NameDLL, NameTask, ProgressBar);
  end;

  if NameDLL = 'DLL2.dll' then
  begin
    if NameTask = 'ProcessCli' then
      Result := StartProcessCli(TaskID, NameDLL, NameTask, ProgressBar);
  end;
end;

// ��������� ������
procedure TAPI.StopTask(TaskThread: TTaskThread);
begin
  TaskThreadList.Remove(TaskThread);

  if (TaskThread <> nil) and (not TaskThread.TaskTerminated) then
  begin
    TaskThread.StopTask;
    TaskThread.WaitFor; // ������� ���������� ������ ������
    FreeAndNil(TaskThread); // ����� ������ ���������� ��������� ������
  end;
end;

// ��������� ������ �� ID
procedure TAPI.StopTask(TaskID: Word);
var
  TaskThread: TTaskThread;
begin
  TaskThread := SearchTaskThread(TaskID);

  StopTask(TaskThread);
end;

// ��������� ���� �����
procedure TAPI.StopAllTask;
var
  i: integer;
begin
  for i := TaskThreadList.Count - 1 downto 0 do
    StopTask(TaskThreadList.Items[i]);

  TaskThreadList.Clear;
end;

// �������� ������ �� ������ TaskList �� ID
procedure TAPI.DeleteTaskFromList(TaskID: Word);
var
  Task: TTask;
begin
  Task := SearchTask(TaskID);
  TaskList.Remove(Task);
end;

// �������� ������ ������ �� ������ TaskThreadList
// � ������ FreeOnTerminate = True ���������� ������ ����� ������ �������������
procedure TAPI.DeleteTaskThreadFromList(TaskThread: TTaskThread);
begin
  TaskThreadList.Remove(TaskThread);
end;

// ��������� ����������� ������ ������ �� ID
procedure TAPI.GetTaskResult(TaskID: Word);
var
  Task: TTask;
begin
  Task := SearchTask(TaskID);

  frmTaskResults.mmResult.Clear;

  Task.SaveResultToMemo(frmTaskResults.mmResult);

  frmTaskResults.ShowModal;
end;

// ��������� ����� ������ ������ �� ID
procedure TAPI.GetTaskLog(TaskID: Word);
var
  Task: TTask;
  FolderPath: string;
begin
  Task := SearchTask(TaskID);

  frmTaskLogs.mmLog.Clear;

  Task.SaveLogToMemo(frmTaskLogs.mmLog);

  if frmTaskLogs.ShowModal = mrOk then
  begin
    FolderPath := GetDialogSelectFolder;
    if FolderPath <> '' then
    begin
      Task.SaveLogToFile(FolderPath);
      MessageDlg('File ' + Task.NameTask + '_Log.txt' + ' save in folder ' +
        FolderPath, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
    end;
  end;
end;

// ����� ������� ������ �����
// ���������� ���� � ��������� �����
function TAPI.GetDialogSelectFolder: string;
var
  PIDL: PItemIDList;
  // ��������� �� ���������� ������������� ������� �������� shell
  BrowseInfo: TBrowseInfo;
  Buf: Array [0 .. MAX_PATH - 1] of Char;
begin
  with BrowseInfo do
  begin
    // ���������� ������������� ����
    hwndOwner := Application.MainForm.Handle;
    // PIDL ��������� ��������
    pidlRoot := nil;
    // ����� ������, � ������� ����� ���������� �������� ��������� ������������� �����
    pszDisplayName := Buf;
    // ����� ������, ����������� ��������� �������
    lpszTitle := '����� �����';
    // ���� ����� ����������� ����
    ulFlags := BIF_RETURNFSANCESTORS OR BIF_USENEWUI;
    // ����� ������� ��������� ������ ����������, ����������� ��� ������ �������
    lpfn := nil;
  end;

  // �������� ���������� ���� ��� ��������� PIDL �������
  PIDL := SHBrowseForFolder(BrowseInfo);
  // ����������� PIDL � ���� � �����
  SHGetPathFromIDList(PIDL, Buf);
  Result := StrPas(Buf);
end;

// ��������� ���������� � DLL �� �������� ��������
procedure TAPI.GetInfoDLL(TreeView: TTreeView);
var
  ListInfoDLL: TListInfoDLL;
begin
  TreeView.Items.Clear;

  ListInfoDLL := TListInfoDLL.Create;
  try
    ListInfoDLL.SearchInfo;
    ListInfoDLL.SaveInfoToTreeView(TreeView);
  finally
    // ��� ������� ������ ����� ���������� ������������� (�.�. OwnsObjects = True)
    ListInfoDLL.Clear;
    ListInfoDLL.Free;
  end;

  // ���������� ���������� ����� � ������
  TreeView.SortType := stText;
  TreeView.AlphaSort(True);

  // ������������� ��� ���� � ������
  TreeView.FullExpand;
end;

end.
