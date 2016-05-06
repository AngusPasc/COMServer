{*******************************************************************************
  ����: dmzn@163.com 2016-05-05
  ����: ����ת���������
*******************************************************************************}
unit UFormMain;

{$I Link.inc}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  CPortTypes, UTrayIcon, CPort, ExtCtrls, IdBaseComponent, IdComponent,
  IdCustomTCPServer, IdTCPServer, ComCtrls, StdCtrls, IdContext;

type
  TCOMItem = record
    FItemName: string;            //�ڵ���
    FItemGroup: string;           //�ڵ����,ÿ����"��-��"��һ
    FPortName: string;            //�˿�����
    FBaudRate: TBaudRate;         //������
    FDataBits: TDataBits;         //����λ
    FStopBits: TStopBits;         //��ͣλ

    FCOMObject: TComPort;         //���ڶ���
    FBuffer: string;              //���ݻ���
    FMemo: string;                //������Ϣ
  end;

  TfFormMain = class(TForm)
    GroupBox1: TGroupBox;
    MemoLog: TMemo;
    StatusBar1: TStatusBar;
    CheckSrv: TCheckBox;
    EditPort: TLabeledEdit;
    IdTCPServer1: TIdTCPServer;
    CheckAuto: TCheckBox;
    CheckLoged: TCheckBox;
    Timer1: TTimer;
    ComPort1: TComPort;
    BtnRefresh: TButton;
    CheckAdjust: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure CheckSrvClick(Sender: TObject);
    procedure CheckLogedClick(Sender: TObject);
    procedure IdTCPServer1Execute(AContext: TIdContext);
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
    procedure OnCOMData(Sender: TObject; Count: Integer);
    //���ݴ���
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}
uses
  IniFiles, Registry, ULibFun, USysLoger;

var
  gPath: string;               //����·��

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
  gPath := ExtractFilePath(Application.ExeName);
  InitGlobalVariant(gPath, gPath+sConfig, gPath+sConfig);

  gSysLoger := TSysLoger.Create(gPath + 'Logs\');
  gSysLoger.LogEvent := ShowLog;

  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.Hint := Application.Title;
  FTrayIcon.Visible := True;

  nIni := nil;
  nReg := nil;
  try
    nIni := TIniFile.Create(gPath + 'Config.ini');
    EditPort.Text := nIni.ReadString('Config', 'Port', '8000');
    Timer1.Enabled := nIni.ReadBool('Config', 'Enabled', False);
    
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

  {$IFDEF DEBUG}
  CheckLoged.Checked := True;
  CheckAdjust.Checked := True;
  {$ENDIF}
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
end;

procedure TfFormMain.CheckSrvClick(Sender: TObject);
var nIdx: Integer;
begin
  if not IdTCPServer1.Active then
    IdTCPServer1.DefaultPort := StrToInt(EditPort.Text);
  IdTCPServer1.Active := CheckSrv.Checked;
  EditPort.Enabled := not CheckSrv.Checked;

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
        FMemo := E.Message;
        WriteLog(E.Message);
      end;
    end;
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
    Add('|-- ����: ' + FItemName);
    Add('|-- ����: ' + FItemGroup);
    Add('|-- �˿�: ' + FPortName);
    Add('|-- ����: ' + BaudRateToStr(FBaudRate));
    Add('|-- ��λ: ' + DataBitsToStr(FDataBits));
    Add('|-- ͣλ: ' + StopBitsToStr(FStopBits));
    Add('|-- ��ע: ' + FMemo);
    Add('');
  end;
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

//Date: 2016-05-05
//Parm: ����;���ݴ�С
//Desc: ����������
procedure TfFormMain.OnCOMData(Sender: TObject; Count: Integer);
var nStr: string;
    nIdx,nInt: Integer;
    nItem,nGroup: Integer;
begin
  nItem := FindCOMItem(Sender);
  if (nItem < 0) or (FCOMPorts[nItem].FCOMObject = nil) then
  begin
    WriteLog('�յ�����,���޷�ƥ�䴮�ڶ���.');
    Exit;
  end;

  nGroup := FindSameGroup(nItem);
  if (nGroup < 0) or (FCOMPorts[nGroup].FCOMObject = nil) then
  begin
    nStr := '�յ�����,���޷�ƥ�䴮��[ %s ]ͬ�����.';
    WriteLog(Format(nStr, [FCOMPorts[nItem].FItemName]));
    Exit;
  end;

  with FCOMPorts[nItem] do
  begin
    FCOMObject.ReadStr(FBuffer, Count);
    nStr := '';
    nInt := Length(FBuffer);

    for nIdx:=1 to nInt do
      nStr := nStr + IntToHex(Ord(FBuffer[nIdx]), 1) + ' ';
    //ʮ������

    nStr := Format('����:[ %s ] ����:[ %s ]', [FItemName, nStr]);
    WriteLog(nStr);
  end; //��ȡ����

  if CheckAdjust.Checked then
  begin
    FCOMPorts[nGroup].FCOMObject.WriteStr(FCOMPorts[nItem].FBuffer);
    nStr := '����:[ %s ] ����:[ ת���� %s ]';
    nStr := Format(nStr, [FCOMPorts[nItem].FItemName, FCOMPorts[nGroup].FItemName]);

    WriteLog(nStr);
    Exit;
  end; //ֱ��ת��
end;

end.
