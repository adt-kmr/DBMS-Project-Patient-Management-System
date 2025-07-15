import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'camera_capture_page.dart';
import 'services/ocr_service.dart';
import 'widgets/web_ocr_demo.dart';

class OCRPage extends StatefulWidget {
  const OCRPage({super.key});

  @override
  State<OCRPage> createState() => _OCRPageState();
}

class _OCRPageState extends State<OCRPage> {
  final ImagePicker _picker = ImagePicker();
  String _extractedText = '';
  bool _isProcessing = false;
  String _processingStatus = 'Processing...';
  Map<String, List<String>> _extractedPatterns = {};

  @override
  void dispose() {
    OCRService.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    final status = await Permission.camera.request();

    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
      }
      return;
    }

    try {
      final result = await Navigator.push<CameraCapturePageResult>(
        context,
        CameraCapturePageRoute(),
      );

      if (result != null) {
        await _processImage(result.imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        await _processPdf(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking PDF: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: OCRService.getSupportedImageExtensions(),
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        await _processImage(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _extractedText = '';
      _extractedPatterns = {};
      _processingStatus = 'Analyzing image...';
    });

    try {
      final extractedText = await OCRService.extractTextFromImage(imageFile);
      final formattedText = OCRService.formatExtractedText(extractedText);
      final patterns = OCRService.extractPatterns(formattedText);

      setState(() {
        _extractedText = formattedText;
        _extractedPatterns = patterns;
        _isProcessing = false;
      });

      if (_extractedText.isNotEmpty && !_extractedText.contains('No text found')) {
        _showResultDialog('OCR Result', _extractedText, patterns);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in the image')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  Future<void> _processPdf(File pdfFile) async {
    setState(() {
      _isProcessing = true;
      _extractedText = '';
      _extractedPatterns = {};
      _processingStatus = 'Opening PDF document...';
    });

    try {
      // Update status during processing
      setState(() {
        _processingStatus = 'Rendering PDF pages...';
      });
      
      final extractedText = await OCRService.extractTextFromPdf(pdfFile);
      
      setState(() {
        _processingStatus = 'Analyzing extracted text...';
      });
      
      final formattedText = OCRService.formatExtractedText(extractedText);
      final patterns = OCRService.extractPatterns(formattedText);

      setState(() {
        _extractedText = formattedText;
        _extractedPatterns = patterns;
        _isProcessing = false;
      });

      if (_extractedText.isNotEmpty && !_extractedText.contains('No text found')) {
        _showResultDialog('PDF Text Extraction Result', _extractedText, patterns);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in the PDF')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing PDF: $e')),
        );
      }
    }
  }

  void _showResultDialog(String title, String text, Map<String, List<String>> patterns) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Full Text'),
                    Tab(text: 'Extracted Data'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Full text tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          text,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      // Extracted patterns tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (patterns['emails']?.isNotEmpty == true) ...[
                              const Text('📧 Emails:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...patterns['emails']!.map((email) => Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: SelectableText(email),
                              )),
                              const SizedBox(height: 16),
                            ],
                            if (patterns['phones']?.isNotEmpty == true) ...[
                              const Text('📞 Phone Numbers:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...patterns['phones']!.map((phone) => Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: SelectableText(phone),
                              )),
                              const SizedBox(height: 16),
                            ],
                            if (patterns['dates']?.isNotEmpty == true) ...[
                              const Text('📅 Dates:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...patterns['dates']!.map((date) => Padding(
                                padding: const EdgeInsets.only(left: 16, top: 4),
                                child: SelectableText(date),
                              )),
                              const SizedBox(height: 16),
                            ],
                            if (patterns.values.every((list) => list.isEmpty))
                              const Text('No specific patterns detected in the text.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Here you can add functionality to save or use the extracted text
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Text saved successfully')),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text(
          "OCR Scanner",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  Text(
                    _processingStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - kToolbarHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.document_scanner,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Choose OCR Method',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Extract text from images and PDF documents',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Web Platform Warning
                    if (kIsWeb) ...[
                      const WebOCRDemo(),
                      const SizedBox(height: 24),
                    ],
                    
                    // OCR Options
                    _ocrOptionButton(
                      icon: Icons.camera_alt,
                      label: "Scan using Camera",
                      subtitle: "Capture image and extract text",
                      onTap: _openCamera,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    
                    _ocrOptionButton(
                      icon: Icons.photo_library,
                      label: "Select from Gallery",
                      subtitle: "Choose image from gallery",
                      onTap: _pickImageFromGallery,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    
                    _ocrOptionButton(
                      icon: Icons.folder_open,
                      label: "Select Image File",
                      subtitle: "Choose image file (JPG, PNG, etc.)",
                      onTap: _pickImageFile,
                      color: Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    
                    _ocrOptionButton(
                      icon: Icons.picture_as_pdf,
                      label: "Select PDF File",
                      subtitle: "Extract text from PDF using OCR",
                      onTap: _pickPdfFile,
                      color: Colors.red,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Last Extracted Text Section
                    if (_extractedText.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[800]?.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.text_snippet,
                                  color: Colors.blueAccent,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Last Extracted Text:',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _extractedText.length > 200
                                    ? '${_extractedText.substring(0, 200)}...'
                                    : _extractedText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showResultDialog(
                                  'Last OCR Result',
                                  _extractedText,
                                  _extractedPatterns,
                                ),
                                icon: const Icon(Icons.visibility),
                                label: const Text('View Full Text'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Supported Formats Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Supported Formats',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Images: JPG, PNG, BMP, GIF, WebP\nDocuments: PDF',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _ocrOptionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
