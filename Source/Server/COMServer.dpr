program COMServer;

uses
  FastMM4,
  Windows,
  Forms,
  UFormMain in 'UFormMain.pas' {fFormMain},
  USyncTrucks in 'USyncTrucks.pas';

{$R *.res}

var
  gMutexHwnd: Hwnd;
  //互斥句柄

begin
  gMutexHwnd := CreateMutex(nil, True, 'RunSoft_COMServer');
  //创建互斥量
  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    //ReleaseMutex(gMutexHwnd);
    //CloseHandle(gMutexHwnd); Exit;
  end; //已有一个实例
  
  Application.Initialize;
  Application.Title := '数据服务';
  Application.CreateForm(TfFormMain, fFormMain);
  Application.Run;

  ReleaseMutex(gMutexHwnd);
  CloseHandle(gMutexHwnd);
end.
