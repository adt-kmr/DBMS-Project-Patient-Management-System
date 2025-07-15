import 'package:flutter_test/flutter_test.dart';
import 'package:pgi_app/services/ocr_service.dart';

void main() {
  group('OCRService Tests', () {
    test('should support common image formats', () {
      expect(OCRService.isSupportedImageFile('test.jpg'), true);
      expect(OCRService.isSupportedImageFile('test.jpeg'), true);
      expect(OCRService.isSupportedImageFile('test.png'), true);
      expect(OCRService.isSupportedImageFile('test.bmp'), true);
      expect(OCRService.isSupportedImageFile('test.gif'), true);
      expect(OCRService.isSupportedImageFile('test.webp'), true);
      expect(OCRService.isSupportedImageFile('test.txt'), false);
    });

    test('should support PDF format', () {
      expect(OCRService.isSupportedDocumentFile('document.pdf'), true);
      expect(OCRService.isSupportedDocumentFile('document.doc'), false);
      expect(OCRService.isSupportedDocumentFile('document.txt'), false);
    });

    test('should format extracted text properly', () {
      const rawText = '  Hello   World  \n\n\n  Test  ';
      const expected = 'Hello World\n\nTest';
      expect(OCRService.formatExtractedText(rawText), expected);
    });

    test('should extract email patterns', () {
      const text = 'Contact us at john.doe@example.com or support@company.org';
      final patterns = OCRService.extractPatterns(text);
      expect(patterns['emails'], contains('john.doe@example.com'));
      expect(patterns['emails'], contains('support@company.org'));
    });

    test('should extract phone patterns', () {
      const text = 'Call us at 1234567890 or (123) 456-7890';
      final patterns = OCRService.extractPatterns(text);
      expect(patterns['phones'], contains('1234567890'));
      expect(patterns['phones'], contains('(123) 456-7890'));
    });

    test('should extract date patterns', () {
      const text = 'Date: 12/25/2023 or 2023-12-25';
      final patterns = OCRService.extractPatterns(text);
      expect(patterns['dates'], contains('12/25/2023'));
      expect(patterns['dates'], contains('2023-12-25'));
    });
  });
}
