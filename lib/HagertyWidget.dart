import 'package:flutter/cupertino.dart';
import 'package:tealium/tealium.dart';

class HagertyWidget extends StatelessWidget {
  String screenName;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return null;
  }

  void setName([String name]) {
    if (name.isEmpty) {
      name = runtimeType.toString();
    }
    Tealium.trackView(name);
  }

  String getName() {
    return screenName;
  }
}
