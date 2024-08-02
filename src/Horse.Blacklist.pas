unit Horse.Blacklist;

{$IFDEF FPC}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
    SysUtils, Classes, Generics.Collections, SyncObjs, fpjson, jsonparser, DB, Horse
  {$ELSE}
    System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs, System.IOUtils, Data.DB, System.JSON, Horse.Commons, Horse
  {$ENDIF}
  ;

const
  MAX_LOG_SIZE = 10240; // 10 KB

type
  THorseBlackListMiddleware = class;

  TAllowedIPManager = class
  private
    FMiddleware: THorseBlackListMiddleware;
  public
    constructor Create(AMiddleware: THorseBlackListMiddleware);
    function Add(const AIP: string): TAllowedIPManager;
    function &End: THorseBlackListMiddleware; // Retorna para a classe anterior
  end;

  THorseBlackListMiddleware = class
  private
    FMaxAttempts: Integer;
    FBlackList: TDictionary<string, Integer>;
    FAllowedIPs: TList<string>;
    FLock: TCriticalSection;
    FLogFile: string;
    FLogFileBaseName: string;
    FEnableConsoleLog: Boolean;
    procedure UpdateLogFile;
    function GetLogFileName: string;
  public
    constructor Create;
    destructor Destroy; override;
    function SetLogFile(const AFileName: string): THorseBlackListMiddleware;
    function SetMaxAttempts(Value: Integer): THorseBlackListMiddleware;
    function SetAllowedIP: TAllowedIPManager; overload; // Retorna o gerenciador de IPs permitidos
    function SetAllowedIP(DataSet: TDataSet; const IPFieldName: string): THorseBlackListMiddleware; overload; // Recebe um DataSet
    function SetAllowedIP(IPList: TList<string>): THorseBlackListMiddleware; overload; // Recebe um objeto com lista de IPs
    function SetAllowedIP(JSONArray: {$IFDEF FPC}TJSONArray{$ELSE}System.JSON.TJSONArray{$ENDIF}): THorseBlackListMiddleware; overload; // Recebe um TJSONArray com lista de IPs
    function SetAllowedIP(JSONString: string): THorseBlackListMiddleware; overload; // Recebe um JSON string com lista de IPs
    function SkipIPS(const IPs: array of string): THorseBlackListMiddleware; // Permite adicionar IPs a serem sempre permitidos
    function EnableConsoleLog(Value: Boolean): THorseBlackListMiddleware;
    procedure Register;
    function HorseCallback: THorseCallback;
    class function New: THorseBlackListMiddleware;
  end;

implementation

{ TAllowedIPManager }

constructor TAllowedIPManager.Create(AMiddleware: THorseBlackListMiddleware);
begin
  FMiddleware := AMiddleware;
end;

function TAllowedIPManager.Add(const AIP: string): TAllowedIPManager;
begin
  FMiddleware.FAllowedIPs.Add(AIP);
  Result := Self;
end;

function TAllowedIPManager.&End: THorseBlackListMiddleware;
begin
  Result := FMiddleware;
end;

{ THorseBlackListMiddleware }

constructor THorseBlackListMiddleware.Create;
begin
  FMaxAttempts := 0; // Valor padrão zero, permitindo todos os IPs sem bloqueio
  FBlackList := TDictionary<string, Integer>.Create;
  FAllowedIPs := TList<string>.Create;
  FLock := TCriticalSection.Create;
  FAllowedIPs.Add('127.0.0.1'); // Adiciona o IP local como sempre permitido
  FEnableConsoleLog := False; // Desativa o log no console por padrão
end;

destructor THorseBlackListMiddleware.Destroy;
begin
  FBlackList.Free;
  FAllowedIPs.Free;
  FLock.Free;
  inherited;
end;

function THorseBlackListMiddleware.SetLogFile(const AFileName: string): THorseBlackListMiddleware;
begin
  FLogFileBaseName := AFileName;
  UpdateLogFile;
  Result := Self;
end;

function THorseBlackListMiddleware.SetMaxAttempts(Value: Integer): THorseBlackListMiddleware;
begin
  FMaxAttempts := Value;
  Result := Self;
end;

function THorseBlackListMiddleware.SetAllowedIP: TAllowedIPManager;
begin
  Result := TAllowedIPManager.Create(Self);
end;

function THorseBlackListMiddleware.SetAllowedIP(DataSet: TDataSet; const IPFieldName: string): THorseBlackListMiddleware;
begin
  DataSet.First;
  while not DataSet.Eof do
  begin
    FAllowedIPs.Add(DataSet.FieldByName(IPFieldName).AsString);
    DataSet.Next;
  end;
  Result := Self;
