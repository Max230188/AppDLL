object frmTaskLog: TfrmTaskLog
  Left = 0
  Top = 0
  Caption = 'Task Log'
  ClientHeight = 441
  ClientWidth = 624
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poDesktopCenter
  TextHeight = 15
  object pnlLog: TPanel
    Left = 0
    Top = 0
    Width = 624
    Height = 384
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 618
    ExplicitHeight = 367
    object mmLog: TMemo
      Left = 1
      Top = 1
      Width = 622
      Height = 382
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 0
    end
  end
  object pnlButtons: TPanel
    Left = 0
    Top = 384
    Width = 624
    Height = 57
    Align = alBottom
    TabOrder = 1
    ExplicitTop = 367
    ExplicitWidth = 618
    object bbSave: TBitBtn
      Left = 1
      Top = 1
      Width = 622
      Height = 25
      Align = alTop
      Caption = 'Save'
      Kind = bkOK
      NumGlyphs = 2
      TabOrder = 0
      ExplicitWidth = 616
    end
    object bbCancel: TBitBtn
      Left = 1
      Top = 31
      Width = 622
      Height = 25
      Align = alBottom
      Kind = bkCancel
      NumGlyphs = 2
      TabOrder = 1
      ExplicitWidth = 616
    end
  end
end
