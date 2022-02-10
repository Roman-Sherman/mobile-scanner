import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const AnalyzeView());
}

class AnalyzeView extends StatefulWidget {
  const AnalyzeView({Key? key}) : super(key: key);

  @override
  _AnalyzeViewState createState() => _AnalyzeViewState();
}

class _AnalyzeViewState extends State<AnalyzeView>
    with SingleTickerProviderStateMixin {
  List<Offset> points = [];

  CameraController cameraController = CameraController();

  String? barcode = null;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return Stack(
            children: [
              CameraView(
                  controller: cameraController,
                  onDetect: (barcode, args) {
                    if (this.barcode != barcode.rawValue) {
                      this.barcode = barcode.rawValue;
                      if (barcode.corners != null) {
                        debugPrint('Size: ${MediaQuery.of(context).size}');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${barcode.rawValue}'),
                          duration: Duration(milliseconds: 200),
                          animation: null,
                        ));
                        setState(() {
                          final List<Offset> points = [];
                          double factorWidth = args.size.width / 520;
                          double factorHeight = args.size.height / 640;
                          for (var point in barcode.corners!) {
                            points.add(Offset(point.dx * factorWidth,
                                point.dy * factorHeight));
                          }
                          this.points = points;
                        });
                      }
                    }
                    // Default 640 x480
                  }),
              Container(
                // width: 400,
                // height: 400,
                child: CustomPaint(
                  painter: OpenPainter(points),
                ),
              ),
              Container(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.only(bottom: 80.0),
                child: IconButton(
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController.torchState,
                    builder: (context, state, child) {
                      final color =
                          state == TorchState.off ? Colors.grey : Colors.white;
                      return Icon(Icons.bolt, color: color);
                    },
                  ),
                  iconSize: 32.0,
                  onPressed: () => cameraController.torch(),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void display(Barcode barcode) {
    Navigator.of(context).popAndPushNamed('display', arguments: barcode);
  }
}

class OpenPainter extends CustomPainter {
  final List<Offset> points;

  OpenPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    var paint1 = Paint()
      ..color = Color(0xff63aa65)
      ..strokeWidth = 10;
    //draw points on canvas
    canvas.drawPoints(PointMode.points, points, paint1);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class OpacityCurve extends Curve {
  @override
  double transform(double t) {
    if (t < 0.1) {
      return t * 10;
    } else if (t <= 0.9) {
      return 1.0;
    } else {
      return (1.0 - t) * 10;
    }
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
//
// void main() {
//   debugPaintSizeEnabled = false;
//   runApp(HomePage());
// }
//
// class HomePage extends StatefulWidget {
//   @override
//   HomeState createState() => HomeState();
// }
//
// class HomeState extends State<HomePage> {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(home: MyApp());
//   }
// }
//
// class MyApp extends StatefulWidget {
//   @override
//   _MyAppState createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   String? qr;
//   bool camState = false;
//
//   @override
//   initState() {
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Plugin example app'),
//       ),
//       body: Center(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Expanded(
//                 child: camState
//                     ? Center(
//                   child: SizedBox(
//                     width: 300.0,
//                     height: 600.0,
//                     child: MobileScanner(
//                       onError: (context, error) => Text(
//                         error.toString(),
//                         style: TextStyle(color: Colors.red),
//                       ),
//                       qrCodeCallback: (code) {
//                         setState(() {
//                           qr = code;
//                         });
//                       },
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.transparent,
//                           border: Border.all(
//                               color: Colors.orange,
//                               width: 10.0,
//                               style: BorderStyle.solid),
//                         ),
//                       ),
//                     ),
//                   ),
//                 )
//                     : Center(child: Text("Camera inactive"))),
//             Text("QRCODE: $qr"),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//           child: Text(
//             "press me",
//             textAlign: TextAlign.center,
//           ),
//           onPressed: () {
//             setState(() {
//               camState = !camState;
//             });
//           }),
//     );
//   }
// }
