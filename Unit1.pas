unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, cefvcl, ceflib, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.Buttons, Vcl.Samples.Spin, System.DateUtils, Data.DB, MemDS,
  DBAccess, MyAccess, DALoader, MyLoader;

type
  TReturn = record
    Return_Result:boolean;
    Return_Message:WideString;
  end;

type
  TGame = record
    GameID:string;
    GameYear:string;
    GameDateTime:string;
    GameName:WideString;
    LeagueName:WideString;
    HomeTeam:string;
    VisitTeam:string;
    OddsURL:WideString;
  end;

type
  TOdds = record
    GameID:string;
    OddsType:string;
    OddsOption:string;
    PR:string;
    Stock:string;
    Quota:string;
  end;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    Panel2: TPanel;
    Panel3: TPanel;
    mmo_message: TMemo;
    lbledt_url: TLabeledEdit;
    chrm1: TChromium;
    btn_run: TBitBtn;
    grp1: TGroupBox;
    lbledt_user: TLabeledEdit;
    lbledt_pwd: TLabeledEdit;
    grp2: TGroupBox;
    chk_autoupdate: TCheckBox;
    se_update_interval: TSpinEdit;
    lbl1: TLabel;
    grp3: TGroupBox;
    chk_allupdate: TCheckBox;
    se_update_begin: TSpinEdit;
    lbl2: TLabel;
    lbl3: TLabel;
    se_update_end: TSpinEdit;
    grp4: TGroupBox;
    lbl4: TLabel;
    cbb_line: TComboBox;
    tmr_autorun: TTimer;
    lbl_countdown: TLabel;
    myconn1: TMyConnection;
    ml_games: TMyLoader;
    ml_odds: TMyLoader;
    qry_temp: TMyQuery;
    procedure btn_runClick(Sender: TObject);
    procedure chrm1AddressChange(Sender: TObject; const browser: ICefBrowser;
      const frame: ICefFrame; const url: ustring);
    procedure FormCreate(Sender: TObject);
    procedure chrm1LoadEnd(Sender: TObject; const browser: ICefBrowser;
      const frame: ICefFrame; httpStatusCode: Integer);
    procedure cbb_lineChange(Sender: TObject);
    procedure chk_allupdateClick(Sender: TObject);
    procedure tmr_autorunTimer(Sender: TObject);
    procedure ml_gamesPutData(Sender: TDALoader);
    procedure ml_oddsPutData(Sender: TDALoader);
  private
    { Private declarations }
    function checkLoginData:TReturn;
    function checkBeginEnd:TReturn;
    procedure writeMessage(Content:WideString);
    procedure doLogin(account:string; pwd:string);
    procedure getGameList(const str:ustring);
    procedure getOddsList(const str:ustring);
    procedure getIsNeedLogin(const str:ustring);
  public
    { Public declarations }
    procedure setGameData(innerText:string; var game:TGame);
    procedure setOddsOption(OddsType:string);
    function getOddsURL(innerHTML:WideString):string;
    function getPRData(innerText:WideString):string;
    function getStockData(innerText:WideString):string;
    function getDefaultQuota(OddsType:string; OddsOption:string):Integer;
    function ConvertToFloat(str:string):Real;
  end;

var
  Form1: TForm1;
  GameList:TList<TGame>;
  OddsList:TList<TOdds>;
  CS_OddsOption:TDictionary<string, Integer>;
  CSFF_OddsOption:TDictionary<string, Integer>;
  TS_OddsOption:TDictionary<string, Integer>;
  FGT_OddsOption:TDictionary<string, Integer>;
  TG777_USER: string;
  TG777_PWD: string;
  TG777_URL: string;
  IsNeedLogin: Boolean;
  GameStartIndex,GameEndIndex:integer;

implementation

{$R *.dfm}

uses
  MSHTML, ActiveX, ComObj;


