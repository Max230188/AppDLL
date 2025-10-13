unit uTasks;

{ ��� ������ ���� DLL ���������� ���������� ��������� ������ ���������� 7-Zip }

interface

uses
  ShareMem, System.Types, System.Classes, System.SysUtils, System.IOUtils,
  System.StrUtils, Winapi.ShellAPI, Winapi.Windows, Vcl.Dialogs, Vcl.Forms;

type
  // ��������� ��������� (������������ ��� ��������� ��������� ������)
  TCallBackLog = reference to procedure(LogMessage: string);
  TCallBackProgress = reference to procedure(Progress, MaxProgress: integer);

  // �������� ������ ��� ��������� ����� ��� ���������� � ������� ShellExecute
  // ���������� ��� ����������� �������� � ��������������� ��� ���������
  // ������������� ������ ������ ������� ������
function ShellCli(AppHandle: THandle; SourcePath: string;
  out ResultMessage: string): integer; stdcall; export;

// �������� ������ ��� ��������� ����� ��� ���������� � ������� ShellExecuteEx
// ���������� ��� ����������� �������� � ��������������� ��� ���������
// ������������� ������ � ���������� ������
function ShellCliEx(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; var StopFlag: Boolean; out ResultMessage: string)
  : integer; stdcall; export;

// �������� ������ ��� ��������� ����� ��� ���������� � ������� CreateProcess
// ���������� ��� ����������� �������� � ��������������� ��� ���������
// ������������� ������, ���������� � �������� ���������� ������
function ProcessCli(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out ResultMessage: string): integer; stdcall; export;

// ���������� ������ ������� ������� ������������ DLL
procedure GetFuncList(out FuncList: TStringList); stdcall; export;

implementation

// ����� �������������� � Windows ���������� 7-Zip
// ���������� ���� � ����� 7z.exe � ���������� ���������
function SearchSevenZip(out SevenZipPath: string): Boolean;
var
  DriveList: TStringDynArray;
  StrDrive, Buf: string;
