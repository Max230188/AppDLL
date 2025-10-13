unit uTasks;

{ Для работы этой DLL необходимо установить последнюю версию архиватора 7-Zip }

interface

uses
  ShareMem, System.Types, System.Classes, System.SysUtils, System.IOUtils,
  System.StrUtils, Winapi.ShellAPI, Winapi.Windows, Vcl.Dialogs, Vcl.Forms;

type
  // Анонимные процедуры (используются как процедуры обратного вызова)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // Создание архива для заданного файла или директории с помощью ShellExecute
  // Возвращает код выполненной операции и соответствующее ему сообщение
  // Отслеживается только момент запуска задачи
function ShellCli(AppHandle: THandle; SourcePath: string;
  out ResultMessage: string): integer; stdcall; export;

// Создание архива для заданного файла или директории с помощью ShellExecuteEx
// Возвращает код выполненной операции и соответствующее ему сообщение
// Отслеживается запуск и завершение задачи
function ShellCliEx(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; var StopFlag: Boolean; out ResultMessage: string)
  : integer; stdcall; export;

// Создание архива для заданного файла или директории с помощью CreateProcess
// Возвращает код выполненной операции и соответствующее ему сообщение
// Отслеживается запуск, завершение и прогресс выполнения задачи
function ProcessCli(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out ResultMessage: string): integer; stdcall; export;

// Возвращает список функций которые экспортирует DLL
procedure GetFuncList(out FuncList: TStringList); stdcall; export;

implementation

// Поиск установленного в Windows архиватора 7-Zip
// Возвращает путь к файлу 7z.exe и логический результат
function SearchSevenZip(out SevenZipPath: string): Boolean;
var
  DriveList: TStringDynArray;
  StrDrive, Buf: string;
begin
  Result := False;
  // проверяем все логические диски по заданным путям
  DriveList := TDirectory.GetLogicalDrives;
  for StrDrive in DriveList do
  begin
    Buf := StrDrive + '\Program Files\7-Zip\7z.exe';
    if TFile.Exists(Buf) then
    begin
      SevenZipPath := Buf;
      Result := True;
      Break
    end;

    Buf := StrDrive + '\Program Files (x86)\7-Zip\7z.exe';
    if TFile.Exists(Buf) then
    begin
      SevenZipPath := Buf;
      Result := True;
      Break
    end;

    Buf := StrDrive + '\7-Zip\7z.exe';
    if TFile.Exists(Buf) then
    begin
      SevenZipPath := Buf;
      Result := True;
      Break
    end;
  end;
end;

function ShellCli(AppHandle: THandle; SourcePath: string;
  out ResultMessage: string): integer;
var
  SevenZipPath, CommandLine, ArchivePath: string;
begin
  // проверяем что архиватор 7-Zip установлен
  if SearchSevenZip(SevenZipPath) then
  begin
    // проверяем что заданный файл или директория существует
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // удаляем лишние символы
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // определяем путь для архива
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // код для командной строки
      CommandLine := Format('a "%s" "%s"', [ArchivePath, SourcePath]);

      // запускаем архивацию
      Result := ShellExecute(AppHandle, 'open', PChar(SevenZipPath),
        PChar(CommandLine), nil, SW_HIDE);

      // обрабатываем результат
      if Result > 32 then
        ResultMessage := 'Архивация запущена'
      else
        ResultMessage := 'Ошибка запуска архивации: №' + IntToStr(Result) + '!';
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := 'Путь к файлу/папки задан некорректно!';
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := 'Архиватор 7-Zip не найден!';
  end;
end;

function ShellCliEx(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; var StopFlag: Boolean;
  out ResultMessage: string): integer;
var
  ShellExecuteInfo: TShellExecuteInfo;
  ExitCode: DWord;
  ExitCodeStr: string;
  ProcessSuccess, ShellSuccess: BOOL;
  SevenZipPath, CommandLine, ArchivePath: string;
