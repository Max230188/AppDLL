unit uMain;

interface

uses
  ShareMem, System.Classes, System.SysUtils, System.Variants, Winapi.Windows,
  Winapi.Messages, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Buttons, Vcl.Grids, Vcl.StdCtrls, uDM, uAPI,
  uTaskThread;

type
  TfrmMain = class(TForm)
    pnlListDLL: TPanel;
    pnlListTask: TPanel;
    pnlRunningTask: TPanel;
    pnlCompletedTask: TPanel;
    SplitterTop: TSplitter;
    SplitterLeft: TSplitter;
    tvListDLL: TTreeView;
    sgdRunningTask: TStringGrid;
    sgdCompletedTask: TStringGrid;
    lbRunningTask: TLabel;
    lbCompletedTask: TLabel;
    procedure FormShow(Sender: TObject);
    procedure tvListDLLAdvancedCustomDrawItem(Sender: TCustomTreeView;
      Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
      var PaintImages, DefaultDraw: Boolean);
    procedure pnlListDLLResize(Sender: TObject);
    procedure tvListDLLCollapsed(Sender: TObject; Node: TTreeNode);
    procedure tvListDLLExpanded(Sender: TObject; Node: TTreeNode);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure pnlRunningTaskCanResize(Sender: TObject;
      var NewWidth, NewHeight: Integer; var Resize: Boolean);
    procedure sgdRunningTaskDrawCell(Sender: TObject; ACol, ARow: LongInt;
      Rect: TRect; State: TGridDrawState);
    procedure FormResize(Sender: TObject);
    procedure FormCanResize(Sender: TObject; var NewWidth, NewHeight: Integer;
      var Resize: Boolean);
    procedure tvListDLLCompare(Sender: TObject; Node1, Node2: TTreeNode;
      Data: Integer; var Compare: Integer);
    procedure sgdRunningTaskTopLeftChanged(Sender: TObject);
  private
    function RoundToNearestMultiple(Value, N: Integer): Integer;
    procedure SetVisibleControls(StringGrid: TStringGrid); overload;
    procedure SetVisibleControls(TreeView: TTreeView); overload;
    function InsertRowInCompletedTask(TaskID: Word; NameTask, NameDLL: string;
      SpeedButtonResult, SpeedButtonLog: TSpeedButton): Integer;
    function InsertRowInRunningTask(TaskID: Word; NameTask, NameDLL: string;
      ProgressBar: TProgressBar; SpeedButtonStop: TSpeedButton): Integer;
    procedure DeleteRowInRunningTask(RowIndex: Integer);
    function SearchRowInRunningTask(TaskID: Word): Integer;
  public
    procedure SpeedButtonStartClick(Sender: TObject);
    procedure SpeedButtonStopClick(Sender: TObject);
    procedure SpeedButtonResultClick(Sender: TObject);
    procedure SpeedButtonLogClick(Sender: TObject);
    procedure TaskThreadTerminate(Sender: TObject);
  end;

  TArrayInt = array of Integer;

var
  frmMain: TfrmMain;
  NodeFirstRectTop: Integer;
  NewTaskID: Word;
  API: TAPI;

implementation

{$R *.dfm}

// ������� �������� ����� frmMain
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  API := TAPI.Create;
end;

// ������� �������� ����� frmMain
procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  API.Free;
end;

// ������� ������ ����� frmMain
procedure TfrmMain.FormShow(Sender: TObject);
begin
  sgdRunningTask.Cells[0, 0] := 'ID';
  sgdRunningTask.Cells[1, 0] := 'Task';
  sgdRunningTask.Cells[2, 0] := 'DLL';
  sgdRunningTask.Cells[3, 0] := 'Progress';
  sgdRunningTask.Cells[4, 0] := 'Action';

  sgdCompletedTask.Cells[0, 0] := 'ID';
  sgdCompletedTask.Cells[1, 0] := 'Task';
  sgdCompletedTask.Cells[2, 0] := 'DLL';
  sgdCompletedTask.Cells[3, 0] := 'Result';
  sgdCompletedTask.Cells[4, 0] := 'Log';

  dmAppData.acUpdateListDLL.Execute;

  // ������ ������������ ������ �����
  frmMain.Constraints.MaxHeight := RoundToNearestMultiple(Screen.Height,
    sgdRunningTask.RowHeights[1] + 2) - 3 * (sgdRunningTask.RowHeights[1] + 2);
