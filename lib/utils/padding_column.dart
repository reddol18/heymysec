import 'package:flutter/material.dart';

class PaddingColumn extends StatelessWidget {
  final List<Widget> children;
  final double paddingValue;

  const PaddingColumn({
    Key? key,
    required this.children,
    required this.paddingValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(this.paddingValue),
      child: Column(
      children: children,
    ),
    );
  }
}