# ql_logger_flutter
=======
A package for efficiently storing and uploading server logs, designed to help developers
track and manage log data from past events for debugging and monitoring purposes.
## Platform Support

| Android | iOS | MacOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |    ✅    |

## Setup Instructions ##

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
            apiToken:'<Auth token>',   // use your API's authorization token here.
            appName: '<App Name>',   // You will get the app name from logger panel 
            url: '<Logger Url>',   // URL where logs will be stored.
            maskKeys: '<Mask Keys>',  // Keys to be masked in your logs.
            recordPermission: '<Record Permission>', // Key to enable or disable recording permissions. 
            durationInMin: '<Duration>'  // Duration (in minutes) for periodically uploading logs.
  );
  ///......
}
```

Make sure that the API which you are using here should accept the following keys. 
```text
project
env
date
log_type
log_name
content
```
  
The [initLoggerService] method contains the [upload] method, which automatically uploads your previously recorded logs.

# Record your logs
For recording the logs, you have to call [ServerLogger.log()] method:
```dart
import 'package:ql_logger_flutter/server_logs.dart';
    /// Use this function to record your log. 
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

# Logs uploading status
Sets callbacks to handle the response and errors from the log upload API.
```dart
ServerLogger.logUploadingResponse(('<response>'){
debugPrint('logger api success response: ${response.toString()}');
}, onError: (e){
debugPrint('logger api error response: ${e.toString()}');
});
```

# Captures errors during an async log call.
Set a callback function to handle exceptions that occur during logging.
```dart
ServerLogger.onException(onError: (error){
debugPrint('log exception: ${error.toString()}');
});
```

# Checks if the logger is initialized. 
Checks if the logger service is ready before logging operations.

```dart
ServerLogger.isInitialized
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
