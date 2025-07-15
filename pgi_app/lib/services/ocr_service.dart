import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from an image file
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      // Check if running on web platform
      if (kIsWeb) {
        // Web fallback - return a demo message since ML Kit doesn't work on web
        return '''
This is a demo OCR result for web platform.

In a production app, you would integrate with:
- Google Cloud Vision API
- Azure Computer Vision
- AWS Textract
- Tesseract.js for client-side OCR

Sample extracted text:
Patient Name: John Doe
Date: ${DateTime.now().toString().split(' ')[0]}
Diagnosis: Regular checkup
Medication: As prescribed
        ''';
      }
      
      // Mobile platform - use ML Kit
      final processedImage = await _preprocessImage(imageFile);
      final inputImage = InputImage.fromFile(processedImage);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      
      return recognizedText.text;
    } catch (e) {
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract text from a PDF file
  static Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      // Check if running on web platform
      if (kIsWeb) {
        // Web fallback for PDF processing
        return '''
This is a demo PDF text extraction for web platform.

In a production app, you would use:
- PDF.js for client-side PDF processing
- Server-side PDF processing APIs
- Cloud-based document processing services

Sample PDF content:
Medical Report
Patient: Jane Smith
Date: ${DateTime.now().toString().split(' ')[0]}
Report Type: Lab Results
Results: All values within normal range
        ''';
      }
      
      // Mobile platform - use pdfx package for rendering and OCR
      final document = await PdfDocument.openFile(pdfFile.path);
      final pageCount = document.pagesCount;
      
      String extractedText = '';
      
      for (int i = 1; i <= pageCount; i++) {
        try {
          // Get the page
          final page = await document.getPage(i);
          
          // Render page as image for OCR
          final pageImage = await page.render(
            width: page.width * 2, // Higher resolution for better OCR
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          
          if (pageImage != null) {
            // Create a temporary file for the rendered image
            final tempDir = Directory.systemTemp;
            final tempFile = File('${tempDir.path}/pdf_page_$i.png');
            await tempFile.writeAsBytes(pageImage.bytes);
            
            // Extract text using OCR
            final pageText = await extractTextFromImage(tempFile);
            extractedText += 'Page $i:\n$pageText\n\n';
            
            // Clean up temporary file
            await tempFile.delete();
          }
          
          // Close the page
          page.close();
        } catch (e) {
          extractedText += 'Page $i: Error processing page - $e\n\n';
        }
      }
      
      // Close the document
      document.close();
      
      if (extractedText.trim().isEmpty) {
        return '''
PDF processed successfully but no text was extracted.

This could mean:
1. The PDF contains only images (scanned document)
2. The PDF has complex formatting that requires specialized processing
3. The text is embedded in a way that requires different extraction methods

File: ${pdfFile.path.split('/').last}
Pages: $pageCount
Size: ${await pdfFile.length()} bytes

For production use, consider:
- Server-side PDF text extraction
- Specialized PDF processing services
- OCR preprocessing for scanned documents
        ''';
      }
      
      return extractedText;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Preprocess image to improve OCR accuracy
  static Future<File> _preprocessImage(File imageFile) async {
    try {
      // Read the image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        return imageFile; // Return original if preprocessing fails
      }

      // Apply image processing for better OCR
      // 1. Convert to grayscale
      image = img.grayscale(image);
      
      // 2. Increase contrast (using correct parameter values)
      image = img.contrast(image, contrast: 120);
      
      // 3. Apply basic image enhancement
      image = img.normalize(image, min: 0, max: 255);

      // Save the processed image
      final processedBytes = img.encodePng(image);
      final processedFile = File('${imageFile.path}_processed.png');
      await processedFile.writeAsBytes(processedBytes);
      
      return processedFile;
    } catch (e) {
      // If preprocessing fails, return the original image
      return imageFile;
    }
  }

  /// Get supported file extensions
  static List<String> getSupportedImageExtensions() {
    return ['jpg', 'jpeg', 'png', 'bmp', 'gif', 'webp'];
  }

  static List<String> getSupportedDocumentExtensions() {
    return ['pdf'];
  }

  /// Check if file is a supported image format
  static bool isSupportedImageFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return getSupportedImageExtensions().contains(extension);
  }

  /// Check if file is a supported document format
  static bool isSupportedDocumentFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return getSupportedDocumentExtensions().contains(extension);
  }

  /// Clean up resources
  static void dispose() {
    _textRecognizer.close();
  }

  /// Validate and format extracted text
  static String formatExtractedText(String rawText) {
    if (rawText.trim().isEmpty) {
      return 'No text found in the document.';
    }

    // Clean up the text
    String cleanedText = rawText
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n') // Clean up multiple newlines
        .trim();

    return cleanedText;
  }

  /// Extract specific information patterns (e.g., dates, phone numbers, emails)
  static Map<String, List<String>> extractPatterns(String text) {
    Map<String, List<String>> patterns = {};

    // Extract email addresses
    final emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
    patterns['emails'] = emailRegex.allMatches(text).map((m) => m.group(0)!).toList();

    // Extract phone numbers (basic pattern)
    final phoneRegex = RegExp(r'\b\d{10,15}\b|\b\(\d{3}\)\s*\d{3}[-.\s]?\d{4}\b');
    patterns['phones'] = phoneRegex.allMatches(text).map((m) => m.group(0)!).toList();

    // Extract dates (basic patterns)
    final dateRegex = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b');
    patterns['dates'] = dateRegex.allMatches(text).map((m) => m.group(0)!).toList();

    // Extract numbers
    final numberRegex = RegExp(r'\b\d+(?:\.\d+)?\b');
    patterns['numbers'] = numberRegex.allMatches(text).map((m) => m.group(0)!).toList();

    return patterns;
  }
}