begin
  Result := False;
  // ��������� ��� ���������� ����� �� �������� �����
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
  // ��������� ��� ��������� 7-Zip ����������
  if SearchSevenZip(SevenZipPath) then
  begin
    // ��������� ��� �������� ���� ��� ���������� ����������
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // ������� ������ �������
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // ���������� ���� ��� ������
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // ��� ��� ��������� ������
      CommandLine := Format('a "%s" "%s"', [ArchivePath, SourcePath]);

      // ��������� ���������
      Result := ShellExecute(AppHandle, 'open', PChar(SevenZipPath),
        PChar(CommandLine), nil, SW_HIDE);

      // ������������ ���������
      if Result > 32 then
        ResultMessage := '��������� ��������'
      else
        ResultMessage := '������ ������� ���������: �' + IntToStr(Result) + '!';
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := '���� � �����/����� ����� �����������!';
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := '��������� 7-Zip �� ������!';
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
  // ��������� ��� ��������� 7-Zip ����������
  if SearchSevenZip(SevenZipPath) then
  begin
    // ��������� ��� �������� ���� ��� ���������� ����������
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // ������� ������ �������
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // ���������� ���� ��� ������
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // ��� ��� ��������� ������
      CommandLine := Format('a "%s" "%s"', [ArchivePath, SourcePath]);

      // ������� ��������� TShellExecuteInfo
      FillChar(ShellExecuteInfo, SizeOf(TShellExecuteInfo), 0);
      // ��������� ��������� TShellExecuteInfo
      with ShellExecuteInfo do
      begin
        // ������ ��������� � ������
        cbSize := SizeOf(TShellExecuteInfo);
        // ���������� ���� ���������
        Wnd := App.Handle;
        // ���� ���� �������� ��� hProcess �������� ���������� ��������
        fMask := SEE_MASK_NOCLOSEPROCESS;
        // ����������� ����������
        lpFile := PChar(SevenZipPath);
        // ��������� ������
        lpParameters := PChar(CommandLine);
        // ����� ����������� ����
        nShow := SW_HIDE;
      end;

      try
        // ��������� ���������
        ShellSuccess := ShellExecuteEx(@ShellExecuteInfo);

        // ������������ ���������
        Result := ShellExecuteInfo.hInstApp;
        if Result > 32 then
        begin
          ResultMessage := '��������� ��������';
          CallBackLog(ResultMessage);
        end
        else
        begin
          ResultMessage := '������ ������� ���������: �' +
            IntToStr(Result) + '!';
          CallBackLog(ResultMessage);
          Exit;
        end;

        // ���������� ����������� ��������
        if ShellSuccess and (ShellExecuteInfo.hProcess <> 0) then
        begin
          while (not App.Terminated) and (not StopFlag) do
          begin
            // ���������, ���������� �� �������
            ProcessSuccess := GetExitCodeProcess(ShellExecuteInfo.hProcess,
              ExitCode);
            Result := ExitCode;
            if ProcessSuccess then
            begin
              if Result = STILL_ACTIVE then
              begin
                // ������� ��� ��� �����������
                ResultMessage := '������� �����������';
                // CallBackLog(ResultMessage);
              end
              else
              begin
                // ������� ��������, ExitCode �������� ��� ������
                if Result = 0 then
                  ResultMessage := '��������� ���������'
                else
                  ResultMessage := '��������� �� ���������';

                CallBackLog(ResultMessage + ' � ����� ���������� ' +
                  IntToStr(Result));
                Break; // ������� �� �����
              end;
            end
            else
            begin
              // ������ ��� ��������� ���� ������
              Result := GetLastError();
              ExitCodeStr := SysErrorMessage(Result);
              // ������� ��� ��������� ������ � ��� �����������
              ResultMessage := Format('������ %d' + #13 + '%s',
                [Result, ExitCodeStr]);
              CallBackLog(ResultMessage);
              Break; // ������� �� �����
            end;

            // ������������ ��� ��������� � ������� (����� ����� �� ��������)
            App.ProcessMessages;
            Sleep(100); // ��������� ��������
          end;
        end;
      finally
        if ShellExecuteInfo.hProcess <> 0 then
        begin
          // ��������� ������� �������
          TerminateProcess(ShellExecuteInfo.hProcess, ExitCode);
          // ��������� ����������
          CloseHandle(ShellExecuteInfo.hProcess);
        end;

        if StopFlag then
        begin
          ResultMessage := '��������� �������� �������������!';
          CallBackLog(ResultMessage);
          App.ProcessMessages;
        end;
      end;
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := '���� � �����/����� ����� �����������!';
      CallBackLog(ResultMessage);
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := '��������� 7-Zip �� ������!';
    CallBackLog(ResultMessage);
  end;
end;

function ProcessCli(App: TApplication; SourcePath: string;
  CallBackLog: TCallBackLog; CallBackProgress: TCallBackProgress;
  var StopFlag: Boolean; out ResultMessage: string): integer;
var
  // �������������� �������� ����
  StartupInfo: TStartupInfo;
  // ���������� � ��������
  ProcessInformation: TProcessInformation;
  // ���������� ������������
  SecurityDescriptor: TSecurityDescriptor;
  // �������� ������������
  SecurityAttributes: TSecurityAttributes;
  // ��������� �������������� ����������� ����� ������
  Overlapped: TOverlapped;
  // ����������� ������ � ������ � ������
  StdOutRead, StdOutWrite: THandle;
  // ����� ������ (������ ����)
  Buf: array [0 .. MAX_PATH - 1] of Byte;
  // ����� ���������� ���� ��������� ��� ������
  AllBytesRead: DWord;
  // ���������� ��������� ����
  BytesRead: DWord;
  // ��� � ����������� ������
  ExitCode: DWord;
  ExitCodeStr: String;

  SevenZipPath, CommandLine, ArchivePath: string;
  StrFull, StrPercent: string;
  IndexPercent: integer;
  ProcessSuccess, CopyData: BOOL;
  WaitResult: Cardinal;