end;

// ������� ��������� � Value ����� ������� N
function TfrmMain.RoundToNearestMultiple(Value, N: Integer): Integer;
begin
  if (N = 0) or (Value mod N = 0) then
    Result := Value
  else
    Result := Round(Value / N) * N;
end;

// ������� ����� ���������� �������� �����
procedure TfrmMain.FormCanResize(Sender: TObject;
  var NewWidth, NewHeight: Integer; var Resize: Boolean);
begin
  // ������������ ������ ����� (������ �� ������� ������ ����� ������ �������)
  NewHeight := RoundToNearestMultiple(NewHeight,
    sgdRunningTask.RowHeights[1] + 2);
end;

// ������� ����� ��������� �������� �����
procedure TfrmMain.FormResize(Sender: TObject);
begin
  if frmMain.WindowState = TWindowState.wsNormal then
    pnlRunningTask.Height := Round(frmMain.Height / 3);
end;

// ���������� ������ �� ���������� TTreeView
procedure TfrmMain.tvListDLLAdvancedCustomDrawItem(Sender: TCustomTreeView;
  Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
  var PaintImages, DefaultDraw: Boolean);
var
  TreeView: TTreeView;
  NodeFirst: TTreeNode;
  NodeRect, NodeFirstRect: TRect;
begin
  TreeView := TTreeView(Sender);

  if (Stage = cdPostPaint) and (Node.Data <> nil) then
  begin
    NodeRect := Node.DisplayRect(True);
    TSpeedButton(Node.Data).Left := NodeRect.Right + 5;
    TSpeedButton(Node.Data).Top := NodeRect.Top;
    TSpeedButton(Node.Data).Width := Sender.ClientWidth - (NodeRect.Right + 5);
    TSpeedButton(Node.Data).Height := NodeRect.Bottom - NodeRect.Top;
    TSpeedButton(Node.Data).Caption := 'Start';
    SetVisibleControls(TreeView);
  end;

  // �������������� TreeView � ������ ����������
  if (Stage = cdPostPaint) then
  begin
    NodeFirst := TreeView.Items.GetFirstNode;
    NodeFirstRect := NodeFirst.DisplayRect(True);

    if (NodeFirstRect.Top <> NodeFirstRectTop) then
    begin
      NodeFirstRectTop := NodeFirstRect.Top;
      TreeView.Items.BeginUpdate;
      TreeView.Repaint;
      TreeView.Items.EndUpdate;
    end;
  end;
end;

// ����������� ������ ��������� ��� ������ ������������� TTreeView
procedure TfrmMain.SetVisibleControls(TreeView: TTreeView);
var
  Node: TTreeNode;
  NodeRect, ViewRect: TRect;
begin
  // ������� ������� TreeView
  ViewRect := TreeView.BoundsRect;

  Node := TreeView.Items.GetFirstNode;

  while Node <> nil do
  begin
    if Node.Data <> nil then
    begin
      // ������� ���������� ����� (���������� �� ��� ���������)
      NodeRect := Node.DisplayRect(True);

      // ��������, ��������� �� ���� ��� ������� �������
      if (NodeRect.Top > ViewRect.Bottom) or (NodeRect.Bottom < ViewRect.Top) or
        (NodeRect.Left > ViewRect.Right) or (NodeRect.Right < ViewRect.Left)
      then
        // ���� �� �����
        TSpeedButton(Node.Data).Visible := False
      else
        // ���� �����
        TSpeedButton(Node.Data).Visible := True;
    end;

    Node := Node.GetNext;
  end;
end;

// ������� ���������� ����� � TTreeView
procedure TfrmMain.tvListDLLCompare(Sender: TObject; Node1, Node2: TTreeNode;
  Data: Integer; var Compare: Integer);
// ����������� ������ � ������ ����� �����
  function StringToIntArray(Str: string): TArrayInt;
  var
    i, j: Integer;
    Buf: string;
  begin
    j := 0;
    Buf := '';
    for i := 1 to High(Str) do
    begin
      case Str[i] of
        '0' .. '9':
          begin
            Buf := Buf + Str[i];
          end;
      else
        begin
          if Buf <> '' then
          begin
            Inc(j);
            SetLength(Result, j);
            Result[j - 1] := StrToInt(Buf);
            Buf := '';
          end;

          Inc(j);
          SetLength(Result, j);
          Result[j - 1] := Ord(Str[i]);
        end;
      end;
    end;
  end;

