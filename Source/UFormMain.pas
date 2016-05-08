{*******************************************************************************
  ����: dmzn@163.com 2016-05-05
  ����: ����ת���������
*******************************************************************************}
unit UFormMain;

{$I Link.inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  CPort, CPortTypes, UTrayIcon, cxGraphics, cxControls, cxLookAndFeels,
  cxLookAndFeelPainters, cxContainer, cxEdit, IdContext, ExtCtrls,
  IdBaseComponent, IdComponent, IdCustomTCPServer, IdTCPServer, StdCtrls,
  cxTextEdit, cxLabel, cxCheckBox, dxNavBarCollns, cxClasses, dxNavBarBase,
  dxNavBar, ComCtrls;

type
  TCOMItem = record
    FItemName: string;            //�ڵ���
    FItemGroup: string;           //�ڵ����
    FPortName: string;            //�˿�����
    FBaudRate: TBaudRate;         //������
    FDataBits: TDataBits;         //����λ
    FStopBits: TStopBits;         //��ͣλ

    FCOMObject: TComPort;         //���ڶ���
    FMemo: string;                //������Ϣ
    FBuffer: string;              //���ݻ���
    FData: string;                //Э������
    FDataLast: Int64;             //����ʱ��
  end;

  PDataItem = ^TDataItem;
  TDataItem = record
    Fsoh    : array[0..0] of Char;    //Э��ͷ
    Fno     : array[0..0] of Char;    //��������
    Fylr    : array[0..4] of Char;    //Զ������ƫ��
    Fyud    : array[0..4] of Char;    //Զ�����±���
    Fyi     : array[0..3] of Char;    //Զ��ǿ��
    Fjh     : array[0..2] of Char;    //����Ƹ�
    Fjlr    : array[0..4] of Char;    //��������ƫ��
    Fjud    : array[0..4] of Char;    //��������ƫ��
    Fjp     : array[0..3] of Char;    //�Ƹ߱�ֵ
    Fend    : array[0..0] of Char;    //Э��β
  end;

  TfFormMain = class(TForm)
    MemoLog: TMemo;
    StatusBar1: TStatusBar;
    IdTCPServer1: TIdTCPServer;
    Timer1: TTimer;
    dxNavBar1: TdxNavBar;
    dxNavGroup1: TdxNavBarGroup;
    dxNavGroup2: TdxNavBarGroup;
    dxNavGroup2Control: TdxNavBarGroupControl;
    CheckAuto: TcxCheckBox;
    CheckSrv: TcxCheckBox;
    CheckAdjust: TcxCheckBox;
    EditPort: TcxTextEdit;
    cxLabel1: TcxLabel;
    HintPanel: TPanel;
    Image1: TImage;
    Image2: TImage;
    Bevel1: TBevel;
    dxNavGroup1Control: TdxNavBarGroupControl;
    CheckLoged: TcxCheckBox;
    HintLabel: TLabel;
    BtnRefresh: TcxLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckSrvClick(Sender: TObject);
    procedure CheckLogedClick(Sender: TObject);
    procedure IdTCPServer1Execute(AContext: TIdContext);
    procedure dxNavGroup2Expanded(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
  private
    { Private declarations }
    FTrayIcon: TTrayIcon;
    {*״̬��ͼ��*}
    FCOMPorts: array of TCOMItem;
    //���ڶ���
    procedure ShowLog(const nStr: string);
    //��ʾ��־
    procedure DoExecute(const nContext: TIdContext);
    //ִ�ж���
    procedure LoadCOMConfig;
    //��������
    function FindCOMItem(const nCOM: TObject): Integer; overload;
    function FindSameGroup(const nIdx: Integer): Integer; overload;
    //��������
    procedure RedirectData(const nItem,nGroup: Integer; const nData: string);
    procedure ParseProtocol(const nItem,nGroup: Integer);
    procedure OnCOMData(Sender: TObject; Count: Integer);
    //���ݴ���
    function AdjustProtocol(const nData: PDataItem): Boolean;
    //У������
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}
uses
  IniFiles, Registry, ULibFun, USysLoger, UFormInputbox;

const
  cChar_Head          = Char($01);               //Э��ͷ
  cChar_End           = Char($FF);               //Э��β
  cSizeData           = SizeOf(TDataItem);       //���ݴ�С

var
  gPath: string;                        //����·��

resourcestring
  sHint               = '��ʾ';
  sConfig             = 'Config.Ini';
  sAutoStartKey       = 'COMServer';

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TfFormMain, '���ڷ���', nEvent);
end;

