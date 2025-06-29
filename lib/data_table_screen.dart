import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:view_selector_example2/constants.dart';
import 'package:view_selector_example2/doc.dart';
import 'package:view_selector_example2/main.dart';

class DataTableScreen extends StatefulWidget {
  final List<Map<String, dynamic>> dataRows;
  final ContactModel? firstItem;
  final String? FromDate;
  final String? ToDate;

  const DataTableScreen({
    super.key,
    required this.dataRows,
    required this.firstItem,
    required this.FromDate,
    required this.ToDate,
  });

  @override
  _DataTableScreenState createState() => _DataTableScreenState();
}

class _DataTableScreenState extends State<DataTableScreen> {
  bool _isLoading = false;
  String? _bsnToken;

  // Helper function to load SVG header
  Future<String> _loadSvgHeader() async {
    try {
      final svgData = await rootBundle.loadString('assets/header.svg');
      return svgData;
    } catch (e) {
      print("Error loading SVG header: $e");
      return ''; // Return empty string if SVG fails to load
    }
  }

  // FIXED: Use Noto Naskh Arabic font from Google Fonts
  Future<pw.Font> _loadArabicFont() async {
    try {
      // Try Noto Naskh Arabic first
      print("Loading Noto Naskh Arabic font from Google Fonts...");
      final naskh = await PdfGoogleFonts.notoNaskhArabicRegular();
      print("Noto Naskh Arabic font loaded successfully");
      return naskh;
    } catch (e) {
      print("Noto Naskh Arabic failed, trying other fonts: $e");
      try {
        // Fallback to Noto Sans Arabic
        final notoFont = await PdfGoogleFonts.notoSansArabicRegular();
        print("Noto Sans Arabic font loaded successfully");
        return notoFont;
      } catch (e2) {
        print("Google Fonts failed, trying local font: $e2");
        try {
          // Last resort - local font
          final fontData =
              await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
          final font = pw.Font.ttf(fontData);
          print("Local font loaded successfully");
          return font;
        } catch (e3) {
          print("All font loading failed: $e3");
          throw Exception('Could not load any Arabic font. Error: $e3');
        }
      }
    }
  }

  // FIXED: Use Noto Naskh Arabic font from Google Fonts
  Future<pw.Font> _loadBoldArabicFont() async {
    try {
      // Try Noto Naskh Arabic first
      print("Loading Noto Naskh Arabic font from Google Fonts...");
      final naskh = await PdfGoogleFonts.notoNaskhArabicBold();
      print("Noto Naskh Arabic font loaded successfully");
      return naskh;
    } catch (e) {
      print("Noto Naskh Arabic failed, trying other fonts: $e");
      try {
        // Fallback to Noto Sans Arabic
        final notoFont = await PdfGoogleFonts.notoSansArabicBold();
        print("Noto Sans Arabic font loaded successfully");
        return notoFont;
      } catch (e2) {
        print("Google Fonts failed, trying local font: $e2");
        try {
          // Last resort - local font
          final fontData =
              await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
          final font = pw.Font.ttf(fontData);
          print("Local font loaded successfully");
          return font;
        } catch (e3) {
          print("All font loading failed: $e3");
          throw Exception('Could not load any Arabic font. Error: $e3');
        }
      }
    }
  }

  // Helper function to clean Arabic text and ensure proper encoding
  String _cleanArabicText(String text) {
    if (text.isEmpty) return text;

    // Remove any problematic characters and ensure proper encoding
    String cleaned = text
        .replaceAll('�', '') // Remove replacement characters
        .replaceAll('\uFFFD', '') // Remove Unicode replacement character
        .trim();

    // Ensure proper Arabic text direction markers are not causing issues
    cleaned = cleaned
        .replaceAll('\u200E', '') // Remove left-to-right mark
        .replaceAll('\u200F', '') // Remove right-to-left mark
        .replaceAll('\u202A', '') // Remove left-to-right embedding
        .replaceAll('\u202B', '') // Remove right-to-left embedding
        .replaceAll('\u202C', '') // Remove pop directional formatting
        .replaceAll('\u202D', '') // Remove left-to-right override
        .replaceAll('\u202E', ''); // Remove right-to-left override

    return cleaned;
  }

