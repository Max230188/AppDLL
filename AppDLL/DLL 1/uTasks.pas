unit uTasks;

interface

uses
  ShareMem, System.Classes, System.Types, System.IOUtils, System.SysUtils,
  System.StrUtils, System.Generics.Collections, System.SyncObjs, Vcl.Forms;

type
  // ��������� ��������� (������������ ��� ��������� ��������� ������)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // ����� ������ � �������� �������� �� �����.
  // ���������� ���������� ��������� ������ � �� ������ ����.
  // ������������� ������, ���������� � �������� ���������� ������.
function SearchFiles(App: TApplication; SourcePath, MaskFiles: String;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out FilesPath: TStringList): integer; stdcall; export;

// ����� ������������������ �������� � �����.
// ��������� ���������� ��������� ��������� � �� �������.
// ������������� ������, ���������� � �������� ���������� ������.
function SearchSequence(App: TApplication; SourceFile, Sequence: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out PosSequence: TDictionary<String, String>): integer;
  stdcall; export;

// ���������� ������ ������� ������� ������������ DLL
procedure GetFuncList(out FuncList: TStringList); stdcall; export;

implementation

// ��������� ������ �� ������ �����
// � �������� ����������� ������������ ','
function ParsingString(SrcStr: string): TStringDynArray;
var
  Buf: string;
  i, j: integer;
begin
  SrcStr := Trim(SrcStr);
  if SrcStr <> '' then
  begin
    Buf := '';
    j := 0;
    for i := 1 to High(SrcStr) do // ���������� ��� ������� � ������
    begin
      if SrcStr[i] = ',' then // ������ ����������� �����
      begin
        Buf := Trim(Buf);
        if Buf <> '' then // ��������� � ������� ������� ���������
        begin
          Inc(j);
          SetLength(Result, j);
          Result[j - 1] := Buf;
          Buf := '';
        end;
      end
      else // ��������� ���������
        Buf := Buf + SrcStr[i];
    end;

    // ��������� � ������� ��������� ���������
    Buf := Trim(Buf);
    if (Buf <> '') then
    begin
      SetLength(Result, j + 1);
      Result[j] := Buf;
    end;
  end;
end;

// �������� ���������� ����� �� ������������� �������
function DelDuplicateMasStr(SrcMas: TStringDynArray): TStringDynArray;
var
  Flag: Boolean;
  i, j, k: integer;
begin
  k := 0;
  for i := 0 to High(SrcMas) do
  begin
    Flag := False;
    for j := i + 1 to High(SrcMas) do
    begin
      if SrcMas[i] = SrcMas[j] then // �������� ������
      begin
        Flag := True;
        break;
      end;
    end;

    if not Flag then // �������� �� ������
    begin
      Inc(k);
      SetLength(Result, k);
      Result[k - 1] := SrcMas[i];
    end;
  end;
end;

// ����������� ��������� �����
function GetCodePageForFile(SourceFile: string): TEncoding;
var
  BytesStream: TBytesStream;
  Buf: TBytes;
  SizeBOM: integer; // ������ BOM-�������
begin
  BytesStream := TBytesStream.Create;
  try
    BytesStream.LoadFromFile(SourceFile);
    Buf := BytesStream.Bytes;

    Result := nil; // ��� ���������� ������ GetBufferEncoding
    // ���������� ��������� �� BOM-�������� (������ ��������� �������� � �����)
    SizeBOM := TEncoding.GetBufferEncoding(Buf, Result, TEncoding.Default);

    // ��������� ��������� ��� ������������� BOM-�������� (������� �������� �����)
    if SizeBOM = 0 then
    begin
      if TEncoding.UTF8.IsBufferValid(Buf) then
      begin
        Result := TEncoding.UTF8;
        Exit;
      end;

      if TEncoding.UTF7.IsBufferValid(Buf) then
      begin
        Result := TEncoding.UTF7;
        Exit;
      end;

      if TEncoding.ASCII.IsBufferValid(Buf) then
      begin
        Result := TEncoding.ASCII;
        Exit;
      end;

      if TEncoding.ANSI.IsBufferValid(Buf) then
      begin
        Result := TEncoding.ANSI;
        Exit;
      end;

      if TEncoding.Unicode.IsBufferValid(Buf) then
      begin
        Result := TEncoding.Unicode;
        Exit;
      end;
    end;
  finally
    BytesStream.Free;
  end;
end;

function SearchFiles(App: TApplication; SourcePath, MaskFiles: String;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out FilesPath: TStringList): integer;
var
  PathList, FilesList, MaskList: TStringDynArray;
  StrPath, StrFile, StrMask: string;
  Progress, MaxProgress: integer;
