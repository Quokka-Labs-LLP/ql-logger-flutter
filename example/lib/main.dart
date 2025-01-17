import 'package:flutter/material.dart';
import 'package:ql_logger_flutter/ql_logger_flutter.dart';

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
      userId: '<User Id>',
      env: '<Environment>',
      apiToken: '<Auth token>',
      appName: '<App Name>',
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
        primaryColor: Colors.deepPurpleAccent,
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Ql Logger Flutter'),
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
  bool isUploading = false;
  bool isRecording = false;
  bool isUpdatingContent = false;
  String logs = '';
  final TextEditingController _controller = TextEditingController(
      text: 'My mobile numbers are '
          '+1234567890, 1234567890, 123 456 7890, 123-456-7890, +91 1234567890 +911234567890, +1 1234567890, +123 1234567890,\n '
          'password: Test@123, first_name: User, last_name: Test, email: abcd@efgh.ijk\n'
          'Coordinates: 28.497917001843486, 77.41316415750744 \n'
          'urls : https://www.example.com/route/subroute, http://www.example.com/route/subroute,');
  final _formKey = GlobalKey<FormState>();

  Future _addLog(String text, {LogType logType = LogType.user}) async {
    try {
      await ServerLogger.log(message: text, logType: logType.name);
      debugPrint('printing the stored logs: $text}');
      _showSnackBar('Log recorded', Colors.green);
    } catch (e) {
      debugPrint('There is some problem in recording the log.');
      _showSnackBar(
          'There is some problem in recording the log.', Colors.redAccent);
    }
  }

  @override
  void initState() {
    updateLogs();
    super.initState();
  }

  Future updateLogs() async {
    logs = await ServerLogger.getLog();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Form(
        key: _formKey,
        child: Container(
          color: Colors.white,
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(
                height: 15,
              ),
              ColoredBox(
                color: Colors.white,
                child: TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  validator: (value) =>
                      value != '' ? null : 'Please provide the text to record',
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              _button(
                  isLoading: isRecording,
                  onTap: () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      setState(() {
                        isRecording = true;
                      });
                      _addLog(
                        _controller.text,
                      );
                      setState(() {
                        isRecording = false;
                      });
                    }
                  },
                  text: 'Record Log'),
              const SizedBox(
                height: 10,
              ),
              _button(
                  isLoading: isUploading,
                  onTap: () async {
                    setState(() {
                      isUploading = true;
                    });
                    String message = await ServerLogger.uploadTodayLogs();
                    setState(() {
                      isUploading = false;
                    });
                    _showSnackBar(message, Colors.green);
                  },
                  text: 'Upload Today\'s Log'),
              const SizedBox(
                height: 10,
              ),
              const SizedBox(
                height: 10,
              ),
              const Divider(
                thickness: 3,
              ),
              Container(
                width: double.maxFinite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.grey.withOpacity(0.5)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Logs',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 24),
                    ),
                    _button(
                        isLoading: isUpdatingContent,
                        text: 'Update logs',
                        onTap: () async {
                          setState(() {
                            isUpdatingContent = true;
                          });
                          await updateLogs();
                          setState(() {
                            isUpdatingContent = false;
                          });
                          _showSnackBar('Content updated', Colors.green);
                        },
                        expanded: false),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    children: [
                      _contentWidget(content: logs, onUpdate: () {}),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _button(
      {required String text,
      required VoidCallback onTap,
      bool isLoading = false,
      bool expanded = true}) {
    return SizedBox(
      width: expanded ? MediaQuery.of(context).size.width : null,
      child: ElevatedButton(
          style: ButtonStyle(
              backgroundColor:
                  WidgetStatePropertyAll(Theme.of(context).primaryColor),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
          onPressed: onTap,
          child: isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                )
              : Text(
                  text,
                  style: const TextStyle(color: Colors.white),
                )),
    );
  }

  _showSnackBar(String text, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        content: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  _contentWidget({required String content, required Function() onUpdate}) {
    return Container(
      width: MediaQuery.of(context).size.width,
      color: Colors.white,
      child: Text(content.isNotEmpty ? content : 'No log recorded.'),
    );
  }
}
