unit uTaskResult;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Buttons;

type
  TfrmTaskResult = class(TForm)
    pnlResult: TPanel;
    pnlButtons: TPanel;
    bbCancel: TBitBtn;
    mmResult: TMemo;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmTaskResult: TfrmTaskResult;

implementation

{$R *.dfm}

end.
