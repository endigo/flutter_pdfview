import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String pathPDF = "";
  String landscapePathPdf = "";
  String remotePDFpath = "";
  String corruptedPathPDF = "";

  @override
  void initState() {
    super.initState();
    fromAsset('assets/corrupted.pdf', 'corrupted.pdf').then((f) {
      setState(() {
        corruptedPathPDF = f.path;
      });
    });
    fromAsset('assets/demo-link.pdf', 'demo.pdf').then((f) {
      setState(() {
        pathPDF = f.path;
      });
    });
    fromAsset('assets/demo-landscape.pdf', 'landscape.pdf').then((f) {
      setState(() {
        landscapePathPdf = f.path;
      });
    });

    createFileOfPdfUrl().then((f) {
      setState(() {
        remotePDFpath = f.path;
      });
    });
  }

  Future<File> createFileOfPdfUrl() async {
    Completer<File> completer = Completer();
    print("Start download file from internet!");
    try {
      // "https://berlin2017.droidcon.cod.newthinking.net/sites/global.droidcon.cod.newthinking.net/files/media/documents/Flutter%20-%2060FPS%20UI%20of%20the%20future%20%20-%20DroidconDE%2017.pdf";
      // final url = "https://pdfkit.org/docs/guide.pdf";
      final url = "http://www.pdf995.com/samples/pdf.pdf";
      final filename = url.substring(url.lastIndexOf("/") + 1);
      var request = await HttpClient().getUrl(Uri.parse(url));
      var response = await request.close();
      var bytes = await consolidateHttpClientResponseBytes(response);
      var dir = await getApplicationDocumentsDirectory();
      print("Download files");
      print("${dir.path}/$filename");
      File file = File("${dir.path}/$filename");

      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }

    return completer.future;
  }

  Future<File> fromAsset(String asset, String filename) async {
    // To open from assets, you can copy them to the app storage folder, and the access them "locally"
    Completer<File> completer = Completer();

    try {
      var dir = await getApplicationDocumentsDirectory();
      File file = File("${dir.path}/$filename");
      var data = await rootBundle.load(asset);
      var bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter PDF View',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                TextButton(
                  child: Text("Open PDF"),
                  onPressed: () {
                    if (pathPDF.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: pathPDF),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Open Landscape PDF"),
                  onPressed: () {
                    if (landscapePathPdf.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: landscapePathPdf),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Remote PDF"),
                  onPressed: () {
                    if (remotePDFpath.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: remotePDFpath),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Open PDF (iPad Safe Mode)"),
                  onPressed: () {
                    if (pathPDF.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(
                            path: pathPDF,
                            isIPadSafe: true,
                          ),
                        ),
                      );
                    }
                  },
                ),
                TextButton(
                  child: Text("Open Corrupted PDF"),
                  onPressed: () {
                    if (pathPDF.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PDFScreen(path: corruptedPathPDF),
                        ),
                      );
                    }
                  },
                )
              ],
            );
          },
        )),
      ),
    );
  }
}

class PDFScreen extends StatefulWidget {
  final String? path;
  final bool isIPadSafe;

  PDFScreen({Key? key, this.path, this.isIPadSafe = false}) : super(key: key);

  _PDFScreenState createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with WidgetsBindingObserver {
  final Completer<PDFViewController> _controller = Completer<PDFViewController>();
  int? _pages = 0;
  int? _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';

  double _xOffset = 0.0;
  double _yOffset = 0.0;
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.path,
            // iPad Safe Mode: Avoid conflicting scroll configurations
            enableSwipe: widget.isIPadSafe ? true : true,
            swipeHorizontal:
                widget.isIPadSafe ? false : true, // Vertical scrolling is safer on iPad
            autoSpacing: widget.isIPadSafe ? true : false, // Let PDFKit handle spacing
            pageFling: widget.isIPadSafe ? false : true, // Disable page fling to avoid conflicts
            pageSnap: widget.isIPadSafe ? false : true, // Disable page snap for smoother scrolling
            defaultPage: _currentPage!,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false, // if set to true the link is handled in flutter
            backgroundColor: Color(0xFFFEF7FF),
            nightMode: true,
            maxZoom: 4.0,
            minZoom: 1.0,
            onRender: (_pages) {
              setState(() {
                this._pages = _pages;
                _isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
              print(error.toString());
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = '$page: ${error.toString()}';
              });
              print('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _controller.complete(pdfViewController);
            },
            onLinkHandler: (String? uri) {
              print('goto uri: $uri');
            },
            onPageChanged: (int? page, int? total) {
              print('page change: ${(page ?? 0) + 1}/$total');
              setState(() {
                _currentPage = page;
              });
            },
            onLoadComplete: (int? pages) {
              final pagesText = '# of pages: $pages';
              final snackBar = SnackBar(content: Text(pagesText));
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
              print(pagesText);
            },
            onDraw: (double pdfXOffset, double pdfYOffset, double pdfScale) {
              setState(() {
                _xOffset = pdfXOffset;
                _yOffset = pdfYOffset;
                _scale = pdfScale;
              });
              print('onDraw - x offset: $pdfXOffset, y offset: $pdfYOffset scale: $pdfScale');
            },
          ),
          _errorMessage.isEmpty
              ? !_isReady
                  ? Center(child: CircularProgressIndicator())
                  : Container()
              : Center(child: Text(_errorMessage)),
          Positioned(
              left: 10,
              top: 10,
              child: Container(
                color: Colors.orange,
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('X Offset: ${_xOffset.toStringAsFixed(2)}'),
                    Text('Y Offset: ${_yOffset.toStringAsFixed(2)}'),
                    Text('Scale: ${_scale.toStringAsFixed(2)}')
                  ],
                ),
              ))
        ],
      ),
      floatingActionButton: FutureBuilder<PDFViewController>(
        future: _controller.future,
        builder: (context, AsyncSnapshot<PDFViewController> snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton.extended(
              label: Text("Go to ${this._pages! ~/ 2}"),
              onPressed: () async {
                await snapshot.data!.setPage(this._pages! ~/ 2);
              },
            );
          }

          return Container();
        },
      ),
    );
  }
}
