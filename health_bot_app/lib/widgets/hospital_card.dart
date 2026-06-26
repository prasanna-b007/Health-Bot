import 'package:flutter/material.dart';

class HospitalCard extends StatelessWidget {
  const HospitalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        title: Text('Hospital Name'),
        subtitle: Text('Distance: 0 km'),
      ),
    );
  }
}
