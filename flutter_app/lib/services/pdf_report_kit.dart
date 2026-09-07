import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ============================================================
/// SHARED PDF REPORT STYLING — iLOGIC TECH
/// Mirrors AppColors in app_theme.dart so every exported PDF
/// (invoices, voucher/team reports, etc.) looks like it belongs
/// to the same app: soft lavender tints instead of solid loud
/// colors, one consistent header with the brand mark, and one
/// consistent table look everywhere.
/// ============================================================
class PdfBrand {
  static const primary = PdfColor.fromInt(0xFF6C1FB0);
  static const primaryDark = PdfColor.fromInt(0xFF3D0F8C);
  static const primaryLight = PdfColor.fromInt(0xFF9A22C7);
  static const magenta = PdfColor.fromInt(0xFFE0189E);

  /// Mild, mostly-white tints — used for table header bands and
  /// info boxes instead of solid/loud fills.
  static const tint = PdfColor.fromInt(0xFFEDE9FE);
  static const tintStrong = PdfColor.fromInt(0xFFF2E6FB);
  static const surfaceAlt = PdfColor.fromInt(0xFFFCF7FF);

  static const textDark = PdfColor.fromInt(0xFF1F1533);
  static const textMuted = PdfColor.fromInt(0xFF6B6280);
  static const borderSoft = PdfColor.fromInt(0xFFE4D9F7);

  /// Status accents — mirrors AppColors.green / AppColors.orange in
  /// app_theme.dart so a "Paid" / "Pending" label in a PDF matches
  /// the same color used for that status inside the app.
  static const green = PdfColor.fromInt(0xFF15803D);
  static const orange = PdfColor.fromInt(0xFFD97706);
}

pw.MemoryImage? _brandLogoCache;

/// Loads the iLOGIC TECH brand mark once per session and reuses it
/// for every report generated afterwards.
Future<pw.MemoryImage> loadBrandLogo() async {
  final cached = _brandLogoCache;
  if (cached != null) return cached;
  final bytes = await rootBundle.load('assets/ilogictech_icon.png');
  final image = pw.MemoryImage(bytes.buffer.asUint8List());
  _brandLogoCache = image;
  return image;
}

/// Standard branded header for every exported report/invoice:
/// logo mark + title/subtitle on the left, an optional document
/// number and date on the right, with a soft brand rule beneath.
pw.Widget pdfReportHeader({
  required pw.MemoryImage logo,
  required String title,
  String? subtitle,
  String? docNumber,
  String? docDate,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 32,
                height: 32,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: PdfBrand.tint,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfBrand.textDark,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      subtitle,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfBrand.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if ((docNumber ?? '').isNotEmpty || (docDate ?? '').isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if ((docNumber ?? '').isNotEmpty)
                  pw.Text(
                    docNumber!,
                    style: pw.TextStyle(
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfBrand.textDark,
                    ),
                  ),
                if ((docDate ?? '').isNotEmpty)
                  pw.Text(
                    docDate!,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfBrand.textMuted,
                    ),
                  ),
              ],
            ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, color: PdfBrand.primaryLight),
    ],
  );
}

/// Mild table header text style shared by every report table —
/// bold brand-purple text (instead of white-on-solid-color) so
/// headers read clearly without shouting.
pw.TextStyle pdfTableHeaderStyle({double fontSize = 9}) => pw.TextStyle(
  fontWeight: pw.FontWeight.bold,
  fontSize: fontSize,
  color: PdfBrand.primaryDark,
);

/// Mild table header background — a soft lavender tint that
/// matches the app's card/chip fills instead of a loud solid color.
const pw.BoxDecoration pdfTableHeaderDecoration = pw.BoxDecoration(
  color: PdfBrand.tint,
);

/// Thin, soft row divider used between table rows.
const pw.BoxDecoration pdfTableRowDecoration = pw.BoxDecoration(
  border: pw.Border(
    bottom: pw.BorderSide(color: PdfBrand.borderSoft, width: 0.6),
  ),
);

/// Very light banding for alternate rows — keeps long tables easy
/// to scan without adding another loud color.
const pw.BoxDecoration pdfTableOddRowDecoration = pw.BoxDecoration(
  color: PdfBrand.surfaceAlt,
);