  // FIXED PDF generation with correct dynamic data and proper columns
  Future<void> _generatePDF(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("Starting PDF generation...");

      // Load Noto Naskh Arabic font
      final arabicFont = await _loadArabicFont();
      final arabicBoldFont = await _loadBoldArabicFont();

      // Load SVG header
      final svgHeader = await _loadSvgHeader();

      print("Fonts and SVG loaded, creating PDF...");

      // Create PDF document
      final pdf = pw.Document();

      // Calculate totals from REAL DATA
      double allDebit = 0.00;
      double allCredit = 0.00;
      double balance = 0.00;

      for (var row in widget.dataRows) {
        allDebit += double.tryParse(
                (row['debit'] ?? '0').toString().replaceAll(',', '')) ??
            0;
        allCredit += double.tryParse(
                (row['credit'] ?? '0').toString().replaceAll(',', '')) ??
            0;
      }

      if (widget.dataRows.isNotEmpty) {
        balance = double.tryParse(
                (widget.dataRows.last['runningBalance'] ?? '0')
                    .toString()
                    .replaceAll(',', '')) ??
            0;
      }

      // Create page with exact layout matching the image but with REAL DATA
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15), // Reduced margin
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // SVG Header - 90% width, centered with 5% margin on each side
                if (svgHeader.isNotEmpty) ...[
                  pw.Container(
                    width: double.infinity,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width:
                              PdfPageFormat.a4.width * 0.9, // 90% of page width
                          child: pw.SvgImage(
                            svg: svgHeader,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Header matching the image exactly with REAL DATA
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Main title with REAL customer name
                      pw.Text(
                        'كشف حساب - ${_cleanArabicText(widget.firstItem?.nameAR ?? '')}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          font: arabicBoldFont,
                        ),
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),

                      // Right side - License number (keep as is for business header)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'مستقل مرخص',
                            style: pw.TextStyle(
                              fontSize: 10,
                              font: arabicBoldFont,
                            ),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            '562495317',
                            style: pw.TextStyle(
                              fontSize: 10,
                              font: arabicBoldFont,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 12),

                // Customer info box with REAL DATA and دليل as separated header (50% width)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width:
                          200, // About 50% of page width (A4 width ~595pts, so 200pts ≈ 35%)
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // دليل as separated header with border
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                    color: PdfColors.black, width: 1),
                              ),
                            ),
                            child: pw.Text(
                              'دليل ${_cleanArabicText(widget.firstItem?.code ?? '')}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                font: arabicBoldFont,
                              ),
                              textDirection: pw.TextDirection.rtl,
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          // REAL customer data section
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text(
                                  _cleanArabicText(
                                      widget.firstItem?.nameAR ?? ''),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    font: arabicBoldFont,
                                  ),
                                  textDirection: pw.TextDirection.rtl,
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  _cleanArabicText(
                                      widget.firstItem?.streetAddress ?? ''),
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    font: arabicFont,
                                  ),
                                  textDirection: pw.TextDirection.rtl,
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'رقم الضريبة ${_cleanArabicText(widget.firstItem?.taxId ?? '')}',
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    font: arabicFont,
                                  ),
                                  textDirection: pw.TextDirection.rtl,
                                ),
                                pw.SizedBox(height: 2),
                                // Phone number with LTR direction for the number part
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.end,
                                  children: [
                                    pw.Text(
                                      _cleanArabicText(
                                          widget.firstItem?.phone ?? ''),
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        font: arabicFont,
                                      ),
                                      textDirection: pw.TextDirection
                                          .ltr, // LTR for phone number
                                    ),
                                    pw.SizedBox(width: 5),
                                    pw.Text(
                                      'تلفون',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        font: arabicFont,
                                      ),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // Period and currency info with REAL DATA
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side - empty for now
                    pw.SizedBox(width: 100),

                    // Right side - period info with REAL dates
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'فترة   ${_cleanArabicText(widget.ToDate ?? '')} - ${_cleanArabicText(widget.FromDate ?? '')}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            font: arabicBoldFont,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          'عملة   :01 شيكل جديد',
                          style: pw.TextStyle(
                            fontSize: 10,
                            font: arabicBoldFont,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          'فرع   default :00',
                          style: pw.TextStyle(
                            fontSize: 10,
                            font: arabicBoldFont,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                        pw.Text(
                          'الحالة   مرحل',
                          style: pw.TextStyle(
                            fontSize: 10,
                            font: arabicBoldFont,
                          ),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 12),

                // Table with ONLY 6 columns (removed حساب رقم | عملية رقم) and REAL DATA
                pw.Expanded(
                  child: pw.Table(
                    border:
                        pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3), // ملاحظات السند
                      1: const pw.FlexColumnWidth(2), // الرصيد الجاري
                      2: const pw.FlexColumnWidth(1.5), // دائن
                      3: const pw.FlexColumnWidth(1.5), // مدين
                      4: const pw.FlexColumnWidth(3), // مستند
                      5: const pw.FlexColumnWidth(1.5), // تاريخ
                    },
                    children: [
                      // Header row with WHITE background and BOLD text
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.white),
                        children: [
                          _buildCompactTableCell(
                              'ملاحظات السند', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell(
                              'الرصيد\nالجاري', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('دائن', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('مدين', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('مستند', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('تاريخ', arabicBoldFont,
                              isHeader: true),
                        ],
                      ),

                      // Data rows with REAL DATA from HTTP requests
                      ...widget.dataRows.map((row) => pw.TableRow(
                            children: [
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${row['docComment'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${row['runningBalance'] ?? '0.00'}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${row['credit'] ?? '0.00'}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['debit'] ?? '0.00'}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${row['shownParent'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['docDate'] ?? ''}'),
                                  arabicFont),
                            ],
                          )),

                      // Total row with REAL calculated totals
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(),
                        children: [
                          _buildCompactTableCell('', arabicBoldFont),
                          _buildCompactTableCell(
                              '${balance.toStringAsFixed(2)}', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell(
                              '${allCredit.toStringAsFixed(2)}', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell(
                              '${allDebit.toStringAsFixed(2)}', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('المجموع', arabicBoldFont,
                              isHeader: true),
                          _buildCompactTableCell('', arabicBoldFont),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      print("PDF created, saving file...");

      // Save and open PDF with REAL customer name
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'كشف حساب - ${_cleanArabicText(widget.firstItem?.nameAR?.replaceAll('/', '-') ?? '')}';
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());

      print("PDF saved successfully: ${file.path}");

      // Open the PDF
      await OpenFile.open(file.path);
    } catch (e) {
      print("Error generating PDF: $e");
      _showErrorDialog('خطأ في توليد ملف PDF: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // FIXED: Simple PDF generation for individual documents with REAL DATA
  Future<void> _generateSimpleDocumentPDF(String docType, String docNumber,
      List<Map<String, dynamic>> docData, String comment) async {
    try {
      print("Starting simple document PDF generation...");

      // Load Noto Naskh Arabic font
      final arabicFont = await _loadArabicFont();

      // Load SVG header
      final svgHeader = await _loadSvgHeader();

      print("Font and SVG loaded, creating document PDF...");

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // SVG Header - 90% width, centered with 5% margin on each side
                if (svgHeader.isNotEmpty) ...[
                  pw.Container(
                    width: double.infinity,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Container(
                          width:
                              PdfPageFormat.a4.width * 0.9, // 90% of page width
                          child: pw.SvgImage(
                            svg: svgHeader,
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],

                // Header with REAL document info
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${_cleanArabicText(docType)}: ${_cleanArabicText(docNumber)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      font: arabicFont,
                    ),
                    textDirection: pw.TextDirection.rtl,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Customer info with REAL DATA
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'الرقم: ${_cleanArabicText(widget.firstItem?.code ?? '')}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: arabicFont,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'الاسم: ${_cleanArabicText(widget.firstItem?.nameAR ?? '')}',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'العنوان: ${_cleanArabicText(widget.firstItem?.streetAddress ?? '')}',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'رقم الضريبة: ${_cleanArabicText(widget.firstItem?.taxId ?? '')}',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'تلفون: ${_cleanArabicText(widget.firstItem?.phone ?? '')}',
                        style: pw.TextStyle(
                          font: arabicFont,
                          fontSize: 11,
                        ),
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Document data table with REAL DATA from HTTP request
                if (docData.isNotEmpty) ...[
                  pw.Table(
                    border:
                        pw.TableBorder.all(width: 0.5, color: PdfColors.black),
                    children: [
                      // Headers based on document type
                      if (docType.contains('فاتورة') ||
                          docType.contains('مرتجع')) ...[
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.white),
                          children: [
                            _buildCompactTableCell('#', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('صنف', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('بيان', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('كمية', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('سعر', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('مجموع', arabicFont,
                                isHeader: true),
                          ],
                        ),
                        // Data rows with REAL DATA
                        ...docData.asMap().entries.map((entry) {
                          int index = entry.key + 1;
                          var row = entry.value;
                          return pw.TableRow(
                            children: [
                              _buildCompactTableCell('$index', arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['item'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['name'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${row['quantity'] ?? ''} ${row['unit'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['price'] ?? ''}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText('${row['amount'] ?? ''}'),
                                  arabicFont),
                            ],
                          );
                        }).toList(),
                      ] else if (docType.contains('قبض')) ...[
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.white),
                          children: [
                            _buildCompactTableCell('#', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('طريقة الدفع', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('رقم', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('التاريخ', arabicFont,
                                isHeader: true),
                            _buildCompactTableCell('القيمة', arabicFont,
                                isHeader: true),
                          ],
                        ),
                        if (docData.isNotEmpty)
                          pw.TableRow(
                            children: [
                              _buildCompactTableCell('1', arabicFont),
                              _buildCompactTableCell(
                                  docData[0]['check'] == '' ? 'كاش' : 'شيكات',
                                  arabicFont),
                              _buildCompactTableCell(
                                  docData[0]['check'] == ''
                                      ? '-'
                                      : _cleanArabicText(
                                          '${docData[0]["check.checkNumber"] ?? ""}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  docData[0]['check'] == ''
                                      ? '-'
                                      : _cleanArabicText(
                                          '${docData[0]["check.dueDate"] ?? ""}'),
                                  arabicFont),
                              _buildCompactTableCell(
                                  _cleanArabicText(
                                      '${docData[0]['credit'] ?? ""}'),
                                  arabicFont),
                            ],
                          ),
                      ],
                    ],
                  ),
                  pw.SizedBox(height: 10),
                ],

                // Comment section with REAL comment data
                if (comment.isNotEmpty) ...[
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'ملاحظة: ${_cleanArabicText(comment)}',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );

      print("Document PDF created, saving file...");

      // Save and open PDF
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${_cleanArabicText(docType)} ${_cleanArabicText(docNumber)}'
              .replaceAll('/', '-');
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());

      print("Document PDF saved successfully: ${file.path}");

      // Open the PDF
      await OpenFile.open(file.path);
    } catch (e) {
      print("Error generating document PDF: $e");
      _showErrorDialog('خطأ في توليد ملف PDF: $e');
    }
  }

  // Compact table cell builder to match the image exactly
  pw.Widget _buildCompactTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.all(2), // Very minimal padding like the image
      child: pw.Text(
        _cleanArabicText(text),
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 9 : 8, // Smaller font sizes to match image
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  Widget _buildLoader() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خطأ', textAlign: TextAlign.right),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'حسناً',
              style: TextStyle(color: KPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchToken() async {
    const tokenUrl =
        'https://script.google.com/macros/s/AKfycby7q0QHLM9YZ8zCOGpgQGXtSPSTdtWrXJe_v5Nls1tYG2NZAws-ezDZ1U9Q1XA-sa25/exec';

    try {
      final response = await http.get(Uri.parse(tokenUrl));
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['data'] != null &&
            responseData['data'] is List &&
            responseData['data'].isNotEmpty) {
          setState(() {
            _bsnToken = responseData['data'][1]['token'];
          });
        } else {
          _showErrorDialog(
              'تعذر الحصول على رمز التوثيق.${responseData['data'][1]['token']}');
        }
      } else {
        _showErrorDialog('خطأ في جلب رمز التوثيق: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء جلب رمز التوثيق.$e');
    }
  }

  void _handleSubmit(String doc, String date, String comment) async {
    final guideNumber = widget.firstItem?.code;
    final theDate = date;
    List<Map<String, dynamic>> dataRows = [];

    setState(() {
      _isLoading = true;
    });

    await _fetchToken();
    if (_bsnToken == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatementDetail.json?search=fromDate:$theDate,toDate:$theDate,reference:$guideNumber,includeCashMov:true,priceIncludeTax:true,showCashInfo:true,showItemInfo:true,selectAll:true,lg_status:مرحل';

    final headers = {'BSN-token': _bsnToken!};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final responseData = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(responseData);

        if (jsonData['rows'] != null) {
          final filteredRows = List<Map<String, dynamic>>.from(jsonData['rows'])
              .where((row) => row['shownParent'] == doc)
              .toList();

          setState(() {
            dataRows = filteredRows;
          });

          String docType = '';
          String result = '';

          if (doc.contains('ف.مبيعات') || doc.contains('ف.يدوية')) {
            docType = 'فاتورة';
            result = doc.contains('ف.مبيعات')
                ? doc.replaceAll("ف.مبيعات", "").trim()
                : doc.replaceAll("ف.يدوية", "").trim();
          } else if (doc.contains('م. مبيعات') || doc.contains('م.مبيعات')) {
            docType = 'مرتجع مبيعات';
            result = doc.contains('م.مبيعات')
                ? doc.replaceAll("م.مبيعات", "").trim()
                : doc.replaceAll("م. مبيعات", "").trim();
          } else if (doc.contains('قبض يدوي') || doc.contains('قبض')) {
            docType = 'قبض';
            result = doc.contains('قبض يدوي')
                ? doc.replaceAll("قبض يدوي", "").trim()
                : doc.replaceAll("قبض", "").trim();
          }

          await _generateSimpleDocumentPDF(docType, result, dataRows, comment);
        }
      } else {
        _showErrorDialog(
            'خطأ في الاتصال بالخادم. رمز الخطأ: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء الاتصال بالخادم.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleInfo(String doc, String date, String comment) async {
    final guideNumber = widget.firstItem?.code;
    final theDate = date;
    List<Map<String, dynamic>> dataRows = [];

    setState(() {
      _isLoading = true;
    });

    await _fetchToken();
    if (_bsnToken == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url =
        'https://gw.bisan.com/api/v2/jalaf/REPORT/customerStatementDetail.json?search=fromDate:$theDate,toDate:$theDate,reference:$guideNumber,includeCashMov:true,priceIncludeTax:true,showCashInfo:true,showItemInfo:true,selectAll:true,lg_status:مرحل';

    final headers = {'BSN-token': _bsnToken!};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final responseData = utf8.decode(response.bodyBytes);
        final jsonData = json.decode(responseData);

        if (jsonData['rows'] != null) {
          final filteredRows = List<Map<String, dynamic>>.from(jsonData['rows'])
              .where((row) => row['shownParent'] == doc)
              .toList();

          setState(() {
            dataRows = filteredRows;
          });

          String fileName = '';
          if (doc.contains('ف.مبيعات') || doc.contains('ف.يدوية')) {
            String result = doc.contains('ف.مبيعات')
                ? doc.replaceAll("ف.مبيعات", "").trim()
                : doc.replaceAll("ف.يدوية", "").trim();
            fileName = 'فاتورة ${result.replaceAll('/', '-')}';
          } else if (doc.contains('م. مبيعات') || doc.contains('م.مبيعات')) {
            String result = doc.contains('م.مبيعات')
                ? doc.replaceAll("م.مبيعات", "").trim()
                : doc.replaceAll("م. مبيعات", "").trim();
            fileName = 'مرتجع مبيعات ${result.replaceAll('/', '-')}';
          } else if (doc.contains('قبض يدوي') || doc.contains('قبض')) {
            String result = doc.contains('قبض يدوي')
                ? doc.replaceAll("قبض يدوي", "").trim()
                : doc.replaceAll("قبض", "").trim();
            fileName = 'قبض ${result.replaceAll('/', '-')}';
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocScreen(
                dataRows: dataRows,
                firstItem: widget.firstItem,
                FromDate: widget.FromDate,
                ToDate: widget.ToDate,
                htmlData: null,
                doc: doc,
                fileName: fileName,
              ),
            ),
          );
        }
      } else {
        _showErrorDialog(
            'خطأ في الاتصال بالخادم. رمز الخطأ: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء الاتصال بالخادم.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getDocumentType(String document) {
    if (document.contains('ف.مبيعات')) return 'فاتورة';
    if (document.contains('م.مبيعات')) return 'مرتجع';
    if (document.contains('قبض')) return 'قبض';
    return 'مستند';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text('${widget.firstItem?.code} - ${widget.firstItem?.nameAR}')),
      body: Stack(
        children: [
          // Scrollable content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120.0),
              child: Column(
                children: widget.dataRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header section with date and document number
                          Container(
                            decoration: const BoxDecoration(
                              color: KPrimaryColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 16,
                                            color: Colors.white70,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            row['docDate'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        row['shownParent'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Document type indicator/badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getDocumentType(row['shownParent'] ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Content section with amounts and actions
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Amounts section
                                Expanded(
                                  flex: 7,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.arrow_upward_rounded,
                                                color: Colors.blue,
                                                size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            row['debit'] != ''
                                                ? 'مدين: ${row['debit']}'
                                                : 'مدين: 0.00',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.green.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                                Icons.arrow_downward_rounded,
                                                color: Colors.green,
                                                size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            row['credit'] != ''
                                                ? 'دائن: ${row['credit']}'
                                                : 'دائن: 0.00',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Text(
                                            'الرصيد:',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            row['runningBalance'] ?? '0.00',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: KPrimaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions section
                                if (!row['shownParent']
                                        .toString()
                                        .contains('رصيد مدور') &&
                                    !row['shownParent']
                                        .toString()
                                        .contains('إشعارات') &&
                                    !row['shownParent']
                                        .toString()
                                        .contains('قيد'))
                                  Column(
                                    children: [
                                      // Print button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: KPrimaryColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            DateTime parsedDate =
                                                DateFormat('dd/MM/yyyy')
                                                    .parse(row['docDate']);
                                            String formattedDate =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(parsedDate);
                                            _handleSubmit(
                                                row['shownParent'],
                                                formattedDate,
                                                row['docComment']);
                                          },
                                          icon: const Icon(
                                            Icons.print_rounded,
                                            color: KPrimaryColor,
                                            size: 24,
                                          ),
                                          tooltip: 'طباعة',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Info button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: IconButton(
                                          onPressed: () {
                                            DateTime parsedDate =
                                                DateFormat('dd/MM/yyyy')
                                                    .parse(row['docDate']);
                                            String formattedDate =
                                                DateFormat('yyyy-MM-dd')
                                                    .format(parsedDate);
                                            _handleInfo(
                                                row['shownParent'],
                                                formattedDate,
                                                row['docComment']);
                                          },
                                          icon: const Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.grey,
                                            size: 24,
                                          ),
                                          tooltip: 'معلومات',
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          // Optional comment section if available
                          if (row['docComment'] != null &&
                              row['docComment'].toString().isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.shade200,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.comment_outlined,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      row['docComment'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Fixed Button at the bottom of the screen
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KPrimaryColor,
                ),
                onPressed: () => _generatePDF(context),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'طباعة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Show loader if _isLoading is true
          if (_isLoading) _buildLoader(),
        ],
      ),
    );
  }
}