//------------------------------------------------------------------------------
procedure TfFormMain.FormCreate(Sender: TObject);
var nIni: TIniFile;
    nReg: TRegistry;
begin
  Randomize;
  gPath := ExtractFilePath(Application.ExeName);
  InitGlobalVariant(gPath, gPath+sConfig, gPath+sConfig);

  gSysLoger := TSysLoger.Create(gPath + 'Logs\');
  gSysLoger.LogEvent := ShowLog;

  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.Hint := Application.Title;
  FTrayIcon.Visible := True;

  CheckLoged.Checked := True;
  {$IFNDEF DEBUG}  
  dxNavGroup2.OptionsExpansion.Expanded := False;
  {$ENDIF}

  nIni := nil;
  nReg := nil;
  try
    nIni := TIniFile.Create(gPath + 'Config.ini');
    EditPort.Text := nIni.ReadString('Config', 'Port', '8000');

    Timer1.Enabled := nIni.ReadBool('Config', 'Enabled', False);
    CheckAdjust.Checked := nIni.ReadBool('Config', 'CloseAdjust', False);

    nReg := TRegistry.Create;
    nReg.RootKey := HKEY_CURRENT_USER;

    nReg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True);
    CheckAuto.Checked := nReg.ValueExists(sAutoStartKey);
    LoadFormConfig(Self, nIni);
  finally
    nIni.Free;
    nReg.Free;
  end;

  SetLength(FCOMPorts, 0);
  LoadCOMConfig;
  //��ȡ��������
end;

procedure TfFormMain.FormClose(Sender: TObject; var Action: TCloseAction);
var nIni: TIniFile;
    nReg: TRegistry;
begin
  nIni := nil;
  nReg := nil;
  try
    nIni := TIniFile.Create(gPath + 'Config.ini');
    nIni.WriteBool('Config', 'Enabled', CheckSrv.Checked);
    nIni.WriteBool('Config', 'CloseAdjust', CheckAdjust.Checked);
    SaveFormConfig(Self, nIni);

    if nIni.ReadString('Config', 'Port', '') = '' then
      nIni.WriteString('Config', 'Port', EditPort.Text);
    //xxxxx

    nReg := TRegistry.Create;
    nReg.RootKey := HKEY_CURRENT_USER;

    nReg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True);
    if CheckAuto.Checked then
      nReg.WriteString(sAutoStartKey, Application.ExeName)
    else if nReg.ValueExists(sAutoStartKey) then
      nReg.DeleteValue(sAutoStartKey);
    //xxxxx
  finally
    nIni.Free;
    nReg.Free;
  end;
end;

procedure TfFormMain.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  CheckSrv.Checked := True;

  {$IFNDEF DEBUG}
  if CheckSrv.Checked then
    FTrayIcon.Minimize;
  //xxxxx
  {$ENDIF}
end;

procedure TfFormMain.CheckSrvClick(Sender: TObject);
var nIdx,nErr: Integer;
begin
  nErr := 0;
  for nIdx:=Low(FCOMPorts) to High(FCOMPorts) do
   with FCOMPorts[nIdx] do
    if Assigned(FCOMObject) then
    try
      if CheckSrv.Checked then
           FCOMObject.Open
      else FCOMObject.Close;
    except
      on E:Exception do
      begin
        Inc(nErr);
        FMemo := E.Message;
        WriteLog(E.Message);
      end;
    end;

  if nErr > 0 then
  begin
    CheckSrv.Checked := False;
    Exit;
  end; //any error

  if not IdTCPServer1.Active then
    IdTCPServer1.DefaultPort := StrToInt(EditPort.Text);
  IdTCPServer1.Active := CheckSrv.Checked;
  EditPort.Enabled := not CheckSrv.Checked;
end;

procedure TfFormMain.CheckLogedClick(Sender: TObject);
begin
  gSysLoger.LogSync := CheckLoged.Checked;
end;

procedure TfFormMain.ShowLog(const nStr: string);
var nIdx: Integer;
begin
  MemoLog.Lines.BeginUpdate;
  try
    MemoLog.Lines.Insert(0, nStr);
    if MemoLog.Lines.Count > 100 then
     for nIdx:=MemoLog.Lines.Count - 1 downto 50 do
      MemoLog.Lines.Delete(nIdx);
  finally
    MemoLog.Lines.EndUpdate;
  end;
