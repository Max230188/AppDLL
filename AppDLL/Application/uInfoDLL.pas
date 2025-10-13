unit uInfoDLL;

interface

uses
  ShareMem, System.Classes, System.Types, System.IOUtils, System.SysUtils,
  System.Generics.Collections, Winapi.Windows, Vcl.ComCtrls;

type
  // Класс для хранения информации о DLL.
  // Наследуем от TPersistent для published свойств.
  TInfoDLL = class(TPersistent)
  private
    fNameDLL: string;

  public
    NameTaskList: TStringList;

  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadNameTaskList;

  published
    property NameDLL: string read fNameDLL write fNameDLL;
  end;

  // Класс содержащий информацию о всех DLL
  TListInfoDLL = class(TObjectList<TInfoDLL>)
  public
    procedure SearchInfo;

    procedure SaveInfoToStrings(Value: TStrings);
    procedure SaveInfoToListView(Value: TListView);
    procedure SaveInfoToTreeView(Value: TTreeView);
  end;

implementation

// -----------------------------TInfoDLL---------------------------------------

// конструктор для TInfoDLL
constructor TInfoDLL.Create;
begin
  inherited;

  NameTaskList := TStringList.Create;
end;

// деструктор для TInfoDLL
destructor TInfoDLL.Destroy;
begin
  NameTaskList.Free;

  inherited;
end;

// загрузка списка экспортируемых функций (задач) из DLL
procedure TInfoDLL.LoadNameTaskList;
type
  // объявляем прототип импортируемой функции
  TGetFuncList = procedure(out FuncList: TStringList); stdcall;
var
  GetFuncList: TGetFuncList;
  hLib: THandle;
begin
  // загружаем DLL в память
  hLib := LoadLibrary(PWideChar(NameDLL));

  if hLib <> 0 then
  begin
    try
      // получаем адрес функции из DLL
      GetFuncList := GetProcAddress(hLib, 'GetFuncList');
      if @GetFuncList <> nil then
      begin
        // запускаем функцию на выполнение
        GetFuncList(NameTaskList);
      end;
    finally
      // выгружаем DLL из памяти
      FreeLibrary(hLib);
    end;
  end;
end;

// -----------------------------TListInfoDLL----------------------------------

// поиск DLL в текущем каталоге и получение списка экспортируемых функций
procedure TListInfoDLL.SearchInfo;
var
  FilesList: TStringDynArray;
  StrFile: string;
  InfoDLL: TInfoDLL;
begin
  FilesList := TDirectory.GetFiles(TDirectory.GetCurrentDirectory, '*.dll');

  for StrFile in FilesList do
  begin
    InfoDLL := TInfoDLL.Create;
    InfoDLL.NameDLL := TPath.GetFileName(StrFile);
    InfoDLL.LoadNameTaskList;
    if InfoDLL.NameTaskList.Count > 0 then
      Add(InfoDLL)
    else
      InfoDLL.Free;
  end;
end;

// сохранение информации о DLL в свойстве типа TStrings
procedure TListInfoDLL.SaveInfoToStrings(Value: TStrings);
var
  InfoDLL: TInfoDLL;
  NameTask: string;
begin
  for InfoDLL in Self do
  begin
    Value.Add(InfoDLL.NameDLL);

    for NameTask in InfoDLL.NameTaskList do
      Value.Add('  ' + NameTask);
    Value.Add('');
  end;
end;

// сохранение информации о DLL в компоненте TListView
procedure TListInfoDLL.SaveInfoToListView(Value: TListView);
var
  InfoDLL: TInfoDLL;
  NameTask: string;
  ListGroup: TListGroup;
  ListItem: TListItem;
  MaxID: integer;
begin
  MaxID := 0;
  Value.ViewStyle := vsReport;
  Value.GroupView := True;

  for InfoDLL in Self do
  begin
    ListGroup := Value.Groups.Add;
    ListGroup.Header := InfoDLL.NameDLL;
    ListGroup.GroupID := MaxID + 1;

    for NameTask in InfoDLL.NameTaskList do
    begin
      ListItem := Value.Items.Add;
      ListItem.GroupID := ListGroup.GroupID;
      ListItem.Caption := NameTask;
    end;
  end;
end;

// сохранение информации о DLL в компоненте TTreeView
procedure TListInfoDLL.SaveInfoToTreeView(Value: TTreeView);
var
  InfoDLL: TInfoDLL;
  NameTask: string;
  ParentNode: TTreeNode;
begin
  for InfoDLL in Self do
  begin
    ParentNode := Value.Items.Add(nil, InfoDLL.NameDLL);

    for NameTask in InfoDLL.NameTaskList do
      Value.Items.AddChild(ParentNode, NameTask);
  end;
end;

end.
