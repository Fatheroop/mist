import 'dart:io';

import 'package:flutter/material.dart';

class JsonViewer extends StatelessWidget {
  final File file;
  const JsonViewer({super.key, required this.file});

  Future<String> readfile() async {
    if (!file.existsSync()) {
      return "file not found";
    } else {
      String data = await file.readAsString();
      return data;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(file.path.split("/").last)),
      body: SafeArea(
        child: FutureBuilder(
          future: readfile(),
          builder: (context, asyncSnapshot) {
            if (asyncSnapshot.hasData) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SelectableText(
                  asyncSnapshot.data ?? "no data found",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              );
            }
            if (asyncSnapshot.connectionState == ConnectionState.waiting) {
              return Text("Data is loading .....");
            } else {
              return Text(
                "Something went wrong.${asyncSnapshot.error.toString()}",
              );
            }
          },
        ),
      ),
    );
  }
}
