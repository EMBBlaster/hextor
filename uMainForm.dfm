object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'DWHex'
  ClientHeight = 639
  ClientWidth = 1028
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  FormStyle = fsMDIForm
  KeyPreview = True
  Menu = MainMenu1
  OldCreateOrder = False
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter1: TSplitter
    Left = 740
    Top = 47
    Width = 4
    Height = 592
    Align = alRight
    AutoSnap = False
    ResizeStyle = rsUpdate
    ExplicitLeft = 840
    ExplicitTop = 49
    ExplicitHeight = 590
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 1028
    Height = 22
    AutoSize = True
    ButtonWidth = 24
    Caption = 'ToolBar1'
    Images = ImageList16
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    object ToolButton1: TToolButton
      Left = 0
      Top = 0
      Action = ActionNew
    end
    object ToolButton2: TToolButton
      Left = 24
      Top = 0
      Action = ActionOpen
      DropdownMenu = RecentFilesMenu
      Style = tbsDropDown
    end
    object ToolButton3: TToolButton
      Left = 63
      Top = 0
      Action = ActionSave
    end
  end
  object MDITabs: TTabControl
    Left = 0
    Top = 22
    Width = 1028
    Height = 25
    Align = alTop
    DoubleBuffered = True
    Images = ImageList16
    ParentDoubleBuffered = False
    TabOrder = 1
    OnChange = MDITabsChange
    OnGetImageIndex = MDITabsGetImageIndex
    OnMouseUp = MDITabsMouseUp
    ExplicitTop = 24
  end
  object RightPanel: TPanel
    Left = 744
    Top = 47
    Width = 284
    Height = 592
    Align = alRight
    BevelOuter = bvNone
    DoubleBuffered = True
    ParentDoubleBuffered = False
    TabOrder = 2
    ExplicitTop = 49
    ExplicitHeight = 590
    object RightPanelPageControl: TPageControl
      Left = 0
      Top = 0
      Width = 284
      Height = 592
      ActivePage = PgValue
      Align = alClient
      TabOrder = 0
      ExplicitHeight = 590
      object PgValue: TTabSheet
        Caption = 'Value'
        ExplicitHeight = 562
        inline ValueFrame: TValueFrame
          Left = 0
          Top = 0
          Width = 276
          Height = 564
          Align = alClient
          TabOrder = 0
          ExplicitWidth = 276
          ExplicitHeight = 562
          inherited ValuesGrid: TKGrid
            Width = 276
            Height = 564
            ExplicitWidth = 276
            ExplicitHeight = 562
            ColWidths = (
              64
              207)
            RowHeights = (
              21
              21)
          end
        end
      end
      object PgStruct: TTabSheet
        Caption = 'Struct'
        ImageIndex = 1
        ExplicitHeight = 562
        inline StructFrame: TStructFrame
          Left = 0
          Top = 0
          Width = 276
          Height = 564
          Align = alClient
          TabOrder = 0
          ExplicitWidth = 276
          ExplicitHeight = 562
        end
      end
    end
  end
  object MainMenu1: TMainMenu
    Images = ImageList16
    Left = 144
    Top = 72
    object File1: TMenuItem
      Caption = 'File'
      object New1: TMenuItem
        Action = ActionNew
      end
      object Open1: TMenuItem
        Action = ActionOpen
      end
      object MIRecentFilesMenu: TMenuItem
        AutoHotkeys = maManual
        Caption = 'Open Recent'
        OnClick = MIRecentFilesMenuClick
        object MIDummyRecentFile: TMenuItem
          Caption = 'MIDummyRecentFile'
          Visible = False
          OnClick = MIDummyRecentFileClick
        end
      end
      object Save1: TMenuItem
        Action = ActionSave
      end
      object Saveas1: TMenuItem
        Action = ActionSaveAs
      end
      object Saveselectionas1: TMenuItem
        Action = ActionSaveSelectionAs
      end
      object Revert1: TMenuItem
        Action = ActionRevert
      end
      object N4: TMenuItem
        Caption = '-'
      end
      object MIOpenDisk: TMenuItem
        Action = ActionOpenDisk
      end
      object N3: TMenuItem
        Caption = '-'
      end
      object OpenProcessMemory1: TMenuItem
        Action = ActionOpenProcMemory
      end
      object N5: TMenuItem
        Caption = '-'
      end
      object Exit1: TMenuItem
        Action = ActionExit
      end
    end
    object Edit1: TMenuItem
      Caption = 'Edit'
      object MICut: TMenuItem
        Action = ActionCut
      end
      object MICopy: TMenuItem
        Action = ActionCopy
      end
      object MICopyAs: TMenuItem
        Action = ActionCopyAs
      end
      object MIPaste: TMenuItem
        Action = ActionPaste
      end
      object MISelectAll: TMenuItem
        Action = ActionSelectAll
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object MIFindReplace: TMenuItem
        Action = ActionFind
      end
      object FindNext1: TMenuItem
        Action = ActionFindNext
      end
      object FindPrevious1: TMenuItem
        Action = ActionFindPrev
      end
      object GoToaddress1: TMenuItem
        Action = ActionGoToAddr
      end
    end
    object View1: TMenuItem
      Caption = 'View'
      object Columnscount1: TMenuItem
        Caption = 'Columns count'
        OnClick = Columnscount1Click
        object MIColumns8: TMenuItem
          Tag = 8
          AutoCheck = True
          Caption = '8'
          RadioItem = True
          OnClick = MIColumns8Click
        end
        object MIColumns16: TMenuItem
          Tag = 16
          AutoCheck = True
          Caption = '16'
          RadioItem = True
          OnClick = MIColumns8Click
        end
        object MIColumns32: TMenuItem
          Tag = 32
          AutoCheck = True
          Caption = '32'
          RadioItem = True
          OnClick = MIColumns8Click
        end
        object MIColumnsByWidth: TMenuItem
          Tag = -1
          AutoCheck = True
          Caption = 'By window width'
          RadioItem = True
          OnClick = MIColumns8Click
        end
      end
    end
    object est1: TMenuItem
      Caption = 'Test'
      object Regions1: TMenuItem
        Caption = 'Regions'
        OnClick = Regions1Click
      end
      object Copyas6Nwords1: TMenuItem
        Caption = 'Copy as 6*N words'
        OnClick = Copyas6Nwords1Click
      end
      object N1: TMenuItem
        Caption = 'Compress'
        OnClick = N1Click
      end
      object Decompress1: TMenuItem
        Caption = 'Decompress'
        OnClick = Decompress1Click
      end
      object abs1: TMenuItem
        Caption = 'Tabs'
        OnClick = abs1Click
      end
    end
  end
  object OpenDialog1: TOpenDialog
    Left = 248
    Top = 72
  end
  object ActionList1: TActionList
    Images = ImageList16
    Left = 48
    Top = 69
    object ActionNew: TAction
      Category = 'File'
      Caption = 'New'
      Hint = 'New file'
      ImageIndex = 0
      ShortCut = 16462
      OnExecute = ActionNewExecute
    end
    object ActionOpen: TAction
      Category = 'File'
      Caption = 'Open'
      Hint = 'Open file...'
      ImageIndex = 1
      ShortCut = 16463
      OnExecute = ActionOpenExecute
    end
    object ActionSave: TAction
      Category = 'File'
      Caption = 'Save'
      Hint = 'Save file'
      ImageIndex = 2
      ShortCut = 16467
      OnExecute = ActionSaveExecute
    end
    object ActionSaveAs: TAction
      Category = 'File'
      Caption = 'Save as...'
      Hint = 'Save file as...'
      ImageIndex = 2
      OnExecute = ActionSaveAsExecute
    end
    object ActionCut: TAction
      Category = 'Edit'
      Caption = 'Cut'
    end
    object ActionCopy: TAction
      Category = 'Edit'
      Caption = 'Copy'
      OnExecute = ActionCopyExecute
    end
    object ActionCopyAs: TAction
      Category = 'Edit'
      Caption = 'Copy as...'
    end
    object ActionPaste: TAction
      Category = 'Edit'
      Caption = 'Paste'
      OnExecute = ActionPasteExecute
    end
    object ActionSelectAll: TAction
      Category = 'Edit'
      Caption = 'Select all'
      OnExecute = ActionSelectAllExecute
    end
    object ActionGoToStart: TAction
      Category = 'Navigation'
      Caption = 'Go to start of file'
      OnExecute = ActionGoToStartExecute
    end
    object ActionGoToEnd: TAction
      Category = 'Navigation'
      Caption = 'Go to end of file'
      OnExecute = ActionGoToEndExecute
    end
    object ActionRevert: TAction
      Category = 'File'
      Caption = 'Revert'
      Hint = 'Revert unsaved changes'
      OnExecute = ActionRevertExecute
    end
    object ActionFind: TAction
      Category = 'Edit'
      Caption = 'Find/Replace...'
      Hint = 'Find/Replace text or data'
      ImageIndex = 3
      OnExecute = ActionFindExecute
    end
    object ActionFindNext: TAction
      Category = 'Edit'
      Caption = 'Find Next'
      ShortCut = 114
      OnExecute = ActionFindNextExecute
    end
    object ActionFindPrev: TAction
      Category = 'Edit'
      Caption = 'Find Previous'
      ShortCut = 8306
      OnExecute = ActionFindPrevExecute
    end
    object ActionGoToAddr: TAction
      Category = 'Navigation'
      Caption = 'Go To address...'
      ShortCut = 16455
      OnExecute = ActionGoToAddrExecute
    end
    object ActionSaveSelectionAs: TAction
      Category = 'File'
      Caption = 'Save selection as...'
      OnExecute = ActionSaveSelectionAsExecute
    end
    object ActionExit: TAction
      Category = 'File'
      Caption = 'Exit'
      ImageIndex = 6
      OnExecute = ActionExitExecute
    end
    object ActionOpenDisk: TAction
      Category = 'File'
      Caption = 'Open Disk...'
      Hint = 'Open logical volume'
      ImageIndex = 4
      OnExecute = ActionOpenDiskExecute
    end
    object ActionOpenProcMemory: TAction
      Category = 'File'
      Caption = 'Open Process Memory...'
      ImageIndex = 5
      OnExecute = ActionOpenProcMemoryExecute
    end
    object ActionBitsEditor: TAction
      Category = 'Edit'
      Caption = 'Edit Bits'
      OnExecute = ActionBitsEditorExecute
    end
  end
  object SaveDialog1: TSaveDialog
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 248
    Top = 136
  end
  object ImageList16: TImageList
    Left = 364
    Top = 69
    Bitmap = {
      494C010108004001DC0010001000FFFFFFFFFF10FFFFFFFFFFFFFFFF424D3600
      0000000000003600000028000000400000003000000001002000000000000030
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000091908F008F8F
      8D008E8D8C008D8C8B008B8A89008A8988008888860087868500868583008484
      82008382800082817F0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000097928F0097928F0097928F009792
      8F0097928F0097928F0097928F0097928F0097928F0097928F0097928F009792
      8F0097928F0097928F0097928F0097928F000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000092929000FBFB
      FA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFB
      FA00FBFBFA008382800000000000000000000000000000000000000000000000
      0000000000000000000000000000F6F6F600EEEEEE00F4F4F400FDFDFD000000
      00000000000000000000000000000000000097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000093939200FCFB
      FB00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADAD
      AD00FBFBFA008484820000000000000000000000000000000000000000000000
      0000FDFDFD00F1F1F100D9D9D900ABABAB008A8A8A00A3A3A300D0D0D000EDED
      ED00FAFAFA0000000000000000000000000097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000095949300FCFB
      FB00F8F7F600F8F7F600F8F7F600F8F7F600F7F7F600F7F6F500F7F6F500F7F6
      F500FBFBFA008685830000000000000000000000000000000000FAFAFA00EDED
      ED00CFCFCF0093939300676767008E848400524D4D004A4A4A005D5D5D008989
      8900C0C0C000E5E5E500F6F6F6000000000097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F00676E74005C63640065696D00676A
      6E0063676B006367690065666B0062656A005B6162006569690063676C00666B
      6F00696C71006B6C6F00686C6E006D727600000000000000000096969500FCFC
      FB00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADAD
      AD00FBFBFA0087868500000000000000000000000000EBEBEB00C0C0C0008181
      8100757575008D8D8D00A5A5A500757070003F3C3C00494444005A5252004E4C
      4C005656560072727200A8A8A800DCDCDC0097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F002C2F360038353700383734003937
      3400393734003837350037373700383838003536340037383200363731003737
      3500363531003836340038383500262A2E00000000000000000097979600FCFC
      FB00F9F8F700F9F8F700F9F8F700F8F8F700F8F7F600F8F7F600F8F7F600F7F6
      F600FBFBFA00888886000000000000000000F1F1F1008989890089898900C9C9
      C900A3A3A30080808000828282007D7C7C004E4E4E00717171007D7D7D00746E
      6E007465650056515100525252007B7B7B0097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F00414648000000000000000A000000
      0B0000000B0000000D00000000000000000000000A0000002A00000027000000
      000000002100000021000000000041414400000000000000000099989800FCFC
      FC00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADAD
      AD00FBFBFB008A8988000000000000000000A6A6A600AEAEAE00989898008282
      8200A4A4A400B9B9B900D1D1D1008E8E8E00797979006C6C6C00818181006262
      620034343400B79898008A7777006B6B6B0097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F003D4345000100230004046C000304
      5E0006055C00030352000405600000002D0004035C0002016B00030674000000
      260006056E0001005100000000003F3F430000000000000000009A9A9900FDFC
      FC00F9F9F800F9F9F800F9F8F800F9F8F700F9F8F700F9F8F700F8F7F700F8F7
      F600FCFBFB008B8A89000000000000000000A0A0A0009C9C9C00B5B5B500C7C7
      C700E1E1E100E6E6E600D0D0D000D8D8D800D1D1D100C3C3C3009A9999007D78
      78004643430093818100847676007D7D7D0097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F004043460000002900040477000100
      6800040455000000000003015700060693000102650000005600040692000000
      40000203890002005800000000003E41420000000000000000009B9B9B00FDFC
      FC00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADAD
      AD00FCFBFB008D8C8B000000000000000000BABABA00D3D3D300DEDEDE00C7C7
      C700E1E1E100DFDFDF00F2F2F200FCFCFC00ECECEC00DFDFDF00F7F7F700EEEA
      EA00DECCCC008F8A8A008D898900E7E7E70097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F00454642000000330007078E000202
      8100020368000405450006048A000302920003038400000070000605AA000000
      54000604A10002027700040331003C3D420000000000000000009D9D9C00FDFC
      FC00FAF9F900FAF9F800FAF9F800FAF9F800F9F9F800F9F8F700F9F8F700F8F8
      F700FCFBFB008E8D8C000000000000000000E3E3E300E0E0E000BBBBBB007979
      79006C6C6C00B8B8B800F2F2F200FCFCFC00ECECEC00DFDFDF00F7F7F700CACA
      CA00C1C1C100CBCBCB00F9F9F9000000000097928F0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000097928F0046454100000038000604A0000303
      A8000203A7000000A40001017F0000005700010080000202B0000406AB000502
      A9000304BA000202B4000B088E003A39430000000000000000009E9E9E00FDFD
      FC00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00ADAD
      AD00FCFBFB008F8F8D000000000000000000000000000000000000000000ECEC
      EC00DBDBDB00C8C8C800D5D5D500E6E6E600CDCDCD00D4D4D400D4D4D400FCFC
      FC000000000000000000000000000000000097928F00CDCCCA00CDCCCA00CDCC
      CA00CDCCCA00CDCCCA00CDCCCA00CDCCCA00CDCCCA00CDCCCA00CDCCCA00CDCC
      CA00CDCCCA00CDCCCA00CDCCCA0097928F0042424200181922001A1B37001C1A
      3C001C1B3D001D1C3C00171827001A19220018182A001719250014140C001616
      0F0015150D0015150D0012140F003F3F3F000000000000000000A09F9F00FDFD
      FD00FAFAF900FAFAF900FAF9F900FAF9F800FAF9F800F9F9F800F9F8F800F9F8
      F700FCFBFB0091908F0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000097928F00E0D9D300E0D9D300E0D9
      D300E0D9D300E0D9D300E0D9D300E0D9D300E0D9D300E0D9D30091796800E0D9
      D30091796800E0D9D3009179680097928F000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000A1A1A100FDFD
      FD00ADADAD00ADADAD00ADADAD00ADADAD00ADADAD00F9F9F800A6A6A6008C8C
      8C008C8C8C009292900000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000097928F0097928F0097928F009792
      8F0097928F0097928F0097928F0097928F0097928F0097928F0097928F009792
      8F0097928F0097928F0097928F0097928F000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000A2A2A200FDFD
      FD00FBFBFA00FBFAFA00FAFAF900FAF9F900FAF9F800FAF9F800A6A6A600EAEA
      EA00D5D5D5009F9E9E0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000A4A4A300FDFD
      FD00FDFDFD00FDFDFD00FDFDFC00FDFCFC00FDFCFC00FDFCFC00A6A6A600D6D6
      D600A1A1A000EBEBEB0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000A5A5A500A4A4
      A300A2A2A200A1A1A100A09F9F009E9E9E009D9D9C009B9B9B009A9A9900A3A3
      A300EBEBEB00000000000000000000000000000000000000000091908F008F8F
      8D008E8D8C008D8C8B008B8A89008A8988008888860087868500868583008484
      82008382800082817E00000000000000000000000000F1F8FC00D8EBF500BDDD
      EF009FCDE70085BFE00053A1CB00C7D6DD00EDF2F40000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000092929000FBFB
      FA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFBFA00FBFB
      FA00FBFBFA00838280000000000000000000000000004CABD70043ACD80044B1
      DB0048B9DF004BBFE3002C8FC300358CB300388FB600389ECD00379DCD00369C
      CC0045A3CF008DC6E100000000000000000000000000B99FAB00BA698E00A666
      7E009D9B9A00969291008B8381008A8685008582810082807F0087858500726E
      6E00874B68009E5B7C008A627400000000000000000000000000000000009090
      9000636363005E5E5E005E5E5E005E5E5E005E5E5E005E5E5E005E5E5E006262
      62008A8A8A00000000000000000000000000000000000000000093939200FCFB
      FB00F8F7F600F8F7F600F7F6F600F7F6F500F7F6F500F7F6F500F7F6F500F7F6
      F500FBFBFA00848482000000000000000000000000003CA6D5006AD8EF0064D5
      EE005FD2EC005ACFEB003396C7004EA7C00052AAC30060CAE30063CBE30067CD
      E40066C8E20045A3CF00000000000000000000000000D175A000CB6C9800C75A
      8300C5C3C200AF799200B04A7B009A959400979493008986850085828100706A
      680096436D00B45F8900905A7300000000000000000000000000464646000D0D
      0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D
      0D000D0D0D003B3B3B000000000000000000000000000000000095949300FCFB
      FB00F8F7F600F8F7F600F8F7F600F8F7F600F7F7F600F7F6F500F7F6F500F7F6
      F500FBFBFA008685830000000000000000000000000038A6D60073DDF1006CD9
      F00066D6EE0061D3ED003398C8004AA6BF004CA8C20057C5E0005AC7E10060C9
      E200D9B66C00379CCC00000000000000000000000000CE7AA100C76D9600C75A
      8300DDDBDB00BD8BA200B34E7D00B0ABAA00AFADAC009C99980092908E00726D
      6B0095426C00B05D8400925D75000000000000000000959595000D0D0D000D0D
      0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D0D000D0D0D001E1E1E009393
      9300393939000D0D0D008787870000000000000000000000000096969500FCFC
      FB00F8F7F700F8F7F700F8F7F600F8F7F600F8F7F600F8F7F600F7F6F500F7F6
      F500FBFBFA00878685000000000000000000000000003AA9D8007CE2F40075DE
      F2006EDBF00068D7EF00359ACA004CA7C0004DA8C30055C4E00054C4E0005AC7
      E100E1C47600389DCD00000000000000000000000000CF7DA300C9719A00C75A
      8300F4F2F200CC9BB100B7528100D7D3D200E2E2E200C4C2C200B4B2B2008580
      7F0098426C00B05B8500945F770000000000000000006B6B6B000D0D0D000D0D
      0D000D0D0D00121212004C4C4C0066666600404040001E1E1E00BEBEBE00FFFF
      FF00979797000D0D0D005D5D5D0000000000000000000000000097979600FCFC
      FB00F9F8F700F9F8F700F9F8F700F8F8F700F8F7F600F8F7F600F8F7F600F7F6
      F600FBFBFA00888886000000000000000000000000003BACDA0084E7F6007EE3
      F40077DFF20071DCF100379DCC0052AAC10052ABC4005BC7E10059C6E1005BC7
      E100EEEFEF00399FCE00000000000000000000000000D081A500CA759C00C167
      9200C193A900B889A100A5668600C49DB000C6A6B700BB99A900B391A1009C68
      800094446C00AD588100966079000000000000000000676767000F0F0F000F0F
      0F003D3D3D00CACACA00F2F2F200D9D9D900F5F5F500DEDEDE00FFFFFF00C3C3
      C300242424000F0F0F005959590000000000000000000000000099989800FCFC
      FC00F9F8F800F9F8F700F9F8F700F9F8F700F8F8F700F8F7F700F8F7F600F8F7
      F600FBFBFB008A8988000000000000000000000000003DB0DC008DEBF80087E8
      F60080E4F50079E1F3003AA1CE005AAEC4005AAFC60092DAEA00AFE2EE0090D9
      E900EEEFEF003BA0CF00000000000000000000000000D384AA00C4769900C27D
      9D00B9709200B96D8E00B9709200B6668900B4628700B3618600B15F8300B161
      8300B2648600B656830097617A00000000000000000068686800121212002121
      2100D8D8D800A8A8A8002B2B2B00121212003B3B3B00C5C5C500E1E1E1002727
      270012121200121212005A5A5A000000000000000000000000009A9A9900FDFC
      FC00F9F9F800F9F9F800F9F8F800F9F8F700F9F8F700F9F8F700F8F7F700F8F7
      F600FCFBFB008B8A89000000000000000000000000003FB2DE0095F0FA008FEC
      F80089E9F70082E5F5003EA5D00064B2C60090C9D700B7E6F000AF683900B5E5
      EF00EEEFEF003CA2D000000000000000000000000000D283A700C98FA800B076
      8E00DDC6CB00FBFCFC00FAFAFB00F9FAFA00F8F9F800F7F8F800F6F7F800DDC6
      CB00BE889800C2669100985F7900000000000000000069696900161616007272
      7200D8D8D8001F1F1F0016161600161616001616160039393900F4F4F4004949
      490016161600161616005C5C5C000000000000000000000000009B9B9B00FDFC
      FC00FAF9F800FAF9F800FAF9F800F9F9F800F9F8F800F9F8F700F8F8F700F8F7
      F600FCFBFB008D8C8B0000000000000000000000000040B5DF009CF4FC0097F1
      FA0091EEF9008BEAF70041A9D20097CBD700B4D9E200AF683900AF683900BBE8
      F100A3E1EE003EA4D100000000000000000000000000D387A900CB96AE00B076
      8E00FDFDFC00FBFCFC00FBFBFB00FAFAFA00F9FAFA00F7F8F900F6F8F800FCFD
      FB00BE889800C66B95009A617C0000000000000000006B6B6B00191919009393
      9300AAAAAA001919190019191900191919001919190018181800D2D2D2006F6F
      6F0019191900191919005D5D5D000000000000000000000000009D9D9C00FDFC
      FC00FAF9F900FAF9F800FAF9F800FAF9F800F9F9F800F9F8F700F9F8F700F8F8
      F700FCFBFB008E8D8C0000000000000000000000000043B8E100A3F7FD009EF5
      FC0099F2FB0093EFFA007BC3DF00B8DBE200B9743900B9743900B9743900B974
      39009E9F8E0088ACB500000000000000000000000000D58CAD00CC9AB100B076
      8E00EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEA
      E500BE889800C96F98009D657F0000000000000000006C6C6C001D1D1D008282
      8200C6C6C6001E1E1E001D1D1D001D1D1D001D1D1D002B2B2B00EBEBEB005B5B
      5B001D1D1D001D1D1D005F5F5F000000000000000000000000009E9E9E00FDFD
      FC00FAFAF900FAF9F900FAF9F800FAF9F800FAF9F800F9F8F800F9F8F700F9F8
      F700FCFBFB008F8F8D0000000000000000000000000045BBE200A8FAFF00A4F8
      FE00A0F6FD009BF3FB00A2D5E700D9983900D9983900D9983900D9983900D998
      3900D9983900D9983900ECCB9C000000000000000000D790B000CE9CB400B076
      8E00FDFCFC00FDFEFE00FCFDFD00FBFCFC00FBFBFB00F9FAFA00F8F9FA00FDFC
      FB00BE889800CD729C00A067820000000000000000006F6F6F00212121004040
      4000EFEFEF0081818100212121002121210026262600A2A2A200D3D3D3002929
      2900212121002121210062626200000000000000000000000000A09F9F00FDFD
      FD00FAFAF900FAFAF900FAF9F900FAF9F800FAF9F800F9F9F800F9F8F800F9F8
      F700FCFBFB0091908F0000000000000000000000000054C3E700A9FBFF00A9FA
      FF00A5F9FE00A1F6FD007FC9E100C1DFE400F7BC3900F7BC3900F7BC3900DDD1
      880093B29100F7BC3900F7BC3900F7BC390000000000D794B400D09FB500B076
      8E00EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEAE500EEEA
      E500BE889800D0769F00A26B8500000000000000000074747400252525002525
      25006E6E6E00EFEFEF00C3C3C300A7A7A700D1D1D100E0E0E000535353002525
      2500252525002525250068686800000000000000000000000000A1A1A100FDFD
      FD00FBFAFA00FAFAF900FAFAF900FAF9F900FAF9F800F9F9F800A6A6A6008C8C
      8C008C8C8C00929290000000000000000000000000005BC5E700A9FBFF00A9FB
      FF00A9FBFF00A7F9FE004EB7DA00ADD6DD00C4E1E600FBC83700FBC83700D7F5
      F80046ACD7000000000000000000FBC8370000000000D99CB800CDCDCD00B076
      8E00FDFDFC00FDFEFE00FDFEFE00FDFDFD00FCFDFD00FAFCFC00FAFAFB00FDFD
      F900BE889800CDCDCD00A9768E0000000000000000009B9B9B00282828002929
      290029292900484848008A8A8A009B9B9B00808080003A3A3A00292929002929
      290029292900292929008F8F8F00000000000000000000000000A2A2A200FDFD
      FD00FBFBFA00FBFAFA00FAFAF900FAF9F900FAF9F800FAF9F800A6A6A600EAEA
      EA00D5D5D5009F9E9D000000000000000000000000005CC6E700A9FBFF00A9FB
      FF009DF3FC0083E2F4004FB9DB0094CCD500CAEFF300DEF9FA00DAB53300DDF7
      F90048AED8000000000000000000F5ECCB0000000000BD9AAA009B678100B076
      8E00F9F8F700F7F5F300F5F4EF00F3F1EC00F2F1EA00F2F1E900EEEAE400EEEA
      E400BE8898009B678100A68896000000000000000000000000005B5B5B002B2B
      2B002C2C2C002C2C2C002C2C2C002C2C2C002C2C2C002C2C2C002C2C2C002C2C
      2C002B2B2B005050500000000000000000000000000000000000A4A4A300FDFD
      FD00FDFDFD00FDFDFD00FDFDFC00FDFCFC00FDFCFC00FDFCFC00A6A6A600D6D6
      D600A1A1A000EBEAEA000000000000000000000000005FC8E8008DE6F5007EDA
      F0007EDAF00095E3F40096D4DE00C4F7FA00C8FBFD00D7FAFB00E2F9FA00CAF2
      F80058B5DB0000000000000000000000000000000000E5B7CE00D887AD00D887
      AD00D887AD00D887AD00D887AD00D887AD00D887AD00D887AD00D887AD00D887
      AD00D887AD00D887AD00B1879A00000000000000000000000000000000009C9C
      9C00787878007474740074747400747474007474740074747400747474007777
      7700979797000000000000000000000000000000000000000000A5A5A500A4A4
      A300A2A2A200A1A1A100A09F9F009E9E9E009D9D9C009B9B9B009A9A9900A3A3
      A300EBEBEB000000000000000000000000000000000079D0EB0069C9E9005FC3
      E6005EC1E5005CC0E4005ABEE30058BCE10055BAE00054B8DF0051B6DD005CB9
      DE009AD2E9000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000424D3E000000000000003E000000
      2800000040000000300000000100010000000000800100000000000000000000
      000000000000000000000000FFFFFF0000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000FFFFFFFFFFFFC003FFFF0000FFFFC003
      FE1F0000FFFFC003F0070000FFFFC003C00100000000C003800000000000C003
      000000000000C003000000000000C003000000000000C003000000000000C003
      000100000000C003E00F00000000C003FFFF0000FFFFC003FFFF0000FFFFC003
      FFFFFFFFFFFFC003FFFFFFFFFFFFC007C003807FFFFFFFFFC00380038001E007
      C00380038001C003C003800380018001C003800380018001C003800380018001
      C003800380018001C003800380018001C003800380018001C003800380018001
      C003800180018001C003800080018001C003800680018001C00380068001C003
      C00380078001E007C0078007FFFFFFFF00000000000000000000000000000000
      000000000000}
  end
  object RecentFilesMenu: TPopupMenu
    AutoHotkeys = maManual
    OnPopup = RecentFilesMenuPopup
    Left = 144
    Top = 136
    object MIDummyRecentFile1: TMenuItem
      Caption = 'MIDummyRecentFile'
      Visible = False
    end
  end
  object EditorClosedTimer: TTimer
    Enabled = False
    Interval = 1
    OnTimer = EditorClosedTimerTimer
    Left = 48
    Top = 224
  end
end