procedure TForm1.cbb_lineChange(Sender: TObject);
begin
  //依据不同线路，载入相对的页面
  case cbb_line.ItemIndex of
    0:TG777_URL:= 'http://w3.tg777.net/';
    1: TG777_URL:= 'http://w2.tg777.net/';
    2: TG777_URL:= 'http://w1.tg777.net/';
    else TG777_URL:= 'http://w1.tg777.net/';
  end;
  chrm1.Load(TG777_URL);
end;

function TForm1.checkLoginData:TReturn;
var
  myreturn:TReturn;
begin
  //检查帐号是否为空
  if Trim(lbledt_user.Text) = '' then
  begin
    myreturn.Return_Result:=False;
    myreturn.Return_Message:='帐号不得为空白 !';
    Result:=myreturn;
  end
  //检查密码是否为空
  else if Trim(lbledt_pwd.Text) = '' then
  begin
    myreturn.Return_Result:=False;
    myreturn.Return_Message:='密码不得为空白 !';
    Result:=myreturn;
  end
  //帐号、密码都有填写
  else
  begin
    myreturn.Return_Result:=True;
    myreturn.Return_Message:='';
    Result:=myreturn;
  end;
end;

function TForm1.checkBeginEnd:TReturn;
var
  myreturn:TReturn;
begin
  if (se_update_begin.Value > se_update_end.Value) then
  begin
    myreturn.Return_Result:=False;
    myreturn.Return_Message:='起始笔数不得大於结束笔数 !';
  end
  else if (se_update_end.Value < se_update_begin.Value) then
  begin
    myreturn.Return_Result:=False;
    myreturn.Return_Message:='结束笔数不得小於起始笔数 !';
  end
  else
  begin
    myreturn.Return_Result:=True;
    myreturn.Return_Message:='';
  end;

  Result:=myreturn;
end;

procedure TForm1.chk_allupdateClick(Sender: TObject);
begin
  if chk_allupdate.Checked then
  begin
    se_update_begin.Enabled:=False;
    se_update_end.Enabled:=False;
  end
  else
  begin
    se_update_begin.Enabled:=True;
    se_update_end.Enabled:=True;
  end;
end;

procedure TForm1.writeMessage(Content:WideString);
begin
  mmo_message.Lines.Add('['+formatdatetime('yyyy-mm-dd hh:nn:ss.zzz',Now)+'] '+Trim(Content));
end;

procedure TForm1.btn_runClick(Sender: TObject);
begin
  if (checkBeginEnd.Return_Result = True) then
  begin
    //第一次执行，先迈行登入动作
    if IsNeedLogin = True then
    begin
      if checkLoginData.Return_Result = True then
      begin
        doLogin(lbledt_user.Text, lbledt_pwd.Text);
      end;
    end
    //非第一次执行，载入赛事页面
    else
    begin
      chrm1.Load(TG777_URL+'list.php');
    end;
  end
  else
  begin
    MessageDlg(checkBeginEnd.Return_Message, mtError, [mbok], 0);
  end;
end;

procedure TForm1.chrm1AddressChange(Sender: TObject; const browser: ICefBrowser;
  const frame: ICefFrame; const url: ustring);
begin
  lbledt_url.Text:=url;
end;

procedure TForm1.chrm1LoadEnd(Sender: TObject; const browser: ICefBrowser;
  const frame: ICefFrame; httpStatusCode: Integer);
begin
  //mmo_message.Lines.Add(frame.Url);
  //首頁
  if (Trim(frame.Url) = TG777_URL) then
  begin
    btn_run.Enabled:=True;
    browser.MainFrame.GetSourceProc(getIsNeedLogin);
  end;
  //赛事列表
  if (StringReplace(frame.Url, TG777_URL, '', [rfReplaceAll, rfIgnoreCase]) = 'controler/listmenu.php') then
  begin
    btn_run.Enabled:=False;
    browser.GetFrame('leftmenu').GetSourceProc(getGameList);
  end;
  //盘口列表
  if Pos('newopen.php', frame.Url) > 0 then
  begin
    btn_run.Enabled:=False;
    browser.MainFrame.GetSourceProc(getOddsList);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  GameList:=TList<TGame>.Create;
  OddsList:=TList<TOdds>.Create;
  GameStartIndex:=0;
  TG777_URL:='http://w1.tg777.net/';
  CS_OddsOption:=TDictionary<string, Integer>.Create;
  CSFF_OddsOption:=TDictionary<string, Integer>.Create;
  TS_OddsOption:=TDictionary<string, Integer>.Create;
  FGT_OddsOption:=TDictionary<string, Integer>.Create;
  setOddsOption('CS');
  setOddsOption('CSFF');
  setOddsOption('TS');
  setOddsOption('FGT');
