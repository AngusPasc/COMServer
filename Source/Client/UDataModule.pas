{*******************************************************************************
  ����: dmzn@163.com 2009-5-20
  ����: ���ݿ����ӡ�������� 
*******************************************************************************}
unit UDataModule;

{$I Link.Inc}
interface

uses
  Windows, Graphics, SysUtils, Classes, DB, MemDS, DBAccess, Uni,
  cxLookAndFeels, XPMan, dxLayoutLookAndFeels, cxEdit, UniProvider,
  MySQLUniProvider;

type
  TFDM = class(TDataModule)
    edtStyle: TcxDefaultEditStyleController;
    dxLayout1: TdxLayoutLookAndFeelList;
    XPM1: TXPManifest;
    dxLayoutWeb1: TdxLayoutWebLookAndFeel;
    cxLoF1: TcxLookAndFeelController;
    DBConn1: TUniConnection;
    SQLQuery: TUniQuery;
    Command: TUniQuery;
    SqlTemp: TUniQuery;
    MySQL1: TMySQLUniProvider;
  private
    { Private declarations }
  public
    { Public declarations }
    function QuerySQL(const nSQL: string): TDataSet;
    function QueryTemp(const nSQL: string): TDataSet;
    procedure QueryData(const nQuery: TUniQuery; const nSQL: string);
    function ExecuteSQL(const nSQL: string): integer;
    //��д����
  end;

var
  FDM: TFDM;

implementation

{$R *.dfm}

uses
  USysLoger;

procedure WriteLog(const nEvent: string);
begin
  gSysLoger.AddLog(TFDM, '����ģ��', nEvent);
end;

//Desc: ִ��nSQLд����
function TFDM.ExecuteSQL(const nSQL: string): integer;
var nStep: Integer;
    nException: string;
begin
  Result := -1;
  nException := '';
  nStep := 0;
  
  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      SqlTemp.Close;
      SqlTemp.Connection := Command.Connection;
      SqlTemp.SQL.Text := 'select 1';
      SqlTemp.Open;

      SqlTemp.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      Command.Connection.Close;
      Command.Connection.Open;
    end; //reconnnect

    Command.Close;
    Command.SQL.Text := nSQL;
    Command.Execute;

    Result := Command.FetchRows;
    nException := '';
    Break;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
      WriteLog(nException);
    end;
  end;

  if nException <> '' then
    raise Exception.Create(nException);
  //xxxxx
end;

//Desc: �����ѯ
function TFDM.QuerySQL(const nSQL: string): TDataSet;
var nStep: Integer;
    nException: string;
begin
  Result := nil;
  nException := '';
  nStep := 0;

  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      SQLQuery.Close;
      SQLQuery.SQL.Text := 'select 1';
      SQLQuery.Open;

      SQLQuery.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      SQLQuery.Connection.Close;
      SQLQuery.Connection.Open;
    end; //reconnnect

    SQLQuery.Close;
    SQLQuery.SQL.Text := nSQL;
    SQLQuery.Open;

    Result := SQLQuery;
    nException := '';
    Break;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
      WriteLog(nException);
    end;
  end;

  if nException <> '' then
    raise Exception.Create(nException);
  //xxxxx
end;

//Desc: ��ʱ��ѯ
function TFDM.QueryTemp(const nSQL: string): TDataSet;
var nStep: Integer;
    nException: string;
begin
  Result := nil;
  nException := '';
  nStep := 0;

  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      SQLTemp.Close;
      SQLTemp.SQL.Text := 'select 1';
      SQLTemp.Open;

      SQLTemp.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      SQLTemp.Connection.Close;
      SQLTemp.Connection.Open;
    end; //reconnnect

    SQLTemp.Close;
    SQLTemp.SQL.Text := nSQL;
    SQLTemp.Open;

    Result := SQLTemp;
    nException := '';
    Break;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
      WriteLog(nException);
    end;
  end;

  if nException <> '' then
    raise Exception.Create(nException);
  //xxxxx
end;

//Desc: ��nQueryִ��nSQL���
procedure TFDM.QueryData(const nQuery: TUniQuery; const nSQL: string);
var nStep: Integer;
    nException: string;
    nBookMark: Pointer;
begin
  nException := '';
  nStep := 0;

  while nStep <= 2 do
  try
    if nStep = 1 then
    begin
      SqlTemp.Close;
      SqlTemp.Connection := nQuery.Connection;
      SqlTemp.SQL.Text := 'select 1';
      SqlTemp.Open;

      SqlTemp.Close;
      Break;
      //connection is ok
    end else

    if nStep = 2 then
    begin
      nQuery.Connection.Close;
      nQuery.Connection.Open;
    end; //reconnnect

    nQuery.DisableControls;
    nBookMark := nQuery.GetBookmark;
    try
      nQuery.Close;
      nQuery.SQL.Text := nSQL;
      nQuery.Open;
                 
      nException := '';
      nStep := 3;
      //delay break loop

      if nQuery.BookmarkValid(nBookMark) then
        nQuery.GotoBookmark(nBookMark);
    finally
      nQuery.FreeBookmark(nBookMark);
      nQuery.EnableControls;
    end;
  except
    on E:Exception do
    begin
      Inc(nStep);
      nException := E.Message;
      WriteLog(nException);
    end;
  end;

  if nException <> '' then
    raise Exception.Create(nException);
  //xxxxx
end;

end.
