import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiptPage extends StatefulWidget {
  final String transactionId;
  final double amount;
  final List<Map<String, dynamic>> products;
  final String phoneNumber;
  final DateTime timestamp;
  final String paymode;

  const ReceiptPage({
    Key? key,
    required this.transactionId,
    required this.amount,
    required this.products,
    required this.phoneNumber,
    required this.timestamp,
    required this.paymode,
  }) : super(key: key);

  @override
  _ReceiptPageState createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _isGeneratingPdf = false;

  double get subtotal => widget.amount / 1.08;
  double get vat => widget.amount - subtotal;

  @override
  Widget build(BuildContext context) {
    String qrData = 'Transaction ID: ${widget.transactionId}\n'
        'Amount: KES ${widget.amount}\n'
        'Phone: ${widget.phoneNumber}\n'
        'Date: ${widget.timestamp.toLocal().toString().split(' ')[0]}\n'
        'Time: ${widget.timestamp.toLocal().toString().split(' ')[1].split('.')[0]}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isGeneratingPdf
                ? const CircularProgressIndicator()
                : const Icon(Icons.download),
            onPressed: _generateAndSavePdf,
            tooltip: 'Download Receipt',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset('assets/images/logo2.png', height: 60, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Column(
                  children: [
                    Text('P.O. Box 12345', style: TextStyle(fontSize: 16)),
                    Text('Website: www.chekr.com', style: TextStyle(fontSize: 16)),
                    Text('Tel: +254 10101010', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Transaction ID: ${widget.transactionId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Date: ${widget.timestamp.toLocal().toString().split(' ')[0]}'),
              Text('Time: ${widget.timestamp.toLocal().toString().split(' ')[1].split('.')[0]}'),
              const Divider(height: 20, thickness: 2),
              const Text('Products Purchased:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...widget.products.map((product) {
                double price = (product['price'] ?? 0).toDouble();
                int quantity = (product['quantity'] ?? 1) as int;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text('${product['name'] ?? 'Unnamed Product'}')),
                      Text('KES ${price.toStringAsFixed(2)} x $quantity'),
                    ],
                  ),
                );
              }).toList(),
              const Divider(height: 20, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                  Text('KES ${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('VAT (8%):', style: TextStyle(fontSize: 16)),
                  Text('KES ${vat.toStringAsFixed(2)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('KES ${widget.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const Divider(height: 20, thickness: 2),
              Text('Payment Mode: ${widget.paymode}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('QR Code:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Center(
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 150.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateAndSavePdf() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) throw Exception('Storage permission not granted');
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text('CHEKR RECEIPT', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('P.O. Box 12345'),
                      pw.Text('Website: www.chekr.com'),
                      pw.Text('Tel: +254 10101010'),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Transaction ID: ${widget.transactionId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: ${widget.timestamp.toLocal().toString().split(' ')[0]}'),
                pw.Text('Time: ${widget.timestamp.toLocal().toString().split(' ')[1].split('.')[0]}'),
                pw.Divider(),
                pw.Text('Products Purchased:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...widget.products.map((product) {
                  double price = (product['price'] ?? 0).toDouble();
                  int quantity = (product['quantity'] ?? 1) as int;
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${product['name'] ?? 'Unnamed Product'}'),
                      pw.Text('KES ${price.toStringAsFixed(2)} x $quantity'),
                    ],
                  );
                }).toList(),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:'),
                    pw.Text('KES ${subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('VAT (8%):'),
                    pw.Text('KES ${vat.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('KES ${widget.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('Payment Method: ${widget.paymode}'),
              ],
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/receipt_${widget.transactionId}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }
}