var
  ArrNode1, ArrNode2: TArrayInt;
  i, NumCount: Integer;
begin
  ArrNode1 := StringToIntArray(Node1.Text);
  ArrNode2 := StringToIntArray(Node2.Text);
  if Length(ArrNode1) <= Length(ArrNode2) then
    NumCount := Length(ArrNode1) - 1
  else
    NumCount := Length(ArrNode2) - 1;

  for i := 0 to NumCount do
  begin
    if ArrNode1[i] > ArrNode2[i] then
    begin
      Compare := 1;
      Break;
    end
    else if ArrNode1[i] < ArrNode2[i] then
    begin
      Compare := -1;
      Break;
    end
    else
      Compare := 0;
  end;
end;

// ������� ������������ ���� TTreeView
procedure TfrmMain.tvListDLLCollapsed(Sender: TObject; Node: TTreeNode);
begin
  tvListDLL.Items.BeginUpdate;
  tvListDLL.Repaint;
  tvListDLL.Items.EndUpdate;
end;

// ������� �������������� ���� TTreeView
procedure TfrmMain.tvListDLLExpanded(Sender: TObject; Node: TTreeNode);
begin
  tvListDLL.Items.BeginUpdate;
  tvListDLL.Repaint;
  tvListDLL.Items.EndUpdate;
end;

// ������� ��������� �������� ������ pnlListDLL
procedure TfrmMain.pnlListDLLResize(Sender: TObject);
begin
  tvListDLL.Items.BeginUpdate;
  tvListDLL.Repaint;
  tvListDLL.Items.EndUpdate;
end;

// ������� ����� ���������� �������� ������� pnlRunningTask � pnlCompletedTask
procedure TfrmMain.pnlRunningTaskCanResize(Sender: TObject;
  var NewWidth, NewHeight: Integer; var Resize: Boolean);
var
  i, j: Integer;
  OffSet: Integer;
  Panel: TPanel;
  StringGrid: TStringGrid;
begin
  Panel := TPanel(Sender);

  OffSet := Round((NewWidth - Panel.Width) / 5);

  for i := 0 to Panel.ControlCount - 1 do
  begin
    if Panel.Controls[i] is TStringGrid then
    begin
      StringGrid := Panel.Controls[i] as TStringGrid;

      // ������������ �������
      for j := 0 to StringGrid.ColCount - 1 do
        StringGrid.ColWidths[j] := StringGrid.ColWidths[j] + OffSet;

      // ������������ ������ ������� (������ �� ������� ������ ����� ������)
      NewHeight := RoundToNearestMultiple(NewHeight,
        StringGrid.RowHeights[1] + 2);
    end;
  end;
end;

// ������� ��������� ������ �� �������� sgdRunningTask � sgdCompletedTask
procedure TfrmMain.sgdRunningTaskTopLeftChanged(Sender: TObject);
var
  StringGrid: TStringGrid;
begin
  StringGrid := TStringGrid(Sender);

  StringGrid.BeginUpdate;
  StringGrid.Repaint;
  StringGrid.EndUpdate;
end;

// ���������� ��������� �� ���������� sgdRunningTask � sgdCompletedTask
procedure TfrmMain.sgdRunningTaskDrawCell(Sender: TObject; ACol, ARow: LongInt;
  Rect: TRect; State: TGridDrawState);
var
  StringGrid: TStringGrid;
begin
  StringGrid := TStringGrid(Sender);

  if (StringGrid.Objects[ACol, ARow] <> nil) and
    (StringGrid.Objects[ACol, ARow] is TControl) then
  begin
    TControl(StringGrid.Objects[ACol, ARow]).Left := Rect.Left;
    TControl(StringGrid.Objects[ACol, ARow]).Top := Rect.Top;
    TControl(StringGrid.Objects[ACol, ARow]).Width := Rect.Right - Rect.Left;
    TControl(StringGrid.Objects[ACol, ARow]).Height := Rect.Bottom - Rect.Top;
    SetVisibleControls(StringGrid);
  end;