end;

procedure TForm1.doLogin(account:string; pwd:string);
var
  js:string;
begin
  js:='document.getElementById("account").value = "'+Trim(account)+'"; '+
      'document.getElementById("pwd").value = "'+Trim(pwd)+'"; '+
      'document.getElementsByClassName("btn_login")[0].onclick();';
  chrm1.Browser.MainFrame.ExecuteJavaScript(js, lbledt_url.Text, 0);
end;

procedure TForm1.getGameList(const str:ustring);
var
  Document:IHTMLDocument2;
  Body:IHTMLElement2;
  Tags:IHTMLElementCollection;
  Tag:IHTMLElement;
  i:integer;
  v:Variant;
  Game:TGame;
begin
  Document:=CreateComObject(Class_HTMLDOcument) as IHTMLDocument2;
  GameList.Clear;
  //取得所有赛事资料
  try
    Document.designMode:='on';
    while Document.readyState <> 'complete' do Application.ProcessMessages;
    v:=VarArrayCreate([0, 0], varVariant);
    v[0]:=str;
    Document.write(PSafeArray(TVarData(v).VArray));
    Document.designMode:='off';
    while Document.readyState <> 'complete' do Application.ProcessMessages;
    Body:=Document.body as IHTMLElement2;
    Tags:=Body.getElementsByTagName('li');
    for i:=0 to Pred(Tags.length) do
    begin
      Tag := Tags.item(i, EmptyParam) as IHTMLElement;
      if AnsiSameText(Copy(Tag._className,1,3), 'two') then
      begin
        if (Tag.parentElement.parentElement._className = 'has-sub open') then
        begin
          Game.GameID:=Trim(StringReplace(Tag._className, 'two', '', [rfReplaceAll, rfIgnoreCase]));
          Game.GameYear:=IntToStr(YearOf(Date()));
          Game.OddsURL:=getOddsURL(Tag.innerHTML);
          setGameData(Tag.innerText, Game);
          GameList.Add(Game);
        end;
      end;
    end;
  finally
    Document:=nil;
  end;

  //全部更新
  if chk_allupdate.Checked then
  begin
    GameStartIndex:=0;
    GameEndIndex:=GameList.Count - 1;
    chrm1.Load(GameList[GameStartIndex].OddsURL);
  end
  //部份更新
  else
  begin
    //起始數筆小於全部筆數
    if (se_update_begin.Value - 1 <= GameList.Count) then
    begin
      GameStartIndex:=se_update_begin.Value - 1;
      //結束筆數大於全部筆數
      if (se_update_end.Value - 1 > GameList.Count) then
      begin
        GameEndIndex:=GameList.Count - 1;
      end
      //結束筆數小於等於全部筆數
      else
      begin
        GameEndIndex:=se_update_end.Value - 1;
      end;
      chrm1.Load(GameList[GameStartIndex].OddsURL);
    end
    else
    begin
      writeMessage('更新范围起始笔数超过全部笔数('+IntToStr(GameList.Count)+') !!');
      btn_run.Enabled:=True;
    end;
  end;
end;

procedure TForm1.getOddsList(const str:ustring);
var
  Document:IHTMLDocument2;
  Body:IHTMLElement2;
  Tags:IHTMLElementCollection;
  Tag:IHTMLElement;
  i:integer;
  v:Variant;
  Odds:TOdds;
