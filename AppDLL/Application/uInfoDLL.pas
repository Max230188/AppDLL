unit uInfoDLL;

interface

uses
  ShareMem, System.Classes, System.Types, System.IOUtils, System.SysUtils,
  System.Generics.Collections, Winapi.Windows, Vcl.ComCtrls;

type
  // ����� ��� �������� ���������� � DLL.
  // ��������� �� TPersistent ��� published �������.
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

  // ����� ���������� ���������� � ���� DLL
  TListInfoDLL = class(TObjectList<TInfoDLL>)
  public
    procedure SearchInfo;

    procedure SaveInfoToStrings(Value: TStrings);
    procedure SaveInfoToListView(Value: TListView);
    procedure SaveInfoToTreeView(Value: TTreeView);
  end;

implementation

// -----------------------------TInfoDLL---------------------------------------

// ����������� ��� TInfoDLL
constructor TInfoDLL.Create;
begin
  inherited;

  NameTaskList := TStringList.Create;
end;

// ���������� ��� TInfoDLL
destructor TInfoDLL.Destroy;
begin
  NameTaskList.Free;

  inherited;
end;

// �������� ������ �������������� ������� (�����) �� DLL
procedure TInfoDLL.LoadNameTaskList;
type
  // ��������� �������� ������������� �������
  TGetFuncList = procedure(out FuncList: TStringList); stdcall;
var
  GetFuncList: TGetFuncList;
  hLib: THandle;
begin
  // ��������� DLL � ������
  hLib := LoadLibrary(PWideChar(NameDLL));

  if hLib <> 0 then
  begin
    try
      // �������� ����� ������� �� DLL
      GetFuncList := GetProcAddress(hLib, 'GetFuncList');
      if @GetFuncList <> nil then
      begin
        // ��������� ������� �� ����������
        GetFuncList(NameTaskList);
      end;
    finally
      // ��������� DLL �� ������
      FreeLibrary(hLib);
    end;
  end;
end;

// -----------------------------TListInfoDLL----------------------------------

// ����� DLL � ������� �������� � ��������� ������ �������������� �������
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

// ���������� ���������� � DLL � �������� ���� TStrings
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

// ���������� ���������� � DLL � ���������� TListView
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

// ���������� ���������� � DLL � ���������� TTreeView
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
