import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:view_selector_example2/constants.dart';
import 'package:view_selector_example2/main.dart';

class DocScreen extends StatefulWidget {
  final List<Map<String, dynamic>> dataRows;
  final ContactModel? firstItem;
  final String? FromDate;
  final String? ToDate;
  final String? htmlData; // Keep for backward compatibility but won't be used
  final String? doc;
  final String? fileName;

  const DocScreen({
    super.key,
    required this.dataRows,
    required this.firstItem,
    required this.FromDate,
    required this.ToDate,
    required this.htmlData,
    required this.doc,
    required this.fileName,
  });

  @override
  _DocScreenState createState() => _DocScreenState();
}

class _DocScreenState extends State<DocScreen> {
  int index = 0;
  double total = 0.00;
  bool _isLoading = false;

  // UPDATED: Use Noto Naskh Arabic font from Google Fonts for better Arabic typography
  Future<pw.Font> _loadArabicFont() async {
    try {
      // Try Noto Naskh Arabic first - beautiful traditional Arabic calligraphy
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

  // UPDATED: Use Noto Naskh Arabic BOLD font from Google Fonts
  Future<pw.Font> _loadBoldArabicFont() async {
    try {
      // Try Noto Naskh Arabic Bold first
      print("Loading Noto Naskh Arabic Bold font from Google Fonts...");
      final naskh = await PdfGoogleFonts.notoNaskhArabicBold();
      print("Noto Naskh Arabic Bold font loaded successfully");
      return naskh;
    } catch (e) {
      print("Noto Naskh Arabic Bold failed, trying other fonts: $e");
      try {
        // Fallback to Noto Sans Arabic Bold
        final notoFont = await PdfGoogleFonts.notoSansArabicBold();
        print("Noto Sans Arabic Bold font loaded successfully");
        return notoFont;
      } catch (e2) {
        print("Google Fonts failed, trying local font: $e2");
        try {
          // Last resort - local font (regular as bold fallback)
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

  // Helper function to calculate rounding discount
  String _calculateRoundingDiscount() {
    double roundedTotal = total.roundToDouble();
    double discount = total - roundedTotal;
    return discount.toStringAsFixed(2);
  }

  // Helper function to get tax value
  String _getTaxValue() {
    if (widget.dataRows.isNotEmpty &&
        widget.dataRows.last["tax"] != null &&
        widget.dataRows.last["tax"] != '' &&
        widget.dataRows.last["tax"] != '0') {
      return _formatNumber(widget.dataRows.last["tax"].toString());
    }
    return '0.00';
  }

  // Helper function to calculate final net total (rounded total, not total + tax)
  String _calculateFinalNet() {
    double roundedTotal = total.roundToDouble();
    return roundedTotal
        .toStringAsFixed(0); // No decimal places for rounded total
  }

  // Helper function to calculate rounding discount for PDF
  String _calculateRoundingDiscountForPDF(double pdfTotal) {
    double roundedTotal = pdfTotal.roundToDouble();
    double discount = pdfTotal - roundedTotal;
    return discount.toStringAsFixed(2);
  }

  // Helper function to calculate final net total for PDF (rounded total, not total + tax)
  String _calculateFinalNetForPDF(double pdfTotal) {
    double roundedTotal = pdfTotal.roundToDouble();
    return roundedTotal
        .toStringAsFixed(0); // No decimal places for rounded total
  }

  // Compact summary cell builder for the summary table
  pw.Widget _buildCompactSummaryCell(String text, pw.Font font,
      {bool isLabel = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: (isLabel && text.contains('المجموع')) ||
                  (isLabel && text.contains('الصافي'))
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: isLabel ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
    );
  }

  // Helper function to format numbers properly (LTR direction)
  String _formatNumber(String value) {
    if (value.isEmpty || value == '0') return '0.00';

    try {
      double number = double.parse(value.replaceAll(',', ''));
      return number.toStringAsFixed(2);
    } catch (e) {
      return value;
    }
  }

  // Helper function to calculate net total
  String _calculateNetTotal() {
    if (widget.dataRows.isEmpty) return '0.00';

    double netTotal = total;

    // Subtract discount if exists
    if (widget.dataRows.last["docDiscount"] != null &&
        widget.dataRows.last["docDiscount"] != '' &&
        widget.dataRows.last["docDiscount"] != '0') {
      double discount = double.tryParse(widget.dataRows.last["docDiscount"]
              .toString()
              .replaceAll(',', '')) ??
          0;
      netTotal -= discount;
    }

    // Add tax if exists
    if (widget.dataRows.last["tax"] != null &&
        widget.dataRows.last["tax"] != '' &&
        widget.dataRows.last["tax"] != '0') {
      double tax = double.tryParse(
              widget.dataRows.last["tax"].toString().replaceAll(',', '')) ??
          0;
      netTotal += tax;
    }

    return netTotal.toStringAsFixed(2);
  }

  // Helper function to get document date from dataRows
  String _getDocumentDate() {
    if (widget.dataRows.isNotEmpty) {
      // Try to get date from first row or any row that has docDate
      for (var row in widget.dataRows) {
        if (row['docDate'] != null && row['docDate'].toString().isNotEmpty) {
          return row['docDate'].toString();
        }
      }
    }
    // Fallback to current date if no docDate found
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  // Helper function to get formatted document title with proper number encoding
  String _getFormattedDocumentTitle() {
    String docType = '';
    String docNumber = '';

    if (widget.doc!.contains('ف.مبيعات')) {
      docType = 'فاتورة ضريبية';
      docNumber = widget.doc!.replaceAll('ف.مبيعات', '').trim();
    } else if (widget.doc!.contains('ف.يدوية')) {
      docType = 'فاتورة يدوية';
      docNumber = widget.doc!.replaceAll('ف.يدوية', '').trim();
    } else if (widget.doc!.contains('م.مبيعات')) {
      docType = 'مرتجع مبيعات';
      docNumber = widget.doc!.replaceAll('م.مبيعات', '').trim();
    } else if (widget.doc!.contains('م. مبيعات')) {
      docType = 'مرتجع مبيعات';
      docNumber = widget.doc!.replaceAll('م. مبيعات', '').trim();
    } else if (widget.doc!.contains('قبض يدوي')) {
      docType = 'قبض';
      docNumber = widget.doc!.replaceAll('قبض يدوي', '').trim();
    } else if (widget.doc!.contains('قبض')) {
      docType = 'قبض';
      docNumber = widget.doc!.replaceAll('قبض', '').trim();
    }

    // Clean the document number to prevent encoding issues
    // Remove any non-ASCII characters that might cause display issues
    docNumber = docNumber.replaceAll(RegExp(r'[^\w\d\s/.-]'), '');

    // Additional cleanup for common problematic characters
    docNumber = docNumber
        .replaceAll('⌧', '')
        .replaceAll('�', '')
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'),
            '') // Remove control characters
        .trim();

    return '$docType $docNumber';
  }

  // Helper function to get current date in Arabic format
  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
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

  // UPDATED PDF generation with improved design matching كشف الحساب style
  Future<void> _generatePDF(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("Starting PDF generation...");

      // Calculate PDF total separately - don't use the shared total variable
      double pdfTotal = 0.0;
      for (var row in widget.dataRows) {
        double amount = double.tryParse(
                (row['amount'] ?? '0').toString().replaceAll(',', '')) ??
            0;
        pdfTotal += amount;
        print(
            "Row amount: ${row['amount']}, parsed: $amount, running total: $pdfTotal");
      }
      print("Final PDF Total calculated: $pdfTotal");
      print("Expected: 123.69 + 1010.12 = 1133.81");

      // Load both regular and bold Noto Naskh Arabic fonts
      final arabicFont = await _loadArabicFont();
      final arabicBoldFont = await _loadBoldArabicFont();

      // Load SVG header
      final svgHeader = await _loadSvgHeader();

      print("Fonts and SVG loaded, creating PDF...");

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15), // Reduced margin
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
                  pw.SizedBox(height: 12),
                ],

                // Header section - professional design matching the standard PDF
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Document title with proper number formatting (LTR for numbers)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          // Extract and format the document number properly
                          pw.Text(
                            _getFormattedDocumentTitle(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              font: arabicBoldFont,
                            ),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6), // Reduced spacing

                      // Date section - use document date
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'تاريخ ${_getDocumentDate()}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              font: arabicFont,
                            ),
                            textDirection: pw.TextDirection.rtl,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4), // Reduced spacing

                      // Business license info
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
                              font: arabicFont,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10), // Reduced spacing

                // Customer info section - professional design matching standard PDF
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250, // Wider for better readability
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // دليل header with better styling
                          pw.Container(
                            width: double.infinity,
                            padding: const pw.EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8), // Reduced padding
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey100,
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                    color: PdfColors.black, width: 1),
                              ),
                            ),
                            child: pw.Text(
                              'دليل ${_cleanArabicText(widget.firstItem?.code ?? '')}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                font: arabicBoldFont,
                              ),
                              textDirection: pw.TextDirection.rtl,
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          // Customer data with reduced spacing
                          pw.Container(
                            width: double.infinity,
                            padding:
                                const pw.EdgeInsets.all(8), // Reduced padding
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                // Customer name - bold and prominent
                                pw.Text(
                                  _cleanArabicText(
                                      widget.firstItem?.nameAR ?? ''),
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                    font: arabicBoldFont,
                                  ),
                                  textDirection: pw.TextDirection.rtl,
                                ),
                                pw.SizedBox(height: 3), // Reduced spacing
                                // Address
                                if (widget.firstItem?.streetAddress != null &&
                                    widget.firstItem!.streetAddress!.isNotEmpty)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                        bottom: 3), // Reduced spacing
                                    child: pw.Text(
                                      _cleanArabicText(
                                          widget.firstItem!.streetAddress!),
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        font: arabicFont,
                                      ),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ),
                                // Tax ID
                                if (widget.firstItem?.taxId != null &&
                                    widget.firstItem!.taxId!.isNotEmpty)
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                        bottom: 3), // Reduced spacing
                                    child: pw.Text(
                                      'رقم الضريبة: ${_cleanArabicText(widget.firstItem!.taxId!)}',
                                      style: pw.TextStyle(
                                        fontSize: 10,
                                        font: arabicFont,
                                      ),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ),
                                // Phone number with proper LTR formatting
                                if (widget.firstItem?.phone != null &&
                                    widget.firstItem!.phone!.isNotEmpty)
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.end,
                                    children: [
                                      pw.Text(
                                        _cleanArabicText(
                                            widget.firstItem!.phone!),
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          font: arabicFont,
                                        ),
                                        textDirection: pw.TextDirection.ltr,
                                      ),
                                      pw.SizedBox(width: 5),
                                      pw.Text(
                                        'تلفون:',
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
                pw.SizedBox(height: 15), // Reduced space before table

                // Table based on document type - RTL design matching the image
                if (widget.doc!.contains('ف.مبيعات') ||
                    widget.doc!.contains('ف.يدوية') ||
                    widget.doc!.contains('م.مبيعات') ||
                    widget.doc!.contains('م. مبيعات')) ...[
                  // Invoice/Return table - RTL design
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        // Main table - RTL column order
                        pw.Table(
                          border: pw.TableBorder.all(
                              width: 1, color: PdfColors.black),
                          columnWidths: {
                            // RTL order: مجموع، سعر، كمية، بيان، صنف، #
                            0: const pw.FlexColumnWidth(1.8), // مجموع
                            1: const pw.FlexColumnWidth(1.5), // سعر
                            2: const pw.FlexColumnWidth(1.5), // كمية
                            3: const pw.FlexColumnWidth(3.5), // بيان
                            4: const pw.FlexColumnWidth(1.8), // صنف
                            5: const pw.FlexColumnWidth(0.8), // #
                          },
                          children: [
                            // Header row - RTL order
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                  color: PdfColors.grey200),
                              children: [
                                _buildRTLTableCell('مجموع', arabicBoldFont,
                                    isHeader: true),
                                _buildRTLTableCell('سعر', arabicBoldFont,
                                    isHeader: true),
                                _buildRTLTableCell('كمية', arabicBoldFont,
                                    isHeader: true),
                                _buildRTLTableCell('بيان', arabicBoldFont,
                                    isHeader: true),
                                _buildRTLTableCell('صنف', arabicBoldFont,
                                    isHeader: true),
                                _buildRTLTableCell('#', arabicBoldFont,
                                    isHeader: true),
                              ],
                            ),
                            // Data rows - RTL order with correct total display (don't modify shared total)
                            ...widget.dataRows.asMap().entries.map((entry) {
                              int rowIndex = entry.key + 1;
                              var row = entry.value;
                              // Don't modify the shared total variable here

                              return pw.TableRow(
                                children: [
                                  _buildRTLTableCell(
                                      _formatNumber(row['amount'] ?? '0'),
                                      arabicFont),
                                  _buildRTLTableCell(
                                      _formatNumber(row['price'] ?? '0'),
                                      arabicFont),
                                  _buildRTLTableCell(
                                      _cleanArabicText(
                                          '${row['quantity'] ?? ''} ${row['unit'] ?? ''}'),
                                      arabicFont),
                                  _buildRTLTableCell(
                                      _cleanArabicText('${row['name'] ?? ''}'),
                                      arabicFont),
                                  _buildRTLTableCell(
                                      _cleanArabicText('${row['item'] ?? ''}'),
                                      arabicFont),
                                  _buildRTLTableCell('$rowIndex', arabicFont),
                                ],
                              );
                            }),
                          ],
                        ),

                        // Summary section - clean design with correct PDF calculations
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: double.infinity,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              // المجموع - use pdfTotal
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  border: pw.Border.all(
                                      width: 0.5, color: PdfColors.grey400),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      _formatNumber(pdfTotal.toString()),
                                      style: pw.TextStyle(
                                          font: arabicBoldFont, fontSize: 11),
                                      textDirection: pw.TextDirection.ltr,
                                    ),
                                    pw.Text(
                                      'المجموع',
                                      style: pw.TextStyle(
                                          font: arabicBoldFont, fontSize: 11),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),

                              // الخصم - use PDF calculation
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                      width: 0.5, color: PdfColors.grey400),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      _calculateRoundingDiscountForPDF(
                                          pdfTotal),
                                      style: pw.TextStyle(
                                          font: arabicFont, fontSize: 10),
                                      textDirection: pw.TextDirection.ltr,
                                    ),
                                    pw.Text(
                                      'الخصم',
                                      style: pw.TextStyle(
                                          font: arabicFont, fontSize: 10),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),

                              // ضريبة 16%
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                      width: 0.5, color: PdfColors.grey400),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      _getTaxValue(),
                                      style: pw.TextStyle(
                                          font: arabicFont, fontSize: 10),
                                      textDirection: pw.TextDirection.ltr,
                                    ),
                                    pw.Text(
                                      'ضريبة 16%',
                                      style: pw.TextStyle(
                                          font: arabicFont, fontSize: 10),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),

                              // الصافي - use PDF calculation
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey100,
                                  border: pw.Border.all(
                                      width: 0.5, color: PdfColors.grey400),
                                ),
                                child: pw.Row(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      _calculateFinalNetForPDF(pdfTotal),
                                      style: pw.TextStyle(
                                          font: arabicBoldFont, fontSize: 11),
                                      textDirection: pw.TextDirection.ltr,
                                    ),
                                    pw.Text(
                                      'الصافي',
                                      style: pw.TextStyle(
                                          font: arabicBoldFont, fontSize: 11),
                                      textDirection: pw.TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10), // Reduced space after table

                  // Terms and conditions with improved font
                  if (widget.doc!.contains('ف.مبيعات') ||
                      widget.doc!.contains('ف.يدوية'))
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Text(
                        'استلمت البضاعة المذكورة أعلاه سليمة و خالية من أي خلل أو عيب و التزم بتسديد قيمتها بعد الاستلام مباشرة',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            font: arabicBoldFont,
                            fontSize: 9),
                        textAlign: pw.TextAlign.center,
                        textDirection: pw.TextDirection.rtl,
                      ),
                    ),
                ] else if (widget.doc!.contains('قبض يدوي') ||
                    widget.doc!.contains('قبض')) ...[
                  // Receipt table - RTL design
                  pw.Table(
                    border:
                        pw.TableBorder.all(width: 1, color: PdfColors.black),
                    columnWidths: {
                      // RTL order: القيمة، التاريخ، رقم، طريقة الدفع، #
                      0: const pw.FlexColumnWidth(1.8), // القيمة
                      1: const pw.FlexColumnWidth(1.8), // التاريخ
                      2: const pw.FlexColumnWidth(1.8), // رقم
                      3: const pw.FlexColumnWidth(2.0), // طريقة الدفع
                      4: const pw.FlexColumnWidth(0.8), // #
                    },
                    children: [
                      // Header row - RTL order
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _buildRTLTableCell('القيمة', arabicBoldFont,
                              isHeader: true),
                          _buildRTLTableCell('التاريخ', arabicBoldFont,
                              isHeader: true),
                          _buildRTLTableCell('رقم', arabicBoldFont,
                              isHeader: true),
                          _buildRTLTableCell('طريقة الدفع', arabicBoldFont,
                              isHeader: true),
                          _buildRTLTableCell('#', arabicBoldFont,
                              isHeader: true),
                        ],
                      ),
                      // Data row - RTL order
                      if (widget.dataRows.isNotEmpty)
                        pw.TableRow(
                          children: [
                            _buildRTLTableCell(
                                _formatNumber(
                                    widget.dataRows[0]['credit'] ?? '0'),
                                arabicFont),
                            _buildRTLTableCell(
                                widget.dataRows[0]['check'] == ''
                                    ? '-'
                                    : _cleanArabicText(
                                        '${widget.dataRows[0]["check.dueDate"] ?? ""}'),
                                arabicFont),
                            _buildRTLTableCell(
                                widget.dataRows[0]['check'] == ''
                                    ? '-'
                                    : _cleanArabicText(
                                        '${widget.dataRows[0]["check.checkNumber"] ?? ""}'),
                                arabicFont),
                            _buildRTLTableCell(
                                widget.dataRows[0]['check'] == ''
                                    ? 'كاش'
                                    : 'شيكات',
                                arabicFont),
                            _buildRTLTableCell('1', arabicFont),
                          ],
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],

                // Signature section with improved spacing
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 100,
                          height: 1,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'الاسم',
                          style: pw.TextStyle(font: arabicFont, fontSize: 10),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 100,
                          height: 1,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'التوقيع',
                          style: pw.TextStyle(font: arabicFont, fontSize: 10),
                          textDirection: pw.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      print("PDF created, saving file...");

      // Save and open PDF
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${widget.fileName}.pdf');
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

  // Professional table cell builder for better design
  pw.Widget _buildProfessionalTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        _cleanArabicText(text),
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
      ),
    );
  }

  // UPDATED: RTL table cell builder with proper font usage
  pw.Widget _buildRTLTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6), // Better padding
      child: pw.Text(
        _cleanArabicText(text),
        style: pw.TextStyle(
          font: font, // Use the provided font (bold or regular)
          fontSize: isHeader ? 10 : 9, // Better font sizes
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl, // Ensure RTL direction
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

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? KPrimaryColor : Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset counters for display
    index = 0;
    total = 0.00;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.doc!.contains('ف.مبيعات') ? widget.doc?.replaceAll('ف.مبيعات', 'فاتورة مبيعات') : widget.doc!.contains('م.مبيعات') ? widget.doc?.replaceAll('م.مبيعات', 'مرتجع مبيعات') : widget.doc!.contains('م. مبيعات') ? widget.doc?.replaceAll('م. مبيعات', 'مرتجع مبيعات') : widget.doc!.contains('قبض يدوي') ? widget.doc?.replaceAll('قبض يدوي', 'قبض') : widget.doc!.contains('قبض') ? widget.doc?.replaceAll('قبض', 'قبض') : widget.doc!.contains('ف.يدوية') ? widget.doc?.replaceAll('ف.يدوية', 'فاتورة مبيعات يدوية') : ''}'),
      ),
      body: Stack(
        children: [
          // Invoice/Return table
          if (widget.doc!.contains('ف.مبيعات') ||
              widget.doc!.contains('ف.يدوية') ||
              widget.doc!.contains('م. مبيعات') ||
              widget.doc!.contains('م.مبيعات'))
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    right: 22, left: 22, top: 10, bottom: 120),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2),
                    4: FlexColumnWidth(2),
                    5: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(
                    color: Colors.grey,
                    width: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  children: [
                    // Table Header
                    TableRow(
                      decoration: BoxDecoration(
                        color: KPrimaryColor.withOpacity(0.1),
                      ),
                      children: [
                        _buildTableCell('#', isHeader: true),
                        _buildTableCell('صنف', isHeader: true),
                        _buildTableCell('بيان', isHeader: true),
                        _buildTableCell('كمية', isHeader: true),
                        _buildTableCell('سعر', isHeader: true),
                        _buildTableCell('مجموع', isHeader: true),
                      ],
                    ),
                    // Table Rows with REAL DATA - Fixed calculation
                    ...widget.dataRows.map((row) {
                      index++;
                      double amount = double.tryParse((row['amount'] ?? '0')
                              .toString()
                              .replaceAll(',', '')) ??
                          0;
                      total += amount;

                      return TableRow(
                        children: [
                          _buildTableCell(index.toString()),
                          _buildTableCell(row['item'] ?? ''),
                          _buildTableCell(row['name'] ?? ''),
                          _buildTableCell(
                              '${row['quantity'] ?? ''} ${row['unit'] ?? ''}'),
                          _buildTableCell(row['price'] ?? ''),
                          _buildTableCell(row['amount'] ?? ''),
                        ],
                      );
                    }),
                    // Total Row with REAL calculated total
                    TableRow(
                      decoration: const BoxDecoration(),
                      children: [
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        const SizedBox(),
                        _buildTableCell('المجموع', isHeader: true),
                        _buildTableCell(total.toStringAsFixed(2),
                            isHeader: true),
                      ],
                    ),
                    // Discount row if exists with REAL DATA
                    if (widget.dataRows.isNotEmpty &&
                        widget.dataRows[widget.dataRows.length - 1]
                                ["docDiscount"] !=
                            '')
                      TableRow(
                        decoration: const BoxDecoration(),
                        children: [
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          _buildTableCell('الخصم:', isHeader: true),
                          _buildTableCell(
                              widget.dataRows[widget.dataRows.length - 1]
                                  ["docDiscount"],
                              isHeader: true),
                        ],
                      ),
                    // After discount row with REAL calculated value
                    if (widget.dataRows.isNotEmpty &&
                        widget.dataRows[widget.dataRows.length - 1]
                                ["docDiscount"] !=
                            '')
                      TableRow(
                        decoration: const BoxDecoration(),
                        children: [
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          _buildTableCell('بعد الخصم:', isHeader: true),
                          _buildTableCell(
                            NumberFormat.currency(
                                    locale: "en_US",
                                    decimalDigits: 2,
                                    symbol: "")
                                .format(total -
                                    (double.tryParse(widget.dataRows[
                                                widget.dataRows.length - 1]
                                            ["docDiscount"]) ??
                                        0.0)),
                            isHeader: true,
                          ),
                        ],
                      ),
                    // Tax row with REAL DATA
                    if (widget.dataRows.isNotEmpty)
                      TableRow(
                        decoration: const BoxDecoration(),
                        children: [
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          _buildTableCell('ضريبة 16%:', isHeader: true),
                          _buildTableCell(
                              widget.dataRows[widget.dataRows.length - 1]
                                  ["tax"],
                              isHeader: true),
                        ],
                      ),
                    // Net total row with REAL calculated net total
                    if (widget.dataRows.isNotEmpty)
                      TableRow(
                        decoration: const BoxDecoration(),
                        children: [
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          _buildTableCell('الصافي:', isHeader: true),
                          _buildTableCell(
                            widget.dataRows[widget.dataRows.length - 1]
                                        ["docDiscount"] !=
                                    ''
                                ? (NumberFormat.currency(
                                            locale: "en_US",
                                            decimalDigits: 2,
                                            symbol: "")
                                        .format(total -
                                            (double.tryParse(widget.dataRows[
                                                        widget.dataRows.length - 1]
                                                    ["docDiscount"]) ??
                                                0.0)))
                                    .replaceAll(',', '')
                                : NumberFormat.currency(
                                        locale: "en_US",
                                        decimalDigits: 2,
                                        symbol: "")
                                    .format(total)
                                    .replaceAll(',', ''),
                            isHeader: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

          // Receipt table with REAL DATA
          if (widget.doc!.contains('قبض يدوي') || widget.doc!.contains('قبض'))
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(
                    right: 22, left: 22, top: 10, bottom: 120),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2),
                    4: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(
                    color: Colors.grey,
                    width: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  children: [
                    // Table Header
                    TableRow(
                      decoration: BoxDecoration(
                        color: KPrimaryColor.withOpacity(0.1),
                      ),
                      children: [
                        _buildTableCell('#', isHeader: true),
                        _buildTableCell('طريقة الدفع', isHeader: true),
                        _buildTableCell('رقم', isHeader: true),
                        _buildTableCell('التاريخ', isHeader: true),
                        _buildTableCell('القيمة', isHeader: true),
                      ],
                    ),
                    // Table Row with REAL DATA
                    if (widget.dataRows.isNotEmpty)
                      TableRow(
                        children: [
                          _buildTableCell('1'),
                          _buildTableCell(widget.dataRows[0]['check'] == ''
                              ? 'كاش'
                              : 'شيكات'),
                          _buildTableCell(widget.dataRows[0]['check'] == ''
                              ? '-'
                              : widget.dataRows[0]["check.checkNumber"]),
                          _buildTableCell(widget.dataRows[0]['check'] == ''
                              ? '-'
                              : widget.dataRows[0]["check.dueDate"]),
                          _buildTableCell(widget.dataRows[0]['credit']),
                        ],
                      ),
                  ],
                ),
              ),
            ),

          // Fixed Button at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22.0),
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
