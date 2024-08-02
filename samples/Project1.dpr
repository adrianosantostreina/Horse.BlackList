program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Horse,
  Horse.Jhonson,
  Horse.Blacklist,

  Data.Db,
  FireDAC.Comp.Client,

  System.IOUtils,
  System.SysUtils,
  System.Json,
  System.Generics.Collections;

const
  LAttempts = 5;

var
  LBlackList: THorseBlackListMiddleware;
  LFolderLog: string;
  LFileLog: string;
  LIPList: TList<string>;
  JSONString: string;
  JSONArray: TJSONArray;

  LDataSet: TFDMemTable;
begin
  LFolderLog := TPath.Combine(ExtractFilePath(ParamStr(0)), 'log');
  LFileLog := TPath.Combine(LFolderLog, 'blacklist.log');

{$REGION 'Exemplo com string Fixa'}
(*
  LBlackList := THorseBlackListMiddleware.New
    .SetLogFile('blacklist.log')
    .SetMaxAttempts(LAttempts)
    .SetAllowedIP
      .Add('127.0.0.1')
      .Add('192.168.0.101')
    .&End;
*)
{$ENDREGION}

{$REGION 'Exemplo com DataSet'}
(*
  try
    LDataSet := TFDMemTable.Create(nil);
    LDataSet.FieldDefs.Add('IP', ftString, 30);
    LDataSet.CreateDataSet;
    LDataSet.Active := True;
    for var I : Integer := 1 to 4 do
    begin
      LDataSet.Append;
      LDataSet.FieldByName('IP').AsString := Format('100.100.100.%3.3d', [I]);
      LDataSet.Post;
    end;

    LBlackList := THorseBlackListMiddleware.New
      .SetLogFile('blacklist.log')
      .SetMaxAttempts(LAttempts)
      .SetAllowedIP(LDataSet, 'IP');
  finally
    LDataSet.Free;
  end;
*)
{$ENDREGION}

{$REGION 'Exemplo com Objeto'}
(*
  LIPList := TList<string>.Create;
  try
    LIPList.Add('100.100.100.001');
    LIPList.Add('100.100.100.002');

    // Configura o middleware
    LBlackList := THorseBlackListMiddleware.New
      .SetLogFile('blacklist.log')
      .SetMaxAttempts(LAttempts)
      .SetAllowedIP(LIPList);
  finally
    LIPList.Free;
  end;
*)
{$ENDREGION}

{$REGION 'Exemplo com JSON String'}
(*
  JSONString := '["127.0.0.1", "192.168.0.100"]';
  LBlackList := THorseBlackListMiddleware.New
    .SetLogFile('blacklist.log')
    .SetMaxAttempts(LAttempts)
    .SetAllowedIP(JSONString);
*)
{$ENDREGION}

{$REGION 'Exemplo com JSON Array'}
(*
  JSONArray := TJSONArray.Create;
  try
    JSONArray.Add('192.168.0.1');
    JSONArray.Add('192.168.0.2');
    JSONArray.Add('10.0.0.1');

    // Configura o middleware Blacklist
    LBlackList := THorseBlackListMiddleware.New
      .SetLogFile('blacklist.log')   // Define o arquivo de log
      .SetMaxAttempts(LAttempts)              // Define o número máximo de tentativas antes do bloqueio
      .SetAllowedIP(JSONArray);       // Adiciona os IPs permitidos a partir do JSONArray
  finally
    JSONArray.Free;
  end;
*)
{$ENDREGION}

{$REGION 'Exemplo com SkipIPS'}
  LBlackList := THorseBlackListMiddleware.New
    .SetLogFile('blacklist.log')
    .SetMaxAttempts(LAttempts)
    .EnableConsoleLog(True)
    .SkipIPS(['192.168.0.1', '192.168.0.2']);
{$ENDREGION}

  //Registra o middleware
  THorse
    .Use(LBlackList.HorseCallback);

  THorse
    .Get('ping',
      procedure (Req: THorseRequest; Res: THorseResponse; Next: TProc)
      begin
        Res.Send('pong')
      end
    );

  THorse
    .Listen(9000);
end.

