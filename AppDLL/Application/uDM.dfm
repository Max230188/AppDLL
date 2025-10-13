object dmAppData: TdmAppData
  Height = 523
  Width = 902
  PixelsPerInch = 144
  object mmAppMenu: TMainMenu
    BiDiMode = bdRightToLeft
    ParentBiDiMode = False
    Left = 88
    Top = 64
    object miUpdateListDLL: TMenuItem
      Action = acUpdateListDLL
    end
    object miClearRunningTask: TMenuItem
      Action = acClearRunningTask
      Caption = 'Clear Running Task'
    end
    object miClearCompletedTask: TMenuItem
      Action = acClearCompletedTask
    end
  end
  object aclAppAction: TActionList
    Left = 256
    Top = 64
    object acUpdateListDLL: TAction
      Category = 'List'
      Caption = 'Update List DLL'
      OnExecute = acUpdateListDLLExecute
    end
    object acClearRunningTask: TAction
      Category = 'List'
      Caption = 'acClearRunningTask'
      OnExecute = acClearRunningTaskExecute
    end
    object acClearCompletedTask: TAction
      Category = 'List'
      Caption = 'Clear Completed Task'
      OnExecute = acClearCompletedTaskExecute
    end
  end
end