end;

procedure TfFormMain.BtnRefreshClick(Sender: TObject);
var nIdx: Integer;
begin
  MemoLog.Clear;
  MemoLog.Lines.Add('ˢ���豸�б�:');

  for nIdx:=Low(FCOMPorts) to High(FCOMPorts) do
  with FCOMPorts[nIdx],MemoLog.Lines do
  begin
    Add('�豸: ' + IntToStr(nIdx+1));
    Add('|--- ����: ' + FItemName);
    Add('|--- ����: ' + FItemGroup);
    Add('|--- �˿�: ' + FPortName);
    Add('|--- ����: ' + BaudRateToStr(FBaudRate));
    Add('|--- ��λ: ' + DataBitsToStr(FDataBits));
    Add('|--- ͣλ: ' + StopBitsToStr(FStopBits));
    Add('|--- ��ע: ' + FMemo);
    Add('');
  end;
end;

procedure TfFormMain.dxNavGroup2Expanded(Sender: TObject);
var nStr: string;
begin
  if ShowInputPWDBox('���������Ա����:', '', nStr) then
       dxNavGroup2.OptionsExpansion.Expanded := nStr = 'admin'
  else dxNavGroup2.OptionsExpansion.Expanded := False;
end;

//------------------------------------------------------------------------------
procedure TfFormMain.IdTCPServer1Execute(AContext: TIdContext);
begin
  try
    DoExecute(AContext);
  except
    on E:Exception do
    begin
      WriteLog(E.Message);
      AContext.Connection.Socket.InputBuffer.Clear;
    end;
  end;
end;

procedure TfFormMain.DoExecute(const nContext: TIdContext);
begin
  //
end;

//Desc: ��ȡ����
procedure TfFormMain.LoadCOMConfig;
var nIdx: Integer;
    nIni: TIniFile;
    nList: TStrings;
begin
  nList := TStringList.Create;
  nIni := TIniFile.Create(gPath + 'Ports.ini');
  try
    nIni.ReadSections(nList);
    SetLength(FCOMPorts, nList.Count);

    for nIdx:=nList.Count-1 downto 0 do
    with FCOMPorts[nIdx],nIni do
    begin
      FItemName  := ReadString(nList[nIdx], 'Name', '');
      FItemGroup := ReadString(nList[nIdx], 'Group', '');
      FPortName  := ReadString(nList[nIdx], 'PortName', '');
      FBaudRate  := StrToBaudRate(ReadString(nList[nIdx], 'BaudRate', '9600'));
      FDataBits  := StrToDataBits(ReadString(nList[nIdx], 'DataBits', '8'));
      FStopBits  := StrToStopBits(ReadString(nList[nIdx], 'StopBits', '1'));

      FBuffer := '';
      FData := '';
      FDataLast := 0;
      FCOMObject := nil;

      if ReadInteger(nList[nIdx], 'Enable', 0) <> 1 then
      begin
        FMemo := '�˿ڽ���';
        Continue;
      end;

      FMemo := '�˿�����';
      FCOMObject := TComPort.Create(Application);
      
      with FCOMObject do
      begin
        Port := FPortName;
        BaudRate := FBaudRate;
        FDataBits := FDataBits;
        FStopBits := FStopBits;
        OnRxChar := OnCOMData;
      end;

      with FCOMObject.Timeouts do
      begin
        ReadTotalConstant := 100;
        ReadTotalMultiplier := 10;
      end;  
    end;
  finally
    nList.Free;
    nIni.Free;
  end;   
end;

//Date: 2016-05-05
//Parm: ���ڶ���
//Desc: ����nCOM��Ӧ����
function TfFormMain.FindCOMItem(const nCOM: TObject): Integer;
var nIdx: Integer;
begin
  Result := -1;
  for nIdx:=Low(FCOMPorts) to High(FCOMPorts) do
  if FCOMPorts[nIdx].FCOMObject = nCOM then
  begin
    Result := nIdx;
    Break;
  end;
end;

//Date: 2016-05-05
//Parm: ���ڶ�������
//Desc: ����nIdx��ͬ�����
function TfFormMain.FindSameGroup(const nIdx: Integer): Integer;
var i: Integer;
begin
  Result := -1;
  for i:=Low(FCOMPorts) to High(FCOMPorts) do
  if (CompareText(FCOMPorts[i].FItemGroup, FCOMPorts[nIdx].FItemGroup) = 0) and
     (i <> nIdx) then
  begin
    Result := i;
    Break;
  end;
