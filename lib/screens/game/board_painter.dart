// Widget này thay thế cho GridView cũ
import 'package:flutter/material.dart';

class BigBoardWidget extends StatelessWidget {
  final int boardSize;
  final double cellSize;
  final Map<String, String> boardData;
  final Function(int, int) onTap;

  const BigBoardWidget({
    Key? key,
    required this.boardSize,
    required this.cellSize,
    required this.boardData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double totalSize = boardSize * cellSize;

    return GestureDetector(
      onTapUp: (details) {
        // Tính toán tọa độ khi chạm vào Canvas
        // localPosition trả về tọa độ pixel (VD: 500.5, 200.0)
        // Chia cho cellSize sẽ ra index dòng và cột
        int x = (details.localPosition.dx / cellSize).floor();
        int y = (details.localPosition.dy / cellSize).floor();

        if (x >= 0 && x < boardSize && y >= 0 && y < boardSize) {
          onTap(x, y);
        }
      },
      child: CustomPaint(
        size: Size(totalSize, totalSize),
        // Dùng RepaintBoundary để cache lại hình ảnh, giúp zoom mượt hơn
        isComplex: true, 
        willChange: false,
        painter: _BoardPainter(
          boardSize: boardSize,
          cellSize: cellSize,
          boardData: boardData,
        ),
      ),
    );
  }
}

// Class chịu trách nhiệm vẽ (Họa sĩ)
class _BoardPainter extends CustomPainter {
  final int boardSize;
  final double cellSize;
  final Map<String, String> boardData;

  _BoardPainter({
    required this.boardSize,
    required this.cellSize,
    required this.boardData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Vẽ nền
    final Paint bgPaint = Paint()..color = const Color(0xFF252540);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Vẽ lưới (Grid Lines)
    final Paint linePaint = Paint()
      ..color = Colors.white24 // Màu line mờ
      ..strokeWidth = 1.0;

    // Vẽ đường dọc
    for (int i = 0; i <= boardSize; i++) {
      double x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // Vẽ đường ngang
    for (int i = 0; i <= boardSize; i++) {
      double y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 3. Vẽ X và O
    final Paint xPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Paint oPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke; // Vẽ nét rỗng

    boardData.forEach((key, value) {
      // key dạng "x,y" -> Parse ra
      final parts = key.split(',');
      if (parts.length == 2) {
        int x = int.parse(parts[0]);
        int y = int.parse(parts[1]);

        // Tính tâm của ô
        double centerX = x * cellSize + cellSize / 2;
        double centerY = y * cellSize + cellSize / 2;
        double offset = cellSize * 0.25; // Khoảng cách từ tâm ra cạnh icon

        if (value == "X") {
          // Vẽ dấu X (2 đường chéo)
          canvas.drawLine(
            Offset(centerX - offset, centerY - offset),
            Offset(centerX + offset, centerY + offset),
            xPaint,
          );
          canvas.drawLine(
            Offset(centerX + offset, centerY - offset),
            Offset(centerX - offset, centerY + offset),
            xPaint,
          );
        } else if (value == "O") {
          // Vẽ dấu O (Hình tròn)
          canvas.drawCircle(Offset(centerX, centerY), offset, oPaint);
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    // Chỉ vẽ lại khi dữ liệu bàn cờ thay đổi
    return oldDelegate.boardData != boardData;
  }
}