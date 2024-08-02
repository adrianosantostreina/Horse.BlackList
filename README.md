
# Horse.Blacklist Middleware

`Horse.Blacklist` is a middleware for Delphi using the Horse framework that allows blocking IP addresses after a configurable number of failed access attempts, as well as allowing the registration of allowed IPs. This middleware is highly configurable and allows the use of IP lists from different sources, such as lists, DataSets, or JSON.

## Installation

### Requirements

- Delphi with support for the Horse Framework.
- Boss package manager for installation.

### Installation via Boss

Run the following command in the terminal to install the middleware via Boss:

```sh
boss install github.com/adrianosantostreina/Horse.BlackList
```

## Usage

### Basic Configuration

Here is a basic example of how to use the `Horse.Blacklist` middleware:

```delphi
uses
  Horse, Horse.Blacklist, System.SysUtils;

var
  LBlackList: THorseBlackListMiddleware;

begin
  LBlackList := THorseBlackListMiddleware.New
    .SetLogFile('blacklist.log')  // Log file for blocked IPs
    .SetMaxAttempts(3);            // Maximum number of attempts before blocking

  THorse.Use(LBlackList.HorseCallback);

  THorse.Get('ping', 
    procedure (Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

### Adding Allowed IPs

#### Adding IPs Manually

You can manually add allowed IPs through the `SetAllowedIP` method:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP
    .Add('127.0.0.1')
    .Add('192.168.0.100')
  .&End;
```

#### Adding IPs from a DataSet

If you have a list of IPs in a DataSet, you can add them as follows:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP(MyDataSet, 'IPFieldName'); // 'IPFieldName' is the name of the field that contains the IPs
```

#### Adding IPs from a TList<string>

If you have a list of IPs in a `TList<string>`, you can use it directly:

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

#### Adding IPs from a JSON

You can also pass a list of IPs in JSON format:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetAllowedIP('["127.0.0.1", "192.168.0.100"]');
```

### Configuring Access Attempt Logging

The middleware can log blocked access attempts to a log file:

```delphi
LBlackList := THorseBlackListMiddleware.New
  .SetLogFile('blacklist.log');  // Define the log file path
```

### Middleware Registration

After configuring the middleware, register it with Horse:

```delphi
THorse.Use(LBlackList.HorseCallback);
```

### Complete Example

Here is a complete example integrating all functionalities:

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
      .SetLogFile('blacklist.log')  // Log for blocked IPs
      .SetMaxAttempts(3)             // Maximum number of attempts before blocking
      .SetAllowedIP(IPList)          // Add IPs from a list
      .SetAllowedIP(JSONString);     // Add IPs from a JSON

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

## Contribution

Contributions are welcome! Feel free to submit PRs with improvements or fixes.

## License

This project is licensed under the terms of the MIT license. See the `LICENSE` file for more details.