end;

//------------------------------------------------------------------------------
//Date: 2016-05-05
//Parm: ����;���ݴ�С
//Desc: ����������
procedure TfFormMain.OnCOMData(Sender: TObject; Count: Integer);
var nStr: string;
    nIdx,nInt: Integer;
    nItem,nGroup: Integer;
begin
  try
    nItem := FindCOMItem(Sender);
    if (nItem < 0) or (FCOMPorts[nItem].FCOMObject = nil) then
    begin
      WriteLog('�յ�����,���޷�ƥ�䴮�ڶ���.');
      Exit;
    end;

    with FCOMPorts[nItem] do
    begin
      FCOMObject.ReadStr(FBuffer, Count);
      nStr := '';
      nInt := Length(FBuffer);

      for nIdx:=1 to nInt do
        nStr := nStr + IntToHex(Ord(FBuffer[nIdx]), 2) + ' ';
      //ʮ������

      nStr := Format('�˿�:[ %s ] ����:[ %s ]', [FItemName, nStr]);
      WriteLog(nStr);
    end; //��ȡ����

    nGroup := FindSameGroup(nItem);
    if (nGroup < 0) or (FCOMPorts[nGroup].FCOMObject = nil) then
    begin
      nStr := '�յ�����,���޷�ƥ�䴮��[ %s ]ͬ�����.';
      WriteLog(Format(nStr, [FCOMPorts[nItem].FItemName]));
      Exit;
    end;

    if CheckAdjust.Checked then
         RedirectData(nItem, nGroup, FCOMPorts[nItem].FBuffer)  //ֱ��ת��
    else ParseProtocol(nItem, nGroup);                          //����Э��
  except
    on E: Exception do
    begin
      WriteLog(E.Message);
    end;
  end;
end;

//Date: 2016/5/6
//Parm: Դ�˿�;Ŀ��˿�;����
//Desc: ��nData����ת����nGroup�˿�
procedure TfFormMain.RedirectData(const nItem,nGroup: Integer;
 const nData: string);
var nStr: string;
begin
  FCOMPorts[nGroup].FCOMObject.WriteStr(nData);
  //xxxxx
  
  nStr := '�˿�:[ %s ] ����:[ ת���� %s ]';
  nStr := Format(nStr, [FCOMPorts[nItem].FItemName, FCOMPorts[nGroup].FItemName]);
  WriteLog(nStr);
end;

//Date: 2016/5/6
//Parm: Դ�˿�;ת���˿�
//Desc: ����nItem�˿�����,У����������������,Ȼ��ת����nGroup�˿�
procedure TfFormMain.ParseProtocol(const nItem, nGroup: Integer);
var i,nS,nE,nPos: Integer;
    nData: TDataItem;
    nBuf: array[0..cSizeData-1] of Char;
begin
  with FCOMPorts[nItem] do
  begin
    nE := Length(FData);
    if (nE > 0) and (GetTickCount - FDataLast >= 1500) then
    begin
      RedirectData(nItem, nGroup, FData);
      FData := '';
      nE := 0;
    end; //��ʱ����ֱ��ת��

    if nE > cSizeData then
    begin
      while nE > 0 do
      begin
        nPos := nE;
        Dec(nE);
        if FData[nPos] = cChar_Head then Break;
      end;

      if nE > 0 then
      begin
        RedirectData(nItem, nGroup, Copy(FData, 1, nE));
        System.Delete(FData, 1, nE);
      end;
    end; //���ݰ�����ʱ,���һ��Э��ͷλ��,��ǰ�������ת��

    //--------------------------------------------------------------------------
    nS := Pos(cChar_Head, FBuffer);
    if (nS < 1) and (FData = '') then
    begin
      RedirectData(nItem, nGroup, FBuffer);
      Exit;
    end; //��Э������ֱ��ת��

    FDataLast := GetTickCount;
    FData :=  FData + FBuffer;
    //�������ݴ�����

    nS := 0;
    nE := 0;
    nPos := Length(FData);

    for i:=nPos downto 1 do
    begin
      if FData[i] = cChar_End then
        nE := i;
      //xxxx

      if (FData[i] = cChar_Head) and (nE > 0) then
      begin
        nS := i;
        Break;
      end;
    end;

    if (nS < 1) or (nE-nS <> cSizeData-1) then
    begin
      if nE > 0 then
      begin
        RedirectData(nItem, nGroup, FData);
        FData := '';
      end;

      Exit;
    end; //δ�ҵ�����Э���

    //--------------------------------------------------------------------------
    StrPCopy(@nBuf[0], Copy(FData, nS, cSizeData));
    Move(nBuf, nData, cSizeData);
    //���Ƶ�Э���,׼������

    if AdjustProtocol(@nData) then
    begin
      SetString(FBuffer, PChar(@nData.Fsoh[0]), cSizeData);
      FData := Copy(FData, 1, nS-1) + FBuffer + Copy(FData, nE+1, nPos-nE+1);
    end;

    RedirectData(nItem, nGroup, FData);
    FData := '';
    //��������
  end;
