{*******************************************************************************
  ����: dmzn@163.com 2016-10-14
  ����: ����Ԫ
*******************************************************************************}
unit UFormMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, DB, DBAccess, Uni, USysDB;

type
  TfFormMain = class(TForm)
    DBConn1: TUniConnection;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fFormMain: TfFormMain;

implementation

{$R *.dfm}

end.
