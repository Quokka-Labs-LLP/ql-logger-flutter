# Welcome to the Repository

This is a default README file for the repository.
=======
A package for efficiently storing and uploading server logs, designed to help developers
track and manage log data from past events for debugging and monitoring purposes.
## Platform Support

| Android | iOS | MacOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |    ✅    |

## Setup Instructions ##

# add the ql_logger_flutter in the pubspec.yaml file
```yaml
dependencies:
  ql_logger_flutter:
    git:
      url: https://github.com/Quokka-Labs-LLP/ql-logger-flutter.git
```

# Initialize the ql_logger_flutter into your application
This package automatically masks sensitive information such as emails, mobile numbers, and domains. It also masks commonly used keys, including:
password, pass, pwd, firstName, lastName, name, first_name, last_name, fName, and lName.

For additional keys that require masking, you can provide them as a list of strings using the [maskKeys] parameter in the [initLoggerService] function.

Initialize server logger with [initLoggerService] method:

```dart
import 'package:ql_logger_flutter/server_logs.dart';

main() async{
  ///......
  await ServerLogger.initLoggerService(
            userId: '<userId>',   //<Optional> Logs will be stored or handled separately for each user based on their unique user ID.
            userName: '<userName>', //<Optional> Logs will be stored or handled separately for each user based on their unique user name.
            env: '<environment>',   // Specifies the current project environment (e.g., 'dev' for development).
            apiKey:'<API Key>',   // API key used for authentication. Obtain this apiKey from the
                             //   log panel, where your project/<env> is listed.
            appName: '<App Name>',   // You will get the app name from logger panel 
            url: '<Logger Url>',   // URL where logs will be stored.
            maskKeys: '<Mask Keys>'  // Keys to be masked in your logs.
  );
  ///......
}
```
  
The [initLoggerService] method contains the [upload] method, which automatically uploads your previously recorded logs.

# Record your logs
For recording the logs, you have to call [ServerLogger.log()] method:
```dart
import 'package:ql_logger_flutter/server_logs.dart';
    /// Use this function where you want to record your log. 
    ServerLogger.log(
         message: '<Message>',   // Log message or event details to be stored.
         logType: '<Log Type>'   // logType is used to define the type of logs you want to store  
                                // available log type (custom/error/user/open)
    );
```

# Record the network requests
For recording your network request just add the [ServerRequestInterceptor()] into your dio interceptor.
This will automatically record you api logs, no need to handle separately

```dart
  final Dio _dio = Dio();
  _dio.interceptors.add(ServerRequestInterceptor());
```


## Following functions used to 
# Set your user's Configuration
```dart
  ServerLogger.setUserConfig(config: UserConfig(userId: '<userId>', userName: '<userName>'));
```
# get your user's Configuration
```dart
  UserConfig config = ServerLogger.getUserConfig();
```
