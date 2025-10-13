program AppDLL;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  uInfoDLL in 'uInfoDLL.pas',
  uAPI in 'uAPI.pas',
  uDM in 'uDM.pas' {dmAppData: TDataModule},
  uTask in 'uTask.pas',
  uTaskThread in 'uTaskThread.pas',
  uTaskParams in 'uTaskParams.pas' {frmTaskParams},
  uTaskResult in 'uTaskResult.pas' {frmTaskResult},
  uTaskLog in 'uTaskLog.pas' {frmTaskLog};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.CreateForm(TdmAppData, dmAppData);
  Application.Run;
end.