end;

// ����������� ������ ��������� ��� ��������� ������������� TStringGrid
procedure TfrmMain.SetVisibleControls(StringGrid: TStringGrid);
var
  stCol, stRow: Integer;
begin
  with StringGrid do
    for stRow := 1 to RowCount - 1 do
      for stCol := 0 to ColCount - 1 do
        if (Objects[stCol, stRow] <> nil) and (Objects[stCol, stRow] is TControl)
        then
          if (stRow < TopRow) or (stRow > TopRow + VisibleRowCount - 1) or
            (stCol < LeftCol) or (stCol > LeftCol + VisibleColCount - 1) then
            TControl(Objects[stCol, stRow]).Visible := False
          else
            TControl(Objects[stCol, stRow]).Visible := True;
end;

// ���������� ������ � ������ ����������� ����� (sgdCompletedTask)
// ������� ���������� ������ ����������� ������
function TfrmMain.InsertRowInCompletedTask(TaskID: Word;
  NameTask, NameDLL: string; SpeedButtonResult, SpeedButtonLog
  : TSpeedButton): Integer;
var
  RowIndex: Integer;
begin
  RowIndex := sgdCompletedTask.RowCount - 1;

  with sgdCompletedTask do
  begin
    Cells[0, RowIndex] := TaskID.ToString;
    Cells[1, RowIndex] := NameTask;
    Cells[2, RowIndex] := NameDLL;
    Objects[3, RowIndex] := SpeedButtonResult;
    Objects[4, RowIndex] := SpeedButtonLog;
    RowCount := RowCount + 1;
    // �������� ����� ������ � ������������ � ���
    Row := RowIndex;
    Selection := TGridRect(Rect(FixedCols, RowIndex, ColCount - 1, RowIndex));
    SetFocus;
  end;

  Result := RowIndex;
end;

// ���������� ������ � ������ ���������� ����� (sgdRunningTask)
// ������� ���������� ������ ����������� ������
function TfrmMain.InsertRowInRunningTask(TaskID: Word;
  NameTask, NameDLL: string; ProgressBar: TProgressBar;
  SpeedButtonStop: TSpeedButton): Integer;
var
  RowIndex: Integer;
begin
  RowIndex := sgdRunningTask.RowCount - 1;

  with sgdRunningTask do
  begin
    Cells[0, RowIndex] := TaskID.ToString;
    Cells[1, RowIndex] := NameTask;
    Cells[2, RowIndex] := NameDLL;
    Objects[3, RowIndex] := ProgressBar;
    Objects[4, RowIndex] := SpeedButtonStop;
    RowCount := RowCount + 1;
    // �������� ����� ������ � ������������ � ���
    Row := RowIndex;
    Selection := TGridRect(Rect(FixedCols, RowIndex, ColCount - 1, RowIndex));
    SetFocus;
  end;

  Result := RowIndex;
end;

// �������� ������ �� ������� ���������� ����� (sgdRunningTask)
procedure TfrmMain.DeleteRowInRunningTask(RowIndex: Integer);
var
  ProgressBar: TProgressBar;
  SpeedButtonStop: TSpeedButton;
  stCol, stRow: Integer;
begin
  with sgdRunningTask do
  begin
    ProgressBar := Objects[3, RowIndex] as TProgressBar;
    SpeedButtonStop := Objects[4, RowIndex] as TSpeedButton;

    for stRow := RowIndex + 1 to RowCount - 1 do
      for stCol := 0 to ColCount - 1 do
      begin
        Objects[stCol, stRow - 1] := Objects[stCol, stRow];
        Cells[stCol, stRow - 1] := Cells[stCol, stRow];
      end;

    RowCount := RowCount - 1;

    ProgressBar.Free;
    SpeedButtonStop.Free;
  end;
end;

// ����� ������ � ������ ���������� ����� (sgdRunningTask)
// ������� ���������� ������ ��������� ������
function TfrmMain.SearchRowInRunningTask(TaskID: Word): Integer;
var
  stRow: Integer;
begin
  Result := -1;

  with sgdRunningTask do
    for stRow := 0 to RowCount - 1 do
      if Cells[0, stRow] = TaskID.ToString then
      begin
        Result := stRow;
        Break;
      end;
