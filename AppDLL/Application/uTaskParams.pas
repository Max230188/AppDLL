unit uTaskParams;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Buttons, Vcl.Grids,
  Vcl.ValEdit, Vcl.ExtCtrls;

type
  TfrmTaskParams = class(TForm)
    pnlParameters: TPanel;
    pnlButtons: TPanel;
    vleParameters: TValueListEditor;
    bbOK: TBitBtn;
    bbCancel: TBitBtn;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmTaskParams: TfrmTaskParams;

implementation

{$R *.dfm}

end.
