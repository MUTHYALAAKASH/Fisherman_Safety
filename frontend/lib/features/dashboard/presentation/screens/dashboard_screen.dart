import 'package:flutter/material.dart';
import '../../../map/presentation/screens/map_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Simply proxy directly into the stunning navigation map view.
    return const MapScreen();
  }
}
