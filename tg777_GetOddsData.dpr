program tg777_GetOddsData;

uses
  Vcl.Forms,
  ceflib,
  Unit1 in 'Unit1.pas' {Form1};

{$R *.res}

begin
  CefCache := 'cache';
  CefSingleProcess := False;
  if not CefLoadLibDefault then
    Exit;

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