begin
  //仍在范围内，更新赛事盘口
  if GameStartIndex <= GameEndIndex then
  begin
    //将赛事资料写到资料库
    ml_games.Load;
    //取得盘口资料
    Document:=CreateComObject(Class_HTMLDOcument) as IHTMLDocument2;
    OddsList.Clear;
    try
      Document.designMode:='on';
      while Document.readyState <> 'complete' do Application.ProcessMessages;
      v:=VarArrayCreate([0, 0], varVariant);
      v[0]:=str;
      Document.write(PSafeArray(TVarData(v).VArray));
      Document.designMode:='off';
      while Document.readyState <> 'complete' do Application.ProcessMessages;
      Body:=Document.body as IHTMLElement2;
      Tags:=Body.getElementsByTagName('td');
      i:=0;
      while i < Tags.length - 1 do
      begin
        try
          Odds.GameID:=GameList[GameStartIndex].GameID;
          Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
          //波胆
          if (AnsiSameText(Copy(Tag.id,1,7), 'arthur1')) and (Length(Tag.id) >= 8) and (Tag._className = 'openallcenter') and (Trim(Tag.innerText) <> '') then
          begin
            Odds.OddsType:='CS';
            //选项
            Odds.OddsOption:=Trim(Tag.innerText);
            //获利
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.PR:=getPRData(Tag.innerText);
            //可交易量
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.Stock:=getStockData(Tag.innerText);
            Odds.Quota:=IntToStr(getDefaultQuota(Odds.OddsType, Odds.OddsOption));
            OddsList.Add(Odds);
          end
          //上半场波胆
          else if (AnsiSameText(Copy(Tag.id,1,7), 'arthur2')) and (Length(Tag.id) >= 8) and (Trim(Tag.innerText) <> '') then
          begin
            Odds.OddsType:='CSFF';
            //选项
            Odds.OddsOption:=Trim(Tag.innerText);
            //获利
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.PR:=getPRData(Tag.innerText);
            //可交易量
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.Stock:=getStockData(Tag.innerText);
            Odds.Quota:=IntToStr(getDefaultQuota(Odds.OddsType, Odds.OddsOption));
            OddsList.Add(Odds);
          end
          //总得分
          else if (AnsiSameText(Copy(Tag.id,1,7), 'arthur3')) and (Length(Tag.id) >= 8) and (Trim(Tag.innerText) <> '') then
          begin
            Odds.OddsType:='TS';
            //选项
            Odds.OddsOption:=Trim(Tag.innerText);
            //获利
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.PR:=getPRData(Tag.innerText);
            //可交易量
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.Stock:=getStockData(Tag.innerText);
            Odds.Quota:=IntToStr(getDefaultQuota(Odds.OddsType, Odds.OddsOption));
            OddsList.Add(Odds);
          end
          //首入球时间
          else if AnsiSameText(Copy(Tag.id,1,6), 'arthur') and (Length(Tag.id) = 7) and (Trim(Tag.innerText) <> '') then
          begin
            Odds.OddsType:='FGT';
            //选项
            Odds.OddsOption:=Trim(Tag.innerText);
            //获利
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.PR:=getPRData(Tag.innerText);
            //可交易量
            Inc(i);
            Tag:=Tags.item(i, EmptyParam) as IHTMLElement;
            Odds.Stock:=getStockData(Tag.innerText);
            Odds.Quota:=IntToStr(getDefaultQuota(Odds.OddsType, Odds.OddsOption));
            OddsList.Add(Odds);
          end;
        finally
          Inc(i);
        end;
      end;
    finally
      //将盘口资料写到资料库
      ml_odds.Load;
      Document:=nil;
      Inc(GameStartIndex);
      //下一笔仍存范围内，载入下场赛事盘口资料页面
      if GameStartIndex <= GameEndIndex then
      begin
        chrm1.Load(GameList[GameStartIndex].OddsURL);
      end
      //已执行完所有范围内的赛事，回到首页
      else
      begin
        chrm1.Load(TG777_URL);
      end;
    end;
  end
