import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

/// Home screen of the example app: copies the bundled sample documents to disk
/// and offers a button per document.
class MyApp extends StatefulWidget {
  /// Creates the example app.
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String pathPDF = '';
  String landscapePathPdf = '';
  String remotePDFpath = '';
  String corruptedPathPDF = '';

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
    final Completer<File> completer = Completer();
    debugPrint('Start download file from internet!');
    try {
      // 'https://berlin2017.droidcon.cod.newthinking.net/sites/global.droidcon.cod.newthinking.net/files/media/documents/Flutter%20-%2060FPS%20UI%20of%20the%20future%20%20-%20DroidconDE%2017.pdf';
      // final url = 'https://pdfkit.org/docs/guide.pdf';
      final url = 'http://www.pdf995.com/samples/pdf.pdf';
      final filename = url.substring(url.lastIndexOf('/') + 1);
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      final dir = await getApplicationDocumentsDirectory();
      debugPrint('Download files');
      debugPrint('${dir.path}/$filename');
      final File file = File('${dir.path}/$filename');

      await file.writeAsBytes(bytes, flush: true);
      completer.complete(file);
    } catch (e) {
      throw Exception('Error parsing asset file!');
    }

    return completer.future;
  }

  Future<File> fromAsset(String asset, String filename) async {
    // To open from assets, you can copy them to the app storage folder, and the access them "locally"
    final Completer<File> completer = Completer();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final File file = File('${dir.path}/$filename');
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
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
                  child: const Text('Open PDF'),
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
                  child: const Text('Open Landscape PDF'),
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
                  child: const Text('Remote PDF'),
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
                  child: const Text('Open PDF (iPad Safe Mode)'),
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
                  child: const Text('Open Corrupted PDF'),
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

/// Full-screen viewer that renders a single document with [PDFView].
class PDFScreen extends StatefulWidget {
  /// Path of the document to display.
  final String? path;

  /// Whether to use the conservative scroll configuration that behaves best on
  /// iPad.
  final bool isIPadSafe;

  /// Creates a viewer for the document at [path].
  const PDFScreen({super.key, this.path, this.isIPadSafe = false});

  @override
  State<PDFScreen> createState() => _PDFScreenState();
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
        title: const Text('Document'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            // iPad Safe Mode: Avoid conflicting scroll configurations
            swipeHorizontal:
                widget.isIPadSafe ? false : true, // Vertical scrolling is safer on iPad
            autoSpacing: widget.isIPadSafe ? true : false, // Let PDFKit handle spacing
            pageFling: widget.isIPadSafe ? false : true, // Disable page fling to avoid conflicts
            pageSnap: false, // Disable page snap for smoother scrolling
            showScrollIndicators: true,
            defaultPage: _currentPage!,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false, // if set to true the link is handled in flutter
            backgroundColor: const Color(0xFFFEF7FF),
            nightMode: true,
            maxZoom: 4.0,
            minZoom: 1.0,
            onRender: (pages) {
              setState(() {
                _pages = pages;
                _isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
              debugPrint(error.toString());
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = '$page: ${error.toString()}';
              });
              debugPrint('$page: ${error.toString()}');
            },
            onViewCreated: (PDFViewController pdfViewController) {
              _controller.complete(pdfViewController);
            },
            onLinkHandler: (String? uri) {
              debugPrint('goto uri: $uri');
            },
            onPageChanged: (int? page, int? total) {
              debugPrint('page change: ${(page ?? 0) + 1}/$total');
              setState(() {
                _currentPage = page;
              });
            },
            onLoadComplete: (int? pages) {
              final pagesText = '# of pages: $pages';
              final snackBar = SnackBar(content: Text(pagesText));
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
              debugPrint(pagesText);
            },
            onDraw: (double pdfXOffset, double pdfYOffset, double pdfScale) {
              setState(() {
                _xOffset = pdfXOffset;
                _yOffset = pdfYOffset;
                _scale = pdfScale;
              });
              debugPrint('onDraw - x offset: $pdfXOffset, y offset: $pdfYOffset scale: $pdfScale');
            },
          ),
          _errorMessage.isEmpty
              ? !_isReady
                  ? const Center(child: CircularProgressIndicator())
                  : Container()
              : Center(child: Text(_errorMessage)),
          Positioned(
              left: 10,
              top: 10,
              child: Container(
                color: Colors.orange,
                padding: const EdgeInsets.all(10),
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
              label: Text('Go to ${_pages! ~/ 2}'),
              onPressed: () async {
                await snapshot.data!.setPage(_pages! ~/ 2);
              },
            );
          }

          return Container();
        },
      ),
    );
  }
}
