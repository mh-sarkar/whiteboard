part of whiteboard;

typedef OnRedoUndo = void Function(bool isUndoAvailable, bool isRedoAvailable);

/// Whiteboard widget for canvas
class WhiteBoard extends StatefulWidget {
  /// WhiteBoardController for actions.
  final WhiteBoardController? controller;

  /// [Color] for background of whiteboard.
  final Color backgroundColor;

  /// [Color] for background of whiteboard.
  final String? backgroundImage;

  /// [Color] of strokes.
  final Color strokeColor;

  /// Width of strokes
  final double strokeWidth;

  /// Flag for erase mode
  final bool isErasing;

  /// Flag for erase mode
  final Size screenSize;

  /// Callback for [Canvas] when it converted to image data.
  /// Use [WhiteBoardController] to convert.
  final ValueChanged<Uint8List>? onConvertImage;

  /// This callback exposes if undo / redo is available and called successfully.
  final OnRedoUndo? onRedoUndo;

  const WhiteBoard({
    Key? key,
    this.controller,
    this.backgroundColor = Colors.white,
    this.backgroundImage,
    this.strokeColor = Colors.blue,
    this.strokeWidth = 4,
    this.isErasing = false,
    this.onConvertImage,
    this.onRedoUndo,
    required this.screenSize,
  }) : super(key: key);

  @override
  _WhiteBoardState createState() => _WhiteBoardState();
}

class _WhiteBoardState extends State<WhiteBoard> {
  final _undoHistory = <RedoUndoHistory>[];
  final _redoStack = <RedoUndoHistory>[];

  final _strokes = <_Stroke>[];

  // cached current canvas size
  late Size _canvasSize;

  bool isImageLoaded = false;

  // convert current canvas to image data.
  Future<void> _convertToImage(ImageByteFormat format) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Emulate painting using _FreehandPainter
    // recorder will record this painting
    _FreehandPainter(
      _strokes,
      widget.backgroundColor,
      image,
    ).paint(canvas, _canvasSize);

    // Stop emulating and convert to Image
    final result = await recorder.endRecording().toImage(
        image != null ? image!.width : _canvasSize.width.floor(),
        image != null ? image!.height : _canvasSize.height.floor());

    // Cast image data to byte array with converting to given format
    final converted =
        (await result.toByteData(format: format))!.buffer.asUint8List();

    widget.onConvertImage?.call(converted);
  }

  ui.Image? image;
  Future<void> init() async {
    isImageLoaded = false;
    setState(() {});
    Uint8List bytes = widget.backgroundImage!.contains('http')
        ? (await NetworkAssetBundle(Uri.parse(widget.backgroundImage!))
                .load(widget.backgroundImage!))
            .buffer
            .asUint8List()
        : (await File(widget.backgroundImage!).readAsBytes());
    final data = resizeImage(bytes);
    image = await loadImage(data);
  }

  Completer<ui.Image>? completer;
  Future<ui.Image> loadImage(Uint8List img) async {
    completer = Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      setState(() {
        isImageLoaded = true;
      });
      return completer!.complete(img);
    });
    return completer!.future;
  }

  Uint8List resizeImage(Uint8List data) {
    Uint8List resizedData = data;
    IMG.Image? img = IMG.decodeImage(data);
    IMG.Image resized = IMG.copyResize(img!,
        width: widget.screenSize.width.toInt(),
        height: (widget.screenSize.height * .75).toInt(),
        interpolation: IMG.Interpolation.cubic);
    resizedData = IMG.encodeJpg(resized);
    return resizedData;
  }

  @override
  void initState() {
    if (widget.backgroundImage != null) {
      print("image!.height");
      // print(image!.width);
      init();
    }
    widget.controller?._delegate = _WhiteBoardControllerDelegate()
      ..saveAsImage = _convertToImage
      ..onUndo = () {
        if (_undoHistory.isEmpty) return false;

        _redoStack.add(_undoHistory.removeLast()..undo());
        widget.onRedoUndo?.call(_undoHistory.isNotEmpty, _redoStack.isNotEmpty);
        return true;
      }
      ..onRedo = () {
        if (_redoStack.isEmpty) return false;

        _undoHistory.add(_redoStack.removeLast()..redo());
        widget.onRedoUndo?.call(_undoHistory.isNotEmpty, _redoStack.isNotEmpty);
        return true;
      }
      ..checkAnyChangesMake = () {
        print(_undoHistory.length);
        print(_redoStack.length);
        if (_undoHistory.isEmpty) return false;
        return true;
      }
      ..onClear = () {
        if (_strokes.isEmpty) return;
        setState(() {
          final _removedStrokes = <_Stroke>[]..addAll(_strokes);
          _undoHistory.add(
            RedoUndoHistory(
              undo: () {
                setState(() => _strokes.addAll(_removedStrokes));
              },
              redo: () {
                setState(() => _strokes.clear());
              },
            ),
          );
          setState(() {
            _strokes.clear();
            _redoStack.clear();
          });
        });
        widget.onRedoUndo?.call(_undoHistory.isNotEmpty, _redoStack.isNotEmpty);
      };
    super.initState();
  }

  void _start(double startX, double startY) {
    final newStroke = _Stroke(
      color: widget.strokeColor,
      width: widget.strokeWidth,
      erase: widget.isErasing,
    );
    newStroke.path.moveTo(startX, startY);

    _strokes.add(newStroke);
    _undoHistory.add(
      RedoUndoHistory(
        undo: () {
          setState(() => _strokes.remove(newStroke));
        },
        redo: () {
          setState(() => _strokes.add(newStroke));
        },
      ),
    );
    _redoStack.clear();
    widget.onRedoUndo?.call(_undoHistory.isNotEmpty, _redoStack.isNotEmpty);
  }

  void _add(double x, double y) {
    setState(() {
      _strokes.last.path.lineTo(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    return isImageLoaded || widget.backgroundImage == null
        ? Container(
            height: widget.screenSize.height,
            width: widget.screenSize.width,
            child: GestureDetector(
              onPanStart: (details) => _start(
                details.localPosition.dx,
                details.localPosition.dy,
              ),
              onPanUpdate: (details) {
                _add(
                  details.localPosition.dx,
                  details.localPosition.dy,
                );
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _canvasSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return CustomPaint(
                    painter: _FreehandPainter(
                        _strokes, widget.backgroundColor, image),
                  );
                },
              ),
            ),
          )
        : Center(
            child: CircularProgressIndicator(),
          );
  }
}
