unit uTaskLog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.ExtCtrls;

type
  TfrmTaskLog = class(TForm)
    pnlLog: TPanel;
    pnlButtons: TPanel;
    bbSave: TBitBtn;
    bbCancel: TBitBtn;
    mmLog: TMemo;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmTaskLog: TfrmTaskLog;

implementation

{$R *.dfm}

end.
