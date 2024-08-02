
# Horse.Blacklist Middleware

`Horse.Blacklist` é um middleware para Delphi usando o framework Horse, que permite bloquear endereços IP após um número configurável de tentativas de acesso falhas, além de permitir o registro de IPs permitidos. Este middleware é altamente configurável e permite o uso de listas de IPs através de diferentes fontes, como listas, DataSets, ou JSON.

## Instalação

### Requisitos

- Delphi com suporte para Horse Framework.
- Gerenciador de pacotes Boss para instalação.

### Instalação via Boss

Execute o seguinte comando no terminal para instalar o middleware via Boss:

```sh
boss install <repo-link-do-middleware>
```

## Uso

### Configuração Básica

Aqui está um exemplo básico de como usar o `Horse.Blacklist` middleware:

```delphi
uses
  Horse, Horse.Blacklist, System.SysUtils;

var
  LBlackList: THorseBlackListMiddleware;

begin
  LBlackList := THorseBlackListMiddleware.New
    .SetLogFile('blacklist.log')  // Arquivo de log para IPs bloqueados
    .SetMaxAttempts(3);            // Número máximo de tentativas antes do bloqueio

  THorse.Use(LBlackList.HorseCallback);

  THorse.Get('ping', 
    procedure (Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

### Adicionando IPs Permitidos

#### Adicionando IPs Manualmente

Você pode adicionar IPs permitidos manualmente através do método `SetAllowedIP`:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP
    .Add('127.0.0.1')
    .Add('192.168.0.100')
  .&End;
```

#### Adicionando IPs a partir de um DataSet

Se você tem uma lista de IPs em um DataSet, pode adicioná-los da seguinte forma:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP(MyDataSet, 'IPFieldName'); // 'IPFieldName' é o nome do campo que contém os IPs
```

#### Adicionando IPs a partir de um TList<string>

Caso você tenha uma lista de IPs em um `TList<string>`, pode usá-la diretamente:

```delphi
var
  IPList: TList<string>;

begin
  IPList := TList<string>.Create;
  try
    IPList.Add('127.0.0.1');
    IPList.Add('192.168.0.100');

    LBlackList := THorseBlackListMiddleware.New
      .SetAllowedIP(IPList);
  finally
    IPList.Free;
  end;
end.
```

#### Adicionando IPs a partir de um JSON

Você pode também passar uma lista de IPs em formato JSON:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP('["127.0.0.1", "192.168.0.100"]');
```

### Configurando o Log de Tentativas

O middleware pode registrar tentativas de acesso bloqueadas em um arquivo de log:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetLogFile('blacklist.log');  // Define o caminho do arquivo de log
```

### Registro do Middleware

Após configurar o middleware, registre-o com o Horse:

```delphi
THorse.Use(LBlackList.HorseCallback);
```

### Exemplo Completo

Aqui está um exemplo completo integrando todas as funcionalidades:

```delphi
program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Horse, Horse.Blacklist, Data.DB, System.Generics.Collections, System.SysUtils;

var
  LBlackList: THorseBlackListMiddleware;
  IPList: TList<string>;
  JSONString: string;

begin
  JSONString := '["127.0.0.1", "192.168.0.100"]';

  IPList := TList<string>.Create;
  try
    IPList.Add('127.0.0.1');
    IPList.Add('192.168.0.200');

    LBlackList := THorseBlackListMiddleware.New
      .SetLogFile('blacklist.log')  // Log para IPs bloqueados
      .SetMaxAttempts(3)             // Número máximo de tentativas antes do bloqueio
      .SetAllowedIP(IPList)          // Adiciona IPs a partir de uma lista
      .SetAllowedIP(JSONString);     // Adiciona IPs a partir de um JSON

    THorse.Use(LBlackList.HorseCallback);

    THorse.Get('ping', 
      procedure (Req: THorseRequest; Res: THorseResponse; Next: TProc)
      begin
        Res.Send('pong');
      end);

    THorse.Listen(9000);
  finally
    IPList.Free;
  end;
end.
```

## Contribuição

Contribuições são bem-vindas! Sinta-se à vontade para enviar PRs com melhorias ou correções.

## Licença

Este projeto está licenciado sob os termos da licença MIT. Consulte o arquivo `LICENSE` para mais detalhes.
