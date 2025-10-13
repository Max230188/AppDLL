unit uDM;

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, System.Actions, Vcl.ActnList,
  Vcl.Buttons, Vcl.Controls, Vcl.Grids;

type
  TdmAppData = class(TDataModule)
    mmAppMenu: TMainMenu;
    miUpdateListDLL: TMenuItem;
    miClearRunningTask: TMenuItem;
    miClearCompletedTask: TMenuItem;
    aclAppAction: TActionList;
    acUpdateListDLL: TAction;
    acClearRunningTask: TAction;
    acClearCompletedTask: TAction;
    procedure acUpdateListDLLExecute(Sender: TObject);
    procedure acClearRunningTaskExecute(Sender: TObject);
    procedure acClearCompletedTaskExecute(Sender: TObject);
  private
    procedure ClearStringGrid(StringGrid: TStringGrid);
  public
    { Public declarations }
  end;

var
  dmAppData: TdmAppData;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

uses uMain; // обязательно объявлять после директив, иначе проект слетит !!!!!!!

// обновление списка DLL в TTreeView
procedure TdmAppData.acUpdateListDLLExecute(Sender: TObject);
var
  i: Integer;
  SpeedButtonStart: TSpeedButton;
begin
  with frmMain do
  begin
    // удаляем все кнопки принадлежашие TTreeView
    for i := tvListDLL.ControlCount - 1 downto 0 do
      tvListDLL.Controls[i].Free;

    // получение информации о DLL из текущего каталога
    API.GetInfoDLL(tvListDLL);

    // связывание узлов TTreeView с кнопками
    for i := 0 to tvListDLL.Items.Count - 1 do
    begin
      if tvListDLL.Items[i].HasChildren then
        Continue;

      SpeedButtonStart := TSpeedButton.Create(tvListDLL);
      SpeedButtonStart.OnClick := SpeedButtonStartClick;
      tvListDLL.Items[i].Data := SpeedButtonStart;
      SpeedButtonStart.Parent := tvListDLL;
    end;
  end;
end;

// очистка таблицы TStringGrid
procedure TdmAppData.ClearStringGrid(StringGrid: TStringGrid);
var
  stCol, stRow: Integer;
  i: Integer;
begin
  with StringGrid do
  begin
    // очищаем сетку StringGrid
    for stRow := 1 to RowCount - 1 do
      for stCol := 0 to ColCount - 1 do
        if (Objects[stCol, stRow] <> nil) and (Objects[stCol, stRow] is TControl)
        then
          Objects[stCol, stRow] := nil
        else
          Cells[stCol, stRow] := '';

    // удаляем строки в StringGrid
    RowCount := 2;

    // удаляем все контролы принадлежашие StringGrid
    for i := ControlCount - 1 downto 0 do
      Controls[i].Free;
  end;
end;

// очистка списка запущенных задач в sgdRunningTask
procedure TdmAppData.acClearRunningTaskExecute(Sender: TObject);
begin
  API.StopAllTask;
  ClearStringGrid(frmMain.sgdRunningTask);
end;

// очистка списка запущенных задач в sgdCompletedTask
procedure TdmAppData.acClearCompletedTaskExecute(Sender: TObject);
var
  stRow: Integer;
  TaskID: Word;
begin
  with frmMain do
  begin
    for stRow := 1 to sgdCompletedTask.RowCount - 2 do
    begin
      TaskID := sgdCompletedTask.Cells[0, stRow].ToInteger;
      API.DeleteTaskFromList(TaskID);
    end;

    ClearStringGrid(sgdCompletedTask);
  end;
end;

end.