end;

procedure TForm1.getIsNeedLogin(const str:ustring);
var
  Document:IHTMLDocument2;
  Body:IHTMLElement2;
  Tags:IHTMLElementCollection;
  Tag:IHTMLElement;
  i:integer;
  v:Variant;
begin
  Document:=CreateComObject(Class_HTMLDOcument) as IHTMLDocument2;
  GameList.Clear;
  //检查登入按钮是否存在
  try
    Document.designMode:='on';
    while Document.readyState <> 'complete' do Application.ProcessMessages;
    v:=VarArrayCreate([0, 0], varVariant);
    v[0]:=str;
    Document.write(PSafeArray(TVarData(v).VArray));
    Document.designMode:='off';
    while Document.readyState <> 'complete' do Application.ProcessMessages;
    Body:=Document.body as IHTMLElement2;
    Tags:=Body.getElementsByTagName('button');
    IsNeedLogin:=False;
    for i:=0 to Pred(Tags.length) do
    begin
      Tag := Tags.item(i, EmptyParam) as IHTMLElement;
      if AnsiSameText(Trim(Tag.innerText), '登入') then
      begin
        IsNeedLogin:=True;
      end;
    end;
  finally
    Document:=nil;
  end;
end;

procedure TForm1.setGameData(innerText:string; var game:TGame);
var
  sl,sl2:TStringList;
begin
  sl:=TStringList.Create;
  sl2:=TStringList.Create;
  try
    sl.StrictDelimiter:=True;
    sl.Delimiter:=#13;
    sl.DelimitedText:=innerText;
    if sl.Count = 2 then
    begin
      //第一行
      sl2.StrictDelimiter:=True;
      sl2.Delimiter:=' ';
      sl2.DelimitedText:=Trim(sl[0]);
      game.GameDateTime:=Trim(sl2[0])+' '+Trim(sl2[1]);
      game.LeagueName:=Trim(sl2[3]);
      //第二行
      sl2.StrictDelimiter:=True;
      sl2.Delimiter:=' ';
      sl2.DelimitedText:=Trim(sl[1]);
      game.GameName:=Trim(sl[1]);
      game.HomeTeam:=Trim(sl2[0]);
      game.VisitTeam:=Trim(sl2[2]);
    end;
  finally
    sl.Destroy;
    sl2.Destroy;
  end;
end;

procedure TForm1.tmr_autorunTimer(Sender: TObject);
var
  myTime:TDateTime;
begin
  //倒数时间未到
  if lbl_countdown.Caption <> '00:00:00' then
  begin
    myTime:=StrToTime(lbl_countdown.Caption);
    myTime:=IncSecond(myTime, -1);
  end
  //倒数时间已到
  else
  begin
    btn_run.Click;
    myTime:=StrToTime(lbl_countdown.Caption);
    myTime:=IncSecond(myTime, se_update_interval.Value);
  end;
  lbl_countdown.Caption:=FormatDateTime('hh:nn:ss',myTime);
  lbl_countdown.Refresh;
end;

function TForm1.getOddsURL(innerHTML:WideString):string;
var
  tempstring:WideString;
  a2,a1,a,c,d,f,h:WideString;
  sl:TStringList;
begin
  try
    sl:=TStringList.Create;
    tempstring:=Copy(innerHTML, Pos('(' , innerHTML) + 1, Pos(')', innerHTML) - Pos('(', innerHTML) - 1);
    sl.StrictDelimiter:=True;
    sl.Delimiter:=',';
    sl.DelimitedText:=tempstring;
    a2:='mid='+sl[0];
    a1:='name='+sl[1];
    a:='gameid='+sl[2];
    c:=sl[3];
    d:='gc12='+sl[4];
    f:='gamename='+sl[5];
    h:='time='+sl[6];
    tempstring:=TG777_URL+'controler/newopen.php?'+a2+'&'+a1+'&'+a+'&'+d+'&'+f+'&'+h;
  finally
    sl.Destroy;
  end;

  Result:=tempstring;
