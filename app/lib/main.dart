import 'package:flutter/material.dart';

import 'app/geode_app.dart';
import 'ui/basic/basic_ui_kit.dart';

/// To change the look of the whole app, swap [BasicUiKit] for another `GeodeUiKit`.
void main() => runApp(const GeodeApp(ui: BasicUiKit()));