begin
  Result := 0;
  Progress := 0;
  MaxProgress := 0;

  try
    if TDirectory.Exists(SourcePath) then
    begin
      MaskList := DelDuplicateMasStr(ParsingString(MaskFiles));

      // ���������� ��� �����
      for StrMask in MaskList do
      begin
        // ���� ����� � ������� �����
        FilesList := TDirectory.GetFiles(SourcePath, StrMask);
        MaxProgress := MaxProgress + Length(FilesList);
        for StrFile in FilesList do
        begin
          FilesPath.Add(StrFile);
          Progress := Progress + 1;
          CallBackProgress(Progress, MaxProgress);
          CallBackLog('������ ���� ' + StrFile);
          App.ProcessMessages; // ����� ����� �� ��������
          if App.Terminated or StopFlag then
            Exit;
        end;

        // ���� ����� � ���������
        PathList := TDirectory.GetDirectories(SourcePath,
          TSearchOption.soAllDirectories, nil);
        for StrPath in PathList do
        begin
          FilesList := TDirectory.GetFiles(StrPath, StrMask);
          MaxProgress := MaxProgress + Length(FilesList);
          for StrFile in FilesList do
          begin
            FilesPath.Add(StrFile);
            Progress := Progress + 1;
            CallBackProgress(Progress, MaxProgress);
            CallBackLog('������ ���� ' + StrFile);
            App.ProcessMessages;
            if App.Terminated or StopFlag then
              Exit;
          end;
          if App.Terminated or StopFlag then
            Exit;
        end;

        if App.Terminated or StopFlag then
          Exit;
      end;
    end
    else
      CallBackLog('���� � �������� ����� �����������!');
  finally
    Result := FilesPath.Count;
    CallBackProgress(Progress, MaxProgress);
    CallBackLog('���������� ��������� ������: ' + IntToStr(Result));
    if StopFlag then
      CallBackLog('����� ������� �������������!');
    App.ProcessMessages;
  end;
end;

function SearchSequence(App: TApplication; SourceFile, Sequence: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out PosSequence: TDictionary<String, String>): integer;
var
  TextList, SequenceList: TStringDynArray;
  StrText, StrSequence, S: String;
  StrTextLength, StrSequenceLength, AllStrLength: integer;
  Progress, MaxProgress: integer;
  CodePageFile: TEncoding;
  i, j: integer;
begin
  Result := 0;
  Progress := 0;
  MaxProgress := 0;

  try
    if TFile.Exists(SourceFile) then
    begin
      CodePageFile := GetCodePageForFile(SourceFile);
      TextList := TFile.ReadAllLines(SourceFile, CodePageFile);
      SequenceList := DelDuplicateMasStr(ParsingString(Sequence));
      MaxProgress := Length(SequenceList) * Length(TextList);

      // ���������� ��� ������������������
      for StrSequence in SequenceList do
      begin
        PosSequence.Add(StrSequence, ''); // ��������� ����
        StrSequenceLength := Length(StrSequence);
        AllStrLength := 0;

        // ���������� ��� ������ � �����
        for StrText in TextList do
        begin
          StrTextLength := Length(StrText);

          // ���� ���������� � �������������������
          i := 1;
          repeat
            j := PosEx(StrSequence, StrText, i);
            if j <> 0 then
            begin
              Inc(Result);
              PosSequence.Items[StrSequence] := PosSequence.Items[StrSequence] +
                ', ' + IntToStr(j + AllStrLength);
              // ��������� �������� �� �����
              i := j + StrSequenceLength;
              CallBackLog('������� ����� ��������� ������������������ ' +
                StrSequence + ': ' + IntToStr(j + AllStrLength));
              App.ProcessMessages;
              if App.Terminated or StopFlag then
                Exit;
            end
            else
              // ��������� ����
              break;
          until i > StrTextLength - StrSequenceLength;

          // ��������� ������ ���� ���������� ����� � ������ ����� ������
          AllStrLength := AllStrLength + StrTextLength + 1;
          Progress := Progress + 1;
          CallBackProgress(Progress, MaxProgress);
          App.ProcessMessages;

          if App.Terminated or StopFlag then
            Exit;
        end;

        // ������� ������� � ������ ������
        S := PosSequence.Items[StrSequence];
        if S.Length > 0 then
          if S[1] = ',' then
          begin
            Delete(S, 1, 1);
            PosSequence.Items[StrSequence] := S;
          end;

        if App.Terminated or StopFlag then
          Exit;
      end;
    end
    else
      CallBackLog('���� � ����� ����� �����������!');
  finally
    CallBackProgress(Progress, MaxProgress);
    CallBackLog('���������� ��������� ���������: ' + IntToStr(Result));
    if StopFlag then
      CallBackLog('����� ������� �������������!');
    App.ProcessMessages;
  end;
end;

procedure GetFuncList(out FuncList: TStringList);
begin
  FuncList.Add('SearchFiles');
  FuncList.Add('SearchSequence');
end;

end.
