import 'package:device_info/device_info.dart';
import 'package:fimber/fimber.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterfirebaseremoteconfig/HagertyWidget.dart';
import 'package:tealium/tealium.dart';

FimberLog rcLogger = FimberLog("Remote_Config_Tag");
FimberLog tealLogger = FimberLog("Telium_Config_Tag");
int eventCounter = 0;
const String TAG_REFRESH_PRESS = "refresh_press";

void main() {
  Fimber.plantTree(DebugTree());

  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
      title: 'Hagerty Remote Config POC',
      home: FutureBuilder<RemoteConfig>(
        future: setupRemoteConfig(),
        builder: (BuildContext context, AsyncSnapshot<RemoteConfig> snapshot) {
          setUpTealium(context);
          return snapshot.hasData ? WelcomeWidget(remoteConfig: snapshot.data) : Container();
        },
      )));
  Fimber.plantTree(DebugTree.elapsed());
}

Future<void> setUpTealium(BuildContext context) async {
  //Here we inspect various aspects about the device and stuff it in the responses for analytical purposes
  TargetPlatform platform = Theme.of(context).platform;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String os;
  String make;
  String model;
  bool isReal;

  if (platform == TargetPlatform.android) {
    tealLogger.i("Running on Android");
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Running on ${androidInfo.model}');
    os = androidInfo.version.sdkInt.toString();
    make = androidInfo.manufacturer;
    model = androidInfo.model;
    isReal = androidInfo.isPhysicalDevice;
  } else {
    tealLogger.i("Running on iOS");
    IosDeviceInfo iOSInfo = await deviceInfo.iosInfo;
    print('Running on ${iOSInfo.model}');
    os = iOSInfo.systemName;
    make = "Apple";
    model = iOSInfo.model;
    isReal = iOSInfo.isPhysicalDevice;
  }
  tealLogger.i("os: $os   make: $make   model: $model   isReal: $isReal");
  tealLogger.i("Setting that data now");

  Tealium.setPersistentData({
    'deviceOSKey': os,
    'deviceSpecsKey': [make, model, isReal]
  });
}

class MyApp extends HagertyWidget {
  @override
  Widget build(BuildContext context) {
    setName();
    Tealium.trackView(getName());

    return MaterialApp(
      title: 'Hagerty Firebase Remote Config POC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Hagerty RC Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class WelcomeWidget extends AnimatedWidget {
  WelcomeWidget({this.remoteConfig}) : super(listenable: remoteConfig);
  final RemoteConfig remoteConfig;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hagerty Remote Config POC'),
      ),
      body: Center(child: Text('Welcome ${remoteConfig.getString('welcome')}')),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.refresh),
          onPressed: () async {
            eventCounter++;
            tealLogger.i("Refresh pressed $eventCounter times so far");
            Tealium.trackEvent(TAG_REFRESH_PRESS);

            try {
              // Using default duration to force fetching from remote server.
              await remoteConfig.fetch(expiration: const Duration(seconds: 0));
              await remoteConfig.activateFetched();
            } on FetchThrottledException catch (exception) {
              // Fetch throttled.
              print(exception);
            } catch (exception) {
              print('Unable to fetch remote config. Cached or default values will be '
                  'used');
            }
          }),
    );
  }
}

Future<RemoteConfig> setupRemoteConfig() async {
  Tealium teal = Tealium.initializeCustom("hagerty", "insider", "dev", null, null, "main", true, null, null, null, true);

  final RemoteConfig remoteConfig = await RemoteConfig.instance;
  // Enable developer mode to relax fetch throttling
  remoteConfig.setConfigSettings(RemoteConfigSettings(debugMode: true));
  remoteConfig.setDefaults(<String, dynamic>{
    'welcome': 'default welcome',
    'hello': 'default hello',
  });
  await remoteConfig.fetch();
  await remoteConfig.activateFetched();
  if (remoteConfig.getString('welcome').isEmpty) {
    rcLogger.i('We didn\'t get didly.');
  } else {
    rcLogger.i('Data found. Welcome: ${remoteConfig.getString('welcome')}');
  }
  return remoteConfig;
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
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
            Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.display1,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
