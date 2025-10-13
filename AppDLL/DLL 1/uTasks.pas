unit uTasks;

interface

uses
  ShareMem, System.Classes, System.Types, System.IOUtils, System.SysUtils,
  System.StrUtils, System.Generics.Collections, System.SyncObjs, Vcl.Forms;

type
  // Анонимные процедуры (используются как процедуры обратного вызова)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // Поиск файлов в заданном каталоге по максе.
  // Возвращает количество найденных файлов и их полные пути.
  // Отслеживается запуск, завершение и прогресс выполнения задачи.
function SearchFiles(App: TApplication; SourcePath, MaskFiles: String;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out FilesPath: TStringList): integer; stdcall; export;

// Поиск последовательности символов в файле.
// Взвращает количество найденных вхождений и их позиции.
// Отслеживается запуск, завершение и прогресс выполнения задачи.
function SearchSequence(App: TApplication; SourceFile, Sequence: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out PosSequence: TDictionary<String, String>): integer;
  stdcall; export;

// Возвращает список функций которые экспортирует DLL
procedure GetFuncList(out FuncList: TStringList); stdcall; export;

implementation

// Разбиение строки на массив строк
// В качестве разделителя используется ','
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
    for i := 1 to High(SrcStr) do // перебираем все символы в строке
    begin
      if SrcStr[i] = ',' then // найден разделитель строк
      begin
        Buf := Trim(Buf);
        if Buf <> '' then // сохраняем в массиве текущую подстроку
        begin
          Inc(j);
          SetLength(Result, j);
          Result[j - 1] := Buf;
          Buf := '';
        end;
      end
      else // формируем подстроку
        Buf := Buf + SrcStr[i];
    end;

    // сохраняем в массиве последнюю подстроку
    Buf := Trim(Buf);
    if (Buf <> '') then
    begin
      SetLength(Result, j + 1);
      Result[j] := Buf;
    end;
  end;
end;

// Удаление дубликатов строк из динамического массива
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
      if SrcMas[i] = SrcMas[j] then // дубликат найден
      begin
        Flag := True;
        break;
      end;
    end;

    if not Flag then // дубликат не найден
    begin
      Inc(k);
      SetLength(Result, k);
      Result[k - 1] := SrcMas[i];
    end;
  end;
end;

// Определение кодировки файла
function GetCodePageForFile(SourceFile: string): TEncoding;
var
  BytesStream: TBytesStream;
  Buf: TBytes;
  SizeBOM: integer; // размер BOM-маркера
begin
  BytesStream := TBytesStream.Create;
  try
    BytesStream.LoadFromFile(SourceFile);
    Buf := BytesStream.Bytes;

    Result := nil; // для правильной работы GetBufferEncoding
    // определяем кодировку по BOM-маркерам (первые несколько символов в файле)
    SizeBOM := TEncoding.GetBufferEncoding(Buf, Result, TEncoding.Default);

    // проверяем кодировки без использования BOM-маркеров (порядок проверки важен)
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

      // перебираем все маски
      for StrMask in MaskList do
      begin
        // ищем файлы в текущей папке
        FilesList := TDirectory.GetFiles(SourcePath, StrMask);
        MaxProgress := MaxProgress + Length(FilesList);
        for StrFile in FilesList do
        begin
          FilesPath.Add(StrFile);
          Progress := Progress + 1;
          CallBackProgress(Progress, MaxProgress);
          CallBackLog('Найден файл ' + StrFile);
          App.ProcessMessages; // чтобы форма не зависала
          if App.Terminated or StopFlag then
            Exit;
        end;

        // ищем файлы в подпапках
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
            CallBackLog('Найден файл ' + StrFile);
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
      CallBackLog('Путь к каталогу задан некорректно!');
  finally
    Result := FilesPath.Count;
    CallBackProgress(Progress, MaxProgress);
    CallBackLog('Количество найденных файлов: ' + IntToStr(Result));
    if StopFlag then
      CallBackLog('Поиск прерван пользователем!');
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

      // перебираем все последовательности
      for StrSequence in SequenceList do
      begin
        PosSequence.Add(StrSequence, ''); // добавляем ключ
        StrSequenceLength := Length(StrSequence);
        AllStrLength := 0;

        // перебираем все строки в файле
        for StrText in TextList do
        begin
          StrTextLength := Length(StrText);

          // ищем совпадения с последовательностью
          i := 1;
          repeat
            j := PosEx(StrSequence, StrText, i);
            if j <> 0 then
            begin
              Inc(Result);
              PosSequence.Items[StrSequence] := PosSequence.Items[StrSequence] +
                ', ' + IntToStr(j + AllStrLength);
              // добавляем значения по ключу
              i := j + StrSequenceLength;
              CallBackLog('Найдено новое вхождение последовательности ' +
                StrSequence + ': ' + IntToStr(j + AllStrLength));
              App.ProcessMessages;
              if App.Terminated or StopFlag then
                Exit;
            end
            else
              // прерываем цикл
              break;
          until i > StrTextLength - StrSequenceLength;

          // учитываем длинну всех предыдущих строк и символ конца строки
          AllStrLength := AllStrLength + StrTextLength + 1;
          Progress := Progress + 1;
          CallBackProgress(Progress, MaxProgress);
          App.ProcessMessages;

          if App.Terminated or StopFlag then
            Exit;
        end;

        // удаляем запятую в начале списка
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
      CallBackLog('Путь к файлу задан некорректно!');
  finally
    CallBackProgress(Progress, MaxProgress);
    CallBackLog('Количество найденных вхождений: ' + IntToStr(Result));
    if StopFlag then
      CallBackLog('Поиск прерван пользователем!');
    App.ProcessMessages;
  end;
end;

procedure GetFuncList(out FuncList: TStringList);
begin
  FuncList.Add('SearchFiles');
  FuncList.Add('SearchSequence');
end;

end.