end;

function THorseBlackListMiddleware.SetAllowedIP(IPList: TList<string>): THorseBlackListMiddleware;
var
  IP: string;
begin
  for IP in IPList do
  begin
    FAllowedIPs.Add(IP);
  end;
  Result := Self;
end;

function THorseBlackListMiddleware.SetAllowedIP(JSONArray: {$IFDEF FPC}TJSONArray{$ELSE}System.JSON.TJSONArray{$ENDIF}): THorseBlackListMiddleware;
var
  JSONValue: {$IFDEF FPC}TJSONData{$ELSE}System.JSON.TJSONValue{$ENDIF};
begin
  for JSONValue in JSONArray do
  begin
    {$IFDEF FPC}
    FAllowedIPs.Add(JSONValue.AsString);
    {$ELSE}
    FAllowedIPs.Add(JSONValue.Value);
    {$ENDIF}
  end;
  Result := Self;
end;

function THorseBlackListMiddleware.SetAllowedIP(JSONString: string): THorseBlackListMiddleware;
var
  JSONArray: {$IFDEF FPC}TJSONArray{$ELSE}System.JSON.TJSONArray{$ENDIF};
begin
  JSONArray := {$IFDEF FPC}GetJSON(JSONString) as TJSONArray{$ELSE}TJSONObject.ParseJSONValue(JSONString) as TJSONArray{$ENDIF};
  try
    Result := SetAllowedIP(JSONArray);
  finally
    JSONArray.Free;
  end;
end;

function THorseBlackListMiddleware.SkipIPS(const IPs: array of string): THorseBlackListMiddleware;
var
  IP: string;
begin
  for IP in IPs do
  begin
    FAllowedIPs.Add(IP);
  end;
  Result := Self;
end;

function THorseBlackListMiddleware.EnableConsoleLog(Value: Boolean): THorseBlackListMiddleware;
begin
  FEnableConsoleLog := Value;
  Result := Self;
end;

procedure THorseBlackListMiddleware.Register;
begin
  THorse.Use(HorseCallback);
end;