end;

function TForm1.getPRData(innerText:WideString):string;
begin
  if Trim(innerText) <> '' then
  begin
    Result:=StringReplace(Trim(innerText), '%', '', [rfReplaceAll, rfIgnoreCase]);
  end
  else
  begin
    Result:='';
  end;
end;

function TForm1.getStockData(innerText:WideString):string;
begin
  if Trim(innerText) <> '' then
  begin
    Result:=StringReplace(Trim(innerText), '￥', '', [rfReplaceAll, rfIgnoreCase]);
  end
  else
  begin
    Result:='';
  end;
end;


procedure TForm1.ml_gamesPutData(Sender: TDALoader);
var
  sql:string;
begin
  writeMessage('==============================================================================================');
  writeMessage('赛事('+IntToStr(GameStartIndex+1)+'/'+IntToStr(GameList.Count)+') '+GameList[GameStartIndex].GameYear+' '+GameList[GameStartIndex].GameDateTime+' '+GameList[GameStartIndex].LeagueName+' '+GameList[GameStartIndex].GameName+'('+GameList[GameStartIndex].GameID+')');
  writeMessage('==============================================================================================');
  sql:='SELECT 1 FROM Games WHERE GameID  = "'+GameList[GameStartIndex].GameID+'" ';
  qry_temp.Active:=False;
  qry_temp.SQL.Clear;
  qry_temp.SQL.Add(sql);
  qry_temp.Active:=True;
  if qry_temp.RecordCount = 0 then
  begin
    ml_games.PutColumnData('GameID', 1, GameList[GameStartIndex].GameID);
    ml_games.PutColumnData('GameYear', 1, GameList[GameStartIndex].GameYear);
    ml_games.PutColumnData('GameDateTime', 1, GameList[GameStartIndex].GameDateTime);
    ml_games.PutColumnData('GameName', 1, GameList[GameStartIndex].GameName);
    ml_games.PutColumnData('LeagueName', 1, GameList[GameStartIndex].LeagueName);
    ml_games.PutColumnData('HomeTeam', 1, GameList[GameStartIndex].HomeTeam);
    ml_games.PutColumnData('VisitTeam', 1, GameList[GameStartIndex].VisitTeam);
    writeMessage('新增赛事资料成功 !');
  end
end;

procedure TForm1.ml_oddsPutData(Sender: TDALoader);
var
  sql:string;
  i:Integer;
  newPR:string;
begin
  for i:=0 to OddsList.Count -1 do
  begin
    sql:='SELECT PR,IsAutoUpdate FROM Odds WHERE GameID = "'+OddsList[i].GameID+'" AND OddsType = "'+OddsList[i].OddsType+'" AND OddsOption = "'+OddsList[i].OddsOption+'"';
    qry_temp.Active:=False;
    qry_temp.SQL.Clear;
    qry_temp.SQL.Add(sql);
    qry_temp.Active:=True;
    //不存在资料库，新增
    if (qry_temp.RecordCount = 0) then
    begin
      ml_odds.PutColumnData('GameID', i+1, OddsList[i].GameID);
      ml_odds.PutColumnData('OddsType', i+1, OddsList[i].OddsType);
      ml_odds.PutColumnData('OddsOption', i+1, OddsList[i].OddsOption);
      if OddsList[i].PR <> '' then
        ml_odds.PutColumnData('PR', i+1, OddsList[i].PR)
      else
        ml_odds.PutColumnData('PR', i+1, 'NULL');
      if OddsList[i].Quota <> '' then
        ml_odds.PutColumnData('Quota', i+1, OddsList[i].Quota)
      else
        ml_odds.PutColumnData('Quota', i+1, 'NULL');
      writeMessage(OddsList[i].OddsType+' '+OddsList[i].OddsOption+' '+OddsList[i].PR+' '+OddsList[i].Quota+' 新增盘口资料成功 !');
    end
    //有存在资料库、获利不同且设定为自动更新
    else if (qry_temp.RecordCount = 1)
      and (ConvertToFloat(qry_temp.FieldByName('PR').AsString) <> ConvertToFloat(OddsList[i].PR))
      and (qry_temp.FieldByName('IsAutoUpdate').AsInteger = 1)
    then
    begin
      newPR:=qry_temp.FieldByName('PR').AsString;
      if OddsList[i].PR = '' then
        sql:='UPDATE Odds SET PR = NULL, UpdateDate = "'+FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz',Now)+'" WHERE GameID = "'+OddsList[i].GameID+'" AND OddsType = "'+OddsList[i].OddsType+'" AND OddsOption = "'+OddsList[i].OddsOption+'"'
      else
        sql:='UPDATE Odds SET PR = '+OddsList[i].PR+', UpdateDate = "'+FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz',Now)+'" WHERE GameID = "'+OddsList[i].GameID+'" AND OddsType = "'+OddsList[i].OddsType+'" AND OddsOption = "'+OddsList[i].OddsOption+'"';
      qry_temp.Active:=False;
      qry_temp.SQL.Clear;
      qry_temp.SQL.Add(sql);
      qry_temp.Execute;
      writeMessage(OddsList[i].OddsType+' '+OddsList[i].OddsOption+' ('+newPR+' => '+OddsList[i].PR+') 更新盘口资料成功 !');
    end;
  end;