begin
  // проверяем что архиватор 7-Zip установлен
  if SearchSevenZip(SevenZipPath) then
  begin
    // проверяем что заданный файл или директория существует
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // удаляем лишние символы
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // определяем путь для архива
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // код для командной строки
      CommandLine := Format('a "%s" "%s"', [ArchivePath, SourcePath]);

      // очищаем структуру TShellExecuteInfo
      FillChar(ShellExecuteInfo, SizeOf(TShellExecuteInfo), 0);
      // заполняем структуру TShellExecuteInfo
      with ShellExecuteInfo do
      begin
        // размер структуры в байтах
        cbSize := SizeOf(TShellExecuteInfo);
        // дескриптор окна владельца
        Wnd := App.Handle;
        // этот флаг означает что hProcess получает дескриптор процесса
        fMask := SEE_MASK_NOCLOSEPROCESS;
        // запускаемое приложение
        lpFile := PChar(SevenZipPath);
        // командная строка
        lpParameters := PChar(CommandLine);
        // режим отображения окна
        nShow := SW_HIDE;
      end;

      try
        // запускаем архивацию
        ShellSuccess := ShellExecuteEx(@ShellExecuteInfo);

        // обрабатываем результат
        Result := ShellExecuteInfo.hInstApp;
        if Result > 32 then
        begin
          ResultMessage := 'Архивация запущена';
          CallBackLog(ResultMessage);
        end
        else
        begin
          ResultMessage := 'Ошибка запуска архивации: №' +
            IntToStr(Result) + '!';
          CallBackLog(ResultMessage);
          Exit;
        end;

        // мониторинг запущенного процесса
        if ShellSuccess and (ShellExecuteInfo.hProcess <> 0) then
        begin
          while (not App.Terminated) and (not StopFlag) do
          begin
            // проверяем, завершился ли процесс
            ProcessSuccess := GetExitCodeProcess(ShellExecuteInfo.hProcess,
              ExitCode);
            Result := ExitCode;
            if ProcessSuccess then
            begin
              if Result = STILL_ACTIVE then
              begin
                // процесс все еще выполняется
                ResultMessage := 'Процесс выполняется';
                // CallBackLog(ResultMessage);
              end
              else
              begin
                // процесс завершен, ExitCode содержит код выхода
                if Result = 0 then
                  ResultMessage := 'Архивация завершена'
                else
                  ResultMessage := 'Архивация не завершена';

                CallBackLog(ResultMessage + ' с кодом результата ' +
                  IntToStr(Result));
                Break; // выходим из цикла
              end;
            end
            else
            begin
              // Ошибка при получении кода выхода
              Result := GetLastError();
              ExitCodeStr := SysErrorMessage(Result);
              // выводим код последней ошибки и его расшифровку
              ResultMessage := Format('Ошибка %d' + #13 + '%s',
                [Result, ExitCodeStr]);
              CallBackLog(ResultMessage);
              Break; // выходим из цикла
            end;

            // обрабатываем все сообщения в очереди (чтобы форма не зависала)
            App.ProcessMessages;
            Sleep(100); // небольшая задержка
          end;
        end;
      finally
        if ShellExecuteInfo.hProcess <> 0 then
        begin
          // завершаем фоновый процесс
          TerminateProcess(ShellExecuteInfo.hProcess, ExitCode);
          // закрываем дескриптор
          CloseHandle(ShellExecuteInfo.hProcess);
        end;

        if StopFlag then
        begin
          ResultMessage := 'Архивация прервана пользователем!';
          CallBackLog(ResultMessage);
          App.ProcessMessages;
        end;
      end;
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := 'Путь к файлу/папки задан некорректно!';
      CallBackLog(ResultMessage);
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := 'Архиватор 7-Zip не найден!';
    CallBackLog(ResultMessage);
  end;
end;

function ProcessCli(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out ResultMessage: string): integer;
var
  // характеристики главного окна
  StartupInfo: TStartupInfo;
  // информация о процессе
  ProcessInformation: TProcessInformation;
  // дескриптор безопасности
  SecurityDescriptor: TSecurityDescriptor;
  // атрибуты безопасности
  SecurityAttributes: TSecurityAttributes;
  // структура обеспечивающая асинхронный режим работы
  Overlapped: TOverlapped;
  // дескрипторы чтения и записи в память
  StdOutRead, StdOutWrite: THandle;
  // буфер обмена (массив байт)
  Buf: array [0 .. MAX_PATH - 1] of Byte;
  // общее количество байт доступных для чтения
  AllBytesRead: DWord;
  // количество считанных байт
  BytesRead: DWord;
  // код и расшифровка ошибки
  ExitCode: DWord;
  ExitCodeStr: String;

  SevenZipPath, CommandLine, ArchivePath: string;
  StrFull, StrPercent: string;
  IndexPercent: integer;
  ProcessSuccess, CopyData: BOOL;
  WaitResult: Cardinal;