end;

//Date: 2016/5/7
//Parm: Э������
//Desc: ����Э������,�б�ҪʱУ��
function TfFormMain.AdjustProtocol(const nData: PDataItem): Boolean;
var nStr,nSVal: string;
    nIdx,nInt: Integer;
    nPY,nDG,nDQ,nRnd,nVal: Double;
begin
  Result := False;
  {$IFDEF DEBUG}
  nStr := '����:[ ' + nData.Fjud + '] ' +
          '�Ƹ�:[ ' + nData.Fjh + '] ' +
          'ǿ��:[ ' + nData.Fyi + ']';
  WriteLog(nStr);
  {$ENDIF}

  nPY := StrToFloat(nData.Fjud);
  //����ƫ��
  nDG := StrToFloat(nData.Fjh);
  //�Ƹ�

  if (nPY <> 0) and (nDG <> 0) then
  begin
    nVal := (nDG - nPY) / nDG;
    nVal := Float2Float(nVal, 100, True);
    //��ֱƫ����

    if (nVal >= 0.80) or (nVal <= 0.70) then
    begin
      nRnd := Random(100);
      while (nRnd = 0) or (nRnd = 100) do
        nRnd := Random(100);
      //xxxxx

      if nRnd >= 10 then
        nRnd := nRnd / 10;
      nRnd := 0.7 + nRnd / 100;
      //���ֵ(0.71 - 0.79)

      nVal := nDG - nRnd * nDG;
      if nPY >= 0 then
           nSVal := '+' + FloatToStr(nVal)
      else nSVal := '-' + FloatToStr(nVal);

      nIdx := Length(nSVal);
      nInt := Length(nData.Fjud);
      if nIdx < nInt then
        nSVal := nSVal + StringOfChar('0', nInt-nIdx);
      //xxxxx

      nStr := Format('��ֱƫ��:[ %s -> %s ]', [Copy(nData.Fjud, 1, nInt),
                                               Copy(nSVal, 1, nInt)]);
      WriteLog(nStr);

      nInt := 1;
      for nIdx:=Low(nData.Fjud) to High(nData.Fjud) do
      begin
        nData.Fjud[nIdx] := nSVal[nInt];
        Inc(nInt);
      end;
      Result := True;
    end;
  end;

  //----------------------------------------------------------------------------
  nDQ := StrToFloat(nData.Fyi);
  //Զ��ǿ��

  if (nDQ > 50) and(nDQ < 150) then
  begin
    nDQ := 150 + Random(50);
    nSVal := FloatToStr(nDQ);

    nInt := Length(nData.Fyi) - Length(nSVal);
    if nInt > 0 then
      nSVal := StringOfChar('0', nInt) + nSVal;
    //xxxxx
    
    nInt := Length(nData.Fyi);
    nStr := Format('�ƹⲹ��:[ %s -> %s ]', [Copy(nData.Fyi, 1, nInt),
                                             Copy(nSVal, 1, nInt)]);
    WriteLog(nStr);

    nInt := 1;
    for nIdx:=Low(nData.Fyi) to High(nData.Fyi) do
    begin
      nData.Fyi[nIdx] := nSVal[nInt];
      Inc(nInt);
    end;
    Result := True;
  end; //�ƹ�ǿ�Ȳ���

  {$IFDEF DEBUG}
  nStr := '����:[ ' + nData.Fjud + '] ' +
          '�Ƹ�:[ ' + nData.Fjh + '] ' +
          'ǿ��:[ ' + nData.Fyi + ']';
  WriteLog(nStr);
  {$ENDIF}
end;

end.