end;

// ���������� ������� ������� �� ������ Start
procedure TfrmMain.SpeedButtonStartClick(Sender: TObject);
var
  NameTask, NameDLL: string;
  ProgressBar: TProgressBar;
  SpeedButtonStart, SpeedButtonStop: TSpeedButton;
  TreeNodeTask, TreeNodeDLL: TTreeNode;
  X, Y, RowIndex: Integer;
begin
  // ���������� ��� ������ � �� DLL
  SpeedButtonStart := TSpeedButton(Sender);
  X := SpeedButtonStart.Left - 20;
  Y := SpeedButtonStart.Top + 5;
  TreeNodeTask := tvListDLL.GetNodeAt(X, Y);
  TreeNodeDLL := TreeNodeTask.Parent;
  NameTask := TreeNodeTask.Text;
  NameDLL := TreeNodeDLL.Text;

  // ��������� ������ � ������� ���������� ����� (sgdRunningTask)
  NewTaskID := NewTaskID + 1;
  ProgressBar := TProgressBar.Create(sgdRunningTask);
  ProgressBar.Parent := sgdRunningTask;
  SpeedButtonStop := TSpeedButton.Create(sgdRunningTask);
  SpeedButtonStop.Caption := 'Stop';
  SpeedButtonStop.Tag := NewTaskID;
  SpeedButtonStop.OnClick := SpeedButtonStopClick;
  SpeedButtonStop.Parent := sgdRunningTask;
  RowIndex := InsertRowInRunningTask(NewTaskID, NameTask, NameDLL, ProgressBar,
    SpeedButtonStop);

  // �������� ������, ��������� ���������� �� ���� � ������ ������
  if not API.StartTask(NewTaskID, NameDLL, NameTask, ProgressBar) then
    DeleteRowInRunningTask(RowIndex);
end;

// ���������� ������� ������� �� ������ Stop
procedure TfrmMain.SpeedButtonStopClick(Sender: TObject);
begin
  API.StopTask(TSpeedButton(Sender).Tag);
end;

// ���������� ������� ������� �� ������ Result
procedure TfrmMain.SpeedButtonResultClick(Sender: TObject);
begin
  API.GetTaskResult(TSpeedButton(Sender).Tag);
end;

// ���������� ������� ������� �� ������ Log
procedure TfrmMain.SpeedButtonLogClick(Sender: TObject);
begin
  API.GetTaskLog(TSpeedButton(Sender).Tag);
end;

// ���������� ������� ���������� ������ ������
// ��������� ������ � ������� ����������� ����� (sgdCompletedTask)
procedure TfrmMain.TaskThreadTerminate(Sender: TObject);
var
  TaskThread: TTaskThread;
  RowIndex: Integer;
  TaskID: Word;
  NameTask, NameDLL: string;
  SpeedButtonResult, SpeedButtonLog: TSpeedButton;
begin
  TaskThread := TTaskThread(Sender);
  TaskID := TaskThread.Task.ID;

  RowIndex := SearchRowInRunningTask(TaskID);

  if RowIndex <> -1 then
  begin
    NameTask := sgdRunningTask.Cells[1, RowIndex];
    NameDLL := sgdRunningTask.Cells[2, RowIndex];

    SpeedButtonResult := TSpeedButton.Create(sgdCompletedTask);
    SpeedButtonResult.Caption := 'Result';
    SpeedButtonResult.Tag := TaskID;
    SpeedButtonResult.OnClick := SpeedButtonResultClick;
    SpeedButtonResult.Parent := sgdCompletedTask;

    SpeedButtonLog := TSpeedButton.Create(sgdCompletedTask);
    SpeedButtonLog.Caption := 'Log';
    SpeedButtonLog.Tag := TaskID;
    SpeedButtonLog.OnClick := SpeedButtonLogClick;
    SpeedButtonLog.Parent := sgdCompletedTask;

    InsertRowInCompletedTask(TaskID, NameTask, NameDLL, SpeedButtonResult,
      SpeedButtonLog);

    DeleteRowInRunningTask(RowIndex);
  end;

  // ���������� ������ TaskThread ����� ������ �������������
  if TaskThread.FreeOnTerminate then
    API.DeleteTaskThreadFromList(TaskThread);
end;

end.