function THorseBlackListMiddleware.HorseCallback: THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      LIP, LEndpoint, LMethod: string;
      AttemptCount: Integer;
      LAccessTime: TDateTime;
    begin
      // Se o FMaxAttempts for zero, permite todas as requisições
      if FMaxAttempts = 0 then
      begin
        Next;
        Exit;
      end;

      Req.Headers.TryGetValue('X-Forwarded-For', LIP);
      if LIP.Equals(EmptyStr) then
        LIP := Req.RawWebRequest.RemoteAddr;

      LEndpoint := Req.RawWebRequest.PathInfo;
      LMethod := Req.RawWebRequest.Method;
      LAccessTime := Now;

      FLock.Enter;
      try
        if FAllowedIPs.Contains(LIP) then
        begin
          Next;
          Exit;
        end;

        if FBlackList.ContainsKey(LIP) then
          AttemptCount := FBlackList[LIP] + 1
        else
          AttemptCount := 1;

        FBlackList.AddOrSetValue(LIP, AttemptCount);

        if AttemptCount > FMaxAttempts then
        begin
          if FLogFile <> EmptyStr then
          begin
            UpdateLogFile;
            TFile.AppendAllText(FLogFile,
              Format('Blocked IP: %s [%s] %s %s'#13#10, [LIP, DateTimeToStr(LAccessTime), LEndpoint, LMethod]));
          end;

          // Log no console, se ativado
          if FEnableConsoleLog then
            WriteLn(Format('Blocked IP: %s [%s] %s %s', [LIP, DateTimeToStr(LAccessTime), LEndpoint, LMethod]));

          Res.Status(THTTPStatus.Forbidden).Send('Access Denied');
          raise EHorseCallbackInterrupted.Create;
        end;
      finally
        FLock.Leave;
      end;

      Next;
    end;
end;

procedure THorseBlackListMiddleware.UpdateLogFile;
var
  LogFileName: string;
  LogFileSize: Int64;
  Suffix: Integer;
begin
  Suffix := 0;
  repeat
    LogFileName := GetLogFileName;
    if Suffix > 0 then
      LogFileName := ChangeFileExt(LogFileName, Format('_%d.log', [Suffix]));
    Inc(Suffix);
    if FileExists(LogFileName) then
      LogFileSize := TFile.GetSize(LogFileName)
    else
      LogFileSize := 0;
  until (LogFileSize < MAX_LOG_SIZE) or (Suffix > 1000);

  FLogFile := LogFileName;
end;

function THorseBlackListMiddleware.GetLogFileName: string;
begin
  Result := Format('%s_%s.log', [ChangeFileExt(FLogFileBaseName, EmptyStr), FormatDateTime('YYYYMMDD', Now)]);
end;

class function THorseBlackListMiddleware.New: THorseBlackListMiddleware;
begin
  Result := THorseBlackListMiddleware.Create;
end;

end.




(*
  interface

  uses
  Horse,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.IOUtils,
  Horse.Commons;

  type
  THorseBlackListMiddleware = class;

  TAllowedIPManager = class
  private
  FMiddleware: THorseBlackListMiddleware;
  public
  constructor Create(AMiddleware: THorseBlackListMiddleware);
  function Add(const AIP: string): TAllowedIPManager;
  function &End: THorseBlackListMiddleware;
  end;

  THorseBlackListMiddleware = class
  private
  FMaxAttempts: Integer;
  FBlackList: TDictionary<string, Integer>;
  FAllowedIPs: TList<string>;
  FLock: TCriticalSection;
  FLogFile: string;
  public
  constructor Create;
  destructor Destroy; override;
  procedure Register;

  function SetLogFile(const AFileName: string): THorseBlackListMiddleware;
  function SetMaxAttempts(Value: Integer): THorseBlackListMiddleware;
  function SetAllowedIP: TAllowedIPManager; // Retorna o gerenciador de IPs permitidos

  function HorseCallback: THorseCallback;
  class function New: THorseBlackListMiddleware;
  end;

  implementation

  { TAllowedIPManager }

  constructor TAllowedIPManager.Create(AMiddleware: THorseBlackListMiddleware);
  begin
  FMiddleware := AMiddleware;
  end;

  function TAllowedIPManager.Add(const AIP: string): TAllowedIPManager;
  begin
  FMiddleware.FAllowedIPs.Add(AIP);
  Result := Self;
  end;

  function TAllowedIPManager.&End: THorseBlackListMiddleware;
  begin
  Result := FMiddleware;
  end;

  { THorseBlackListMiddleware }

  constructor THorseBlackListMiddleware.Create;
  begin
  FMaxAttempts := 5;
  FBlackList := TDictionary<string, Integer>.Create;
  FAllowedIPs := TList<string>.Create;
  FLock := TCriticalSection.Create;
  end;

  destructor THorseBlackListMiddleware.Destroy;
  begin
  FBlackList.Free;
  FAllowedIPs.Free;
  FLock.Free;
  inherited;
  end;

  function THorseBlackListMiddleware.SetLogFile(const AFileName: string): THorseBlackListMiddleware;
  begin
  FLogFile := AFileName;
  Result := Self;
  end;

  function THorseBlackListMiddleware.SetMaxAttempts(Value: Integer): THorseBlackListMiddleware;
  begin
  FMaxAttempts := Value;
  Result := Self;
  end;

  function THorseBlackListMiddleware.SetAllowedIP: TAllowedIPManager;
  begin
  Result := TAllowedIPManager.Create(Self);
  end;

  procedure THorseBlackListMiddleware.Register;
  begin
  THorse.Use(HorseCallback);
  end;

  function THorseBlackListMiddleware.HorseCallback: THorseCallback;
  begin
  Result :=
  procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
  var
  LIP, LEndpoint, LMethod: string;
  AttemptCount: Integer;
  LAccessTime: TDateTime;
  begin
  Req.Headers.TryGetValue('X-Forwarded-For', LIP);
  if LIP.Equals(EmptyStr) then
  LIP := Req.RawWebRequest.RemoteAddr;

  LEndpoint := Req.RawWebRequest.PathInfo;
  LMethod := Req.RawWebRequest.Method;
  LAccessTime := Now;

  FLock.Enter;
  try
  if FAllowedIPs.Contains(LIP) then
  begin
  Next;
  Exit;
  end;

  if FBlackList.ContainsKey(LIP) then
  AttemptCount := FBlackList[LIP] + 1
  else
  AttemptCount := 1;

  FBlackList.AddOrSetValue(LIP, AttemptCount);

  if AttemptCount > FMaxAttempts then
  begin
  if FLogFile <> EmptyStr then
  begin
  TFile.AppendAllText(FLogFile,
  Format('Blocked IP: %s [%s] %s %s'#13#10, [LIP, DateTimeToStr(LAccessTime), LEndpoint, LMethod]));
  end;

  Res.Status(THTTPStatus.Forbidden).Send('Access Denied');
  raise EHorseCallbackInterrupted.Create;
  end;
  finally
  FLock.Leave;
  end;

  Next;
  end;
  end;

  class function THorseBlackListMiddleware.New: THorseBlackListMiddleware;
  begin
  Result := THorseBlackListMiddleware.Create;
  end;

  end.
*)
