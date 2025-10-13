object frmTaskResult: TfrmTaskResult
  Left = 0
  Top = 0
  Caption = 'Task Result'
  ClientHeight = 444
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  TextHeight = 15
  object pnlResult: TPanel
    Left = 0
    Top = 0
    Width = 624
    Height = 416
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 618
    ExplicitHeight = 399
    object mmResult: TMemo
      Left = 1
      Top = 1
      Width = 622
      Height = 414
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 416
    Width = 624
    Height = 28
    Align = alBottom
    TabOrder = 1
    ExplicitTop = 399
    ExplicitWidth = 618
    object bbCancel: TBitBtn
      Left = 1
      Top = 1
      Width = 622
      Height = 26
      Align = alClient
      Kind = bkCancel
      NumGlyphs = 2
      TabOrder = 0
      ExplicitWidth = 616
    end
  end
end