begin
  // проверяем что архиватор 7-Zip установлен
  if SearchSevenZip(SevenZipPath) then
  begin
    // проверяем что заданный файл или директория существует
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // удаляем лишние символы
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // определяем путь для архива
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // код для командной строки
      CommandLine := Format('"%s" a -bsp1 "%s" "%s"',
        [SevenZipPath, ArchivePath, SourcePath]);

      // инициализация дескриптора безопасности
      InitializeSecurityDescriptor(@SecurityDescriptor,
        SECURITY_DESCRIPTOR_REVISION);
      // указатель на дескриптор защиты процесса
      SecurityAttributes.lpSecurityDescriptor := @SecurityDescriptor;
      // признак наследования возвращаемого дескриптора
      SecurityAttributes.bInheritHandle := True;
      // размер структуры в байтах
      SecurityAttributes.nLength := SizeOf(TSecurityAttributes);

      // создаем анонимный канал для обмена данными между процессами
      CreatePipe(StdOutRead, StdOutWrite, @SecurityAttributes, 0);

      // очищаем структуру StartupInfo
      FillChar(StartupInfo, SizeOf(StartupInfo), #0);
      // размер структуры в байтах
      StartupInfo.cb := SizeOf(TStartupInfo);
      // флаги для дочерних процессов
      StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      // режим отображения окна
      StartupInfo.wShowWindow := SW_HIDE;
      // дескриптор процесса для стандартного вывода
      StartupInfo.hStdOutput := StdOutWrite;
      // дескриптор процесса для вывода ошибок
      StartupInfo.hStdError := StdOutWrite;

      // очищаем структуру Overlapped
      FillChar(Overlapped, 0, SizeOf(TOverlapped));
      // создаем событие синхронизации
      Overlapped.hEvent := CreateEvent(
        // адрес структуры TSecurityAttributes
        @SecurityAttributes,
        // указывает, будет ли объект переключаться в несигнальное состояние
        // вручную (True) или автоматически (False)
        True,
        // задает начальное состояние (если True - объект в сигнальном состоянии)
        False,
        // имя или nil, если имя не требуется
        nil);

      try
        // запускаем процесс архивации
        if not CreateProcess(
          // запускаемое приложение
          PChar(SevenZipPath),
          // командная строка
          PChar(CommandLine),
          // атрибуты безопасности создаваемого процесса
          @SecurityAttributes,
          // атрибуты безопасности главного потока этого процесса
          @SecurityAttributes,
          // определяет, наследуют ли новые процессы дескрипторы родительских
          True,
          // определяет флаги c характеристиками процесса
          // (особенности создания и уровень приоритета)
          IDLE_PRIORITY_CLASS,
          // настройки окружения нового процесса
          nil,
          // путь к текущему каталогу нового процесса
          nil,
          // структуры TStartupInfo и TProcessInformation
          StartupInfo, ProcessInformation) then
        begin
          Result := GetLastError();
          ResultMessage := 'Ошибка запуска архивации: №' +
            IntToStr(Result) + '!';
          CallBackLog(ResultMessage);
          CallBackProgress(0, 100);
          Exit;
        end
        else
        begin
          Result := 0;
          ResultMessage := 'Архивация запущена';
          CallBackLog(ResultMessage);
          CallBackProgress(0, 100);
        end;

        // считываем данные из фонового процесса
        while (not App.Terminated) and (not StopFlag) do
        begin
          // копирует данные из именованного или анонимного канала в буфер,
          // не удаляя их из канала
          CopyData := PeekNamedPipe(
            // дескриптор канала
            StdOutRead,
            // указатель на буфер чтения
            nil,
            // размер буфера (0 - значение по умолчанию)
            0,
            // количество байтов, считанных из канала
            nil,
            // общее количество байтов, доступных для чтения из канала
            @AllBytesRead,
            // количество байтов, оставшихся в этом сообщении
            nil);

          // если нет данных доступных для чтения из канала
          if not CopyData or (AllBytesRead = 0) then
          begin
            // проверяем, завершился ли процесс
            ProcessSuccess := GetExitCodeProcess(ProcessInformation.hProcess,
              ExitCode);
            Result := ExitCode;
            if ProcessSuccess then
            begin
              if Result = STILL_ACTIVE then
              begin
                // процесс все еще выполняется
                ResultMessage := 'Процесс выполняется';
                // CallBackLog(ResultMessage);
              end
              else
              begin
                // процесс завершен, ExitCode содержит код выхода
                if Result = 0 then
                begin
                  ResultMessage := 'Архивация завершена';
                  CallBackProgress(100, 100);
                end
                else
                  ResultMessage := 'Архивация не завершена';

                CallBackLog(ResultMessage + ' с кодом результата ' +
                  IntToStr(Result));
                Break; // выходим из цикла
              end;
            end
            else
            begin
              // Ошибка при получении кода выхода
              Result := GetLastError();
              ExitCodeStr := SysErrorMessage(Result);
              // выводим код последней ошибки и его расшифровку
              ResultMessage := Format('Ошибка %d' + #13 + '%s',
                [Result, ExitCodeStr]);
              CallBackLog(ResultMessage);
              Break; // выходим из цикла
            end;

            // обрабатываем все сообщения в очереди (чтобы форма не зависала)
            App.ProcessMessages;
            Sleep(100); // небольшая задержка
            Continue; // пропускаем текущую итерацию
          end;

          // считываем данные из анонимного канала в буфер
          FillChar(Buf, SizeOf(Buf), #0);
          if ReadFile(StdOutRead, Buf, SizeOf(Buf), BytesRead, @Overlapped) and
            (BytesRead > 0) then
          begin
            // выводим данные
            StrFull := TEncoding.GetEncoding('CP866').GetString(Buf);
            CallBackLog(StrFull);

            // выводим прогресс
            StrFull := Trim(StrFull);
            IndexPercent := PosEx('%', StrFull, 1);
            if IndexPercent > 0 then
              try
                StrPercent := Copy(StrFull, 1, IndexPercent - 1);
                CallBackProgress(StrToInt(StrPercent), 100);
              except
                on E: EConvertError do
                  if Copy(StrFull, IndexPercent - 3, 3) = '100' then
                    CallBackProgress(100, 100);
              end;
          end
          else // если считать данные не получилось (канал занят другим процессом)
          begin
            ExitCode := GetLastError();
            case ExitCode of
              ERROR_IO_PENDING:
                begin
                  // ожидаем 50 миллисекунд
                  repeat
                    App.ProcessMessages;
                    WaitResult := WaitForSingleObject(Overlapped.hEvent, 50);
                  until (WaitResult <> WAIT_TIMEOUT) or
                    App.Terminated or StopFlag;

                  if App.Terminated or StopFlag then
                    Break; // выходим из цикла

                  if WaitResult = WAIT_OBJECT_0 then
                    // дождались, получаем результат функции чтения (ReadFile)
                    GetOverlappedResult(StdOutRead, Overlapped, BytesRead, True)
                  else
                  begin
                    Result := WaitResult;
                    ResultMessage := 'Ошибка синхронизации!';
                    CallBackLog(ResultMessage);
                    Break; // выходим из цикла
                  end;
                end;
              ERROR_BROKEN_PIPE:
                begin
                  Result := ExitCode;
                  ResultMessage := 'Канал разорван!';
                  CallBackLog(ResultMessage);
                  Break; // выходим из цикла
                end
            else
              begin
                Result := ExitCode;
                ResultMessage := 'Сбой чтения данных!';
                CallBackLog(ResultMessage);
                Break; // выходим из цикла
              end;
            end
          end;
        end;
      finally
        if ProcessInformation.hProcess <> 0 then
        begin
          // завершаем фоновый процесс
          TerminateProcess(ProcessInformation.hProcess, ExitCode);
          // закрываем дескриптор главного потока
          CloseHandle(ProcessInformation.hThread);
          // закрываем дескриптор созданного процесса
          CloseHandle(ProcessInformation.hProcess);
        end;

        // закрываем дескриптор события синхронизации
        if Overlapped.hEvent <> 0 then
          CloseHandle(Overlapped.hEvent);

        // закрываем дескриптор чтения
        if StdOutRead <> 0 then
          CloseHandle(StdOutRead);

        // закрываем дескриптор записи
        if StdOutWrite <> 0 then
          CloseHandle(StdOutWrite);

        if StopFlag then
        begin
          ResultMessage := 'Архивация прервана пользователем!';
          CallBackLog(ResultMessage);
          App.ProcessMessages;
        end;
      end;
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := 'Путь к файлу/папки задан некорректно!';
      CallBackLog(ResultMessage);
      CallBackProgress(0, 100);
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := 'Архиватор 7-Zip не найден!';
    CallBackLog(ResultMessage);
    CallBackProgress(0, 100);
  end;
end;

procedure GetFuncList(out FuncList: TStringList);
begin
  // FuncList.Add('ShellCli');
  // FuncList.Add('ShellCliEx');
  FuncList.Add('ProcessCli');
end;

end.
