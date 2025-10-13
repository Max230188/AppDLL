object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'AppDLL'
  ClientHeight = 651
  ClientWidth = 1075
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = dmAppData.mmAppMenu
  Position = poDesktopCenter
  OnCanResize = FormCanResize
  OnClose = FormClose
  OnCreate = FormCreate
  OnResize = FormResize
  OnShow = FormShow
  TextHeight = 15
  object SplitterLeft: TSplitter
    Left = 281
    Top = 0
    Height = 651
    ExplicitLeft = 176
    ExplicitTop = 136
    ExplicitHeight = 100
  end
  object pnlListDLL: TPanel
    Left = 0
    Top = 0
    Width = 281
    Height = 651
    Align = alLeft
    TabOrder = 0
    OnResize = pnlListDLLResize
    ExplicitHeight = 634
    object tvListDLL: TTreeView
      Left = 1
      Top = 1
      Width = 279
      Height = 649
      Align = alClient
      Indent = 19
      TabOrder = 0
      OnAdvancedCustomDrawItem = tvListDLLAdvancedCustomDrawItem
      OnCollapsed = tvListDLLCollapsed
      OnCompare = tvListDLLCompare
      OnExpanded = tvListDLLExpanded
      ExplicitHeight = 632
    end
  end
  object pnlListTask: TPanel
    Left = 284
    Top = 0
    Width = 791
    Height = 651
    Align = alClient
    TabOrder = 1
    ExplicitWidth = 785
    ExplicitHeight = 634
    object SplitterTop: TSplitter
      Left = 1
      Top = 257
      Width = 789
      Height = 3
      Cursor = crVSplit
      Align = alTop
      ExplicitTop = 305
      ExplicitWidth = 375
    end
    object pnlRunningTask: TPanel
      Left = 1
      Top = 1
      Width = 789
      Height = 256
      Align = alTop
      TabOrder = 0
      OnCanResize = pnlRunningTaskCanResize
      ExplicitWidth = 783
      object lbRunningTask: TLabel
        Left = 1
        Top = 1
        Width = 787
        Height = 15
        Align = alTop
        Caption = 'Running Task'
        ExplicitWidth = 71
      end
      object sgdRunningTask: TStringGrid
        Left = 1
        Top = 16
        Width = 787
        Height = 239
        Align = alClient
        DefaultColWidth = 150
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goFixedRowDefAlign]
        TabOrder = 0
        OnDrawCell = sgdRunningTaskDrawCell
        OnTopLeftChanged = sgdRunningTaskTopLeftChanged
        ExplicitWidth = 781
      end
    end
    object pnlCompletedTask: TPanel
      Left = 1
      Top = 260
      Width = 789
      Height = 390
      Align = alClient
      TabOrder = 1
      OnCanResize = pnlRunningTaskCanResize
      ExplicitWidth = 783
      ExplicitHeight = 373
      object lbCompletedTask: TLabel
        Left = 1
        Top = 1
        Width = 787
        Height = 15
        Align = alTop
        Caption = 'Completed Task'
        ExplicitWidth = 85
      end
      object sgdCompletedTask: TStringGrid
        Left = 1
        Top = 16
        Width = 787
        Height = 373
        Align = alClient
        DefaultColWidth = 150
        FixedCols = 0
        RowCount = 2
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect, goFixedRowDefAlign]
        TabOrder = 0
        OnDrawCell = sgdRunningTaskDrawCell
        OnTopLeftChanged = sgdRunningTaskTopLeftChanged
        ExplicitWidth = 781
        ExplicitHeight = 356
      end
    end
  end
end
