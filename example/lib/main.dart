import 'package:flutter/material.dart';
import 'package:ql_logger_flutter/server_logs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<String> maskKeys = [
    'password',
    'pass',
    'pwd',
    'phone',
    'fName',
    'lName',
    'first_name',
    'last_name',
    'f_name',
    'l_name',
  ];
  await ServerLogger.initLoggerService(
      url: '<Your API url>',
      userId: '2',
      env: 'dev',
      apiKey: '<Your API key>',
      appName: 'mobile-test-2811',
      maskKeys: maskKeys);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logger Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Logger Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    _addLogs();
  }

  Future _addLogs() async {
    debugPrint('printing the stored logs: ${ServerLogger.log(message: 'My mobile numbers are '
        '+1234567890, 1234567890, 123 456 7890, 123-456-7890, +91 1234567890 +911234567890, +1 1234567890, +123 1234567890,\n '
        'password: Test@123, first_name: User, last_name: Test, email: abcd@efgh.ijk\n'
        'Coordinates: 28.497917001843486, 77.41316415750744 \n'
        'urls : https://www.example.com/route/subroute, http://www.example.com/route/subroute,')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
            ),
            const SizedBox(
              height: 50,
            ),
            ElevatedButton(
              onPressed: () async {
                await ServerLogger.getLog();
              },
              child: const Text('Get Logs Button'),
            ),
            const SizedBox(
              height: 50,
            ),
            ElevatedButton(
              onPressed: () async {
                await ServerLogger.uploadTodayLogs();
              },
              child: const Text('Upload Logs'),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