end;

procedure TForm1.setOddsOption(OddsType:string);
var
  sql:string;
begin
  OddsType:=UpperCase(Trim(OddsType));
  sql:='SELECT * FROM OddsOption WHERE OddsType = "'+OddsType+'"';
  qry_temp.Active:=False;
  qry_temp.SQL.Clear;
  qry_temp.SQL.Add(sql);
  qry_temp.Active:=True;
  while not qry_temp.Eof do
  begin
    if (OddsType = 'CS') then
      CS_OddsOption.Add(qry_temp.FieldByName('OddsOption').AsString, qry_temp.FieldByName('DefaultQuota').AsInteger)
    else if (OddsType = 'CSFF') then
      CSFF_OddsOption.Add(qry_temp.FieldByName('OddsOption').AsString, qry_temp.FieldByName('DefaultQuota').AsInteger)
    else if (OddsType = 'TS') then
      TS_OddsOption.Add(qry_temp.FieldByName('OddsOption').AsString, qry_temp.FieldByName('DefaultQuota').AsInteger)
    else if (OddsType = 'FGT') then
      FGT_OddsOption.Add(qry_temp.FieldByName('OddsOption').AsString, qry_temp.FieldByName('DefaultQuota').AsInteger);
    qry_temp.Next;
  end;
end;

function TForm1.getDefaultQuota(OddsType:string; OddsOption:string):Integer;
var
  DefaultQuota:Integer;
begin
  OddsType:=UpperCase(Trim(OddsType));
  OddsOption:=Trim(OddsOption);
  if OddsType = 'CS' then
  begin
    if (CS_OddsOption.TryGetValue(OddsOption, DefaultQuota) = True) then
      Result:=DefaultQuota
    else
      Result:=0;
  end
  else if OddsType = 'CSFF' then
  begin
    if (CSFF_OddsOption.TryGetValue(OddsOption, DefaultQuota) = True) then
      Result:=DefaultQuota
    else
      Result:=0;
  end
  else if OddsType = 'TS' then
  begin
    if (TS_OddsOption.TryGetValue(OddsOption, DefaultQuota) = True) then
      Result:=DefaultQuota
    else
      Result:=0;
  end
  else if OddsType = 'FGT' then
  begin
    if (FGT_OddsOption.TryGetValue(OddsOption, DefaultQuota) = True) then
      Result:=DefaultQuota
    else
      Result:=0;
  end
  else
  begin
    Result:=0;
  end;
end;

function TForm1.ConvertToFloat(str:string):Real;
begin
  if (str = '') or (str = Null) then
    Result:=0
  else
    Result:=StrToFloat(str);
end;

end.