begin
  // ��������� ��� ��������� 7-Zip ����������
  if SearchSevenZip(SevenZipPath) then
  begin
    // ��������� ��� �������� ���� ��� ���������� ����������
    if TFile.Exists(SourcePath) or TDirectory.Exists(SourcePath) then
    begin
      // ������� ������ �������
      if (SourcePath[SourcePath.Length] = '\') or
        (SourcePath[SourcePath.Length] = '/') then
        Delete(SourcePath, SourcePath.Length, 1);

      // ���������� ���� ��� ������
      if TFile.Exists(SourcePath) then
        ArchivePath := TPath.GetDirectoryName(SourcePath) + '\' +
          TPath.GetFileNameWithoutExtension(SourcePath) + '.zip'
      else
        ArchivePath := SourcePath + '.zip';

      // ��� ��� ��������� ������
      CommandLine := Format('"%s" a -bsp1 "%s" "%s"',
        [SevenZipPath, ArchivePath, SourcePath]);

      // ������������� ����������� ������������
      InitializeSecurityDescriptor(@SecurityDescriptor,
        SECURITY_DESCRIPTOR_REVISION);
      // ��������� �� ���������� ������ ��������
      SecurityAttributes.lpSecurityDescriptor := @SecurityDescriptor;
      // ������� ������������ ������������� �����������
      SecurityAttributes.bInheritHandle := True;
      // ������ ��������� � ������
      SecurityAttributes.nLength := SizeOf(TSecurityAttributes);

      // ������� ��������� ����� ��� ������ ������� ����� ����������
      CreatePipe(StdOutRead, StdOutWrite, @SecurityAttributes, 0);

      // ������� ��������� StartupInfo
      FillChar(StartupInfo, SizeOf(StartupInfo), #0);
      // ������ ��������� � ������
      StartupInfo.cb := SizeOf(TStartupInfo);
      // ����� ��� �������� ���������
      StartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      // ����� ����������� ����
      StartupInfo.wShowWindow := SW_HIDE;
      // ���������� �������� ��� ������������ ������
      StartupInfo.hStdOutput := StdOutWrite;
      // ���������� �������� ��� ������ ������
      StartupInfo.hStdError := StdOutWrite;

      // ������� ��������� Overlapped
      FillChar(Overlapped, 0, SizeOf(TOverlapped));
      // ������� ������� �������������
      Overlapped.hEvent := CreateEvent(
        // ����� ��������� TSecurityAttributes
        @SecurityAttributes,
        // ���������, ����� �� ������ ������������� � ������������ ���������
        // ������� (True) ��� ������������� (False)
        True,
        // ������ ��������� ��������� (���� True - ������ � ���������� ���������)
        False,
        // ��� ��� nil, ���� ��� �� ���������
        nil);

      try
        // ��������� ������� ���������
        if not CreateProcess(
          // ����������� ����������
          PChar(SevenZipPath),
          // ��������� ������
          PChar(CommandLine),
          // �������� ������������ ������������ ��������
          @SecurityAttributes,
          // �������� ������������ �������� ������ ����� ��������
          @SecurityAttributes,
          // ����������, ��������� �� ����� �������� ����������� ������������
          True,
          // ���������� ����� c ���������������� ��������
          // (����������� �������� � ������� ����������)
          IDLE_PRIORITY_CLASS,
          // ��������� ��������� ������ ��������
          nil,
          // ���� � �������� �������� ������ ��������
          nil,
          // ��������� TStartupInfo � TProcessInformation
          StartupInfo, ProcessInformation) then
        begin
          Result := GetLastError();
          ResultMessage := '������ ������� ���������: �' +
            IntToStr(Result) + '!';
          CallBackLog(ResultMessage);
          CallBackProgress(0, 100);
          Exit;
        end
        else
        begin
          Result := 0;
          ResultMessage := '��������� ��������';
          CallBackLog(ResultMessage);
          CallBackProgress(0, 100);
        end;

        // ��������� ������ �� �������� ��������
        while (not App.Terminated) and (not StopFlag) do
        begin
          // �������� ������ �� ������������ ��� ���������� ������ � �����,
          // �� ������ �� �� ������
          CopyData := PeekNamedPipe(
            // ���������� ������
            StdOutRead,
            // ��������� �� ����� ������
            nil,
            // ������ ������ (0 - �������� �� ���������)
            0,
            // ���������� ������, ��������� �� ������
            nil,
            // ����� ���������� ������, ��������� ��� ������ �� ������
            @AllBytesRead,
            // ���������� ������, ���������� � ���� ���������
            nil);

          // ���� ��� ������ ��������� ��� ������ �� ������
          if not CopyData or (AllBytesRead = 0) then
          begin
            // ���������, ���������� �� �������
            ProcessSuccess := GetExitCodeProcess(ProcessInformation.hProcess,
              ExitCode);
            Result := ExitCode;
            if ProcessSuccess then
            begin
              if Result = STILL_ACTIVE then
              begin
                // ������� ��� ��� �����������
                ResultMessage := '������� �����������';
                // CallBackLog(ResultMessage);
              end
              else
              begin
                // ������� ��������, ExitCode �������� ��� ������
                if Result = 0 then
                begin
                  ResultMessage := '��������� ���������';
                  CallBackProgress(100, 100);
                end
                else
                  ResultMessage := '��������� �� ���������';

                CallBackLog(ResultMessage + ' � ����� ���������� ' +
                  IntToStr(Result));
                Break; // ������� �� �����
              end;
            end
            else
            begin
              // ������ ��� ��������� ���� ������
              Result := GetLastError();
              ExitCodeStr := SysErrorMessage(Result);
              // ������� ��� ��������� ������ � ��� �����������
              ResultMessage := Format('������ %d' + #13 + '%s',
                [Result, ExitCodeStr]);
              CallBackLog(ResultMessage);
              Break; // ������� �� �����
            end;

            // ������������ ��� ��������� � ������� (����� ����� �� ��������)
            App.ProcessMessages;
            Sleep(100); // ��������� ��������
            Continue; // ���������� ������� ��������
          end;

          // ��������� ������ �� ���������� ������ � �����
          FillChar(Buf, SizeOf(Buf), #0);
          if ReadFile(StdOutRead, Buf, SizeOf(Buf), BytesRead, @Overlapped) and
            (BytesRead > 0) then
          begin
            // ������� ������
            StrFull := TEncoding.GetEncoding('CP866').GetString(Buf);
            CallBackLog(StrFull);

            // ������� ��������
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
          else // ���� ������� ������ �� ���������� (����� ����� ������ ���������)
          begin
            ExitCode := GetLastError();
            case ExitCode of
              ERROR_IO_PENDING:
                begin
                  // ������� 50 �����������
                  repeat
                    App.ProcessMessages;
                    WaitResult := WaitForSingleObject(Overlapped.hEvent, 50);
                  until (WaitResult <> WAIT_TIMEOUT) or
                    App.Terminated or StopFlag;

                  if App.Terminated or StopFlag then
                    Break; // ������� �� �����

                  if WaitResult = WAIT_OBJECT_0 then
                    // ���������, �������� ��������� ������� ������ (ReadFile)
                    GetOverlappedResult(StdOutRead, Overlapped, BytesRead, True)
                  else
                  begin
                    Result := WaitResult;
                    ResultMessage := '������ �������������!';
                    CallBackLog(ResultMessage);
                    Break; // ������� �� �����
                  end;
                end;
              ERROR_BROKEN_PIPE:
                begin
                  Result := ExitCode;
                  ResultMessage := '����� ��������!';
                  CallBackLog(ResultMessage);
                  Break; // ������� �� �����
                end
            else
              begin
                Result := ExitCode;
                ResultMessage := '���� ������ ������!';
                CallBackLog(ResultMessage);
                Break; // ������� �� �����
              end;
            end
          end;
        end;
      finally
        if ProcessInformation.hProcess <> 0 then
        begin
          // ��������� ������� �������
          TerminateProcess(ProcessInformation.hProcess, ExitCode);
          // ��������� ���������� �������� ������
          CloseHandle(ProcessInformation.hThread);
          // ��������� ���������� ���������� ��������
          CloseHandle(ProcessInformation.hProcess);
        end;

        // ��������� ���������� ������� �������������
        if Overlapped.hEvent <> 0 then
          CloseHandle(Overlapped.hEvent);

        // ��������� ���������� ������
        if StdOutRead <> 0 then
          CloseHandle(StdOutRead);

        // ��������� ���������� ������
        if StdOutWrite <> 0 then
          CloseHandle(StdOutWrite);

        if StopFlag then
        begin
          ResultMessage := '��������� �������� �������������!';
          CallBackLog(ResultMessage);
          App.ProcessMessages;
        end;
      end;
    end
    else
    begin
      Result := SE_ERR_PNF;
      ResultMessage := '���� � �����/����� ����� �����������!';
      CallBackLog(ResultMessage);
      CallBackProgress(0, 100);
    end;
  end
  else
  begin
    Result := SE_ERR_FNF;
    ResultMessage := '��������� 7-Zip �� ������!';
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
