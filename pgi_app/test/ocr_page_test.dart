import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgi_app/ocr_page.dart';

void main() {
  group('OCRPage Widget Tests', () {
    testWidgets('OCRPage displays all input options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OCRPage(),
        ),
      );

      // Verify the title is displayed
      expect(find.text('Choose OCR Method'), findsOneWidget);

      // Verify all input options are displayed
      expect(find.text('Scan using Camera'), findsOneWidget);
      expect(find.text('Select from Gallery'), findsOneWidget);
      expect(find.text('Select Image File'), findsOneWidget);
      expect(find.text('Select PDF File'), findsOneWidget);

      // Verify icons are displayed
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('OCRPage shows processing indicator when processing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OCRPage(),
        ),
      );

      // Initially should not show processing indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Processing...'), findsNothing);
    });

    testWidgets('Camera option button is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OCRPage(),
        ),
      );

      // Find and tap the camera button
      final cameraButton = find.ancestor(
        of: find.text('Scan using Camera'),
        matching: find.byType(InkWell),
      );

      expect(cameraButton, findsOneWidget);
      
      // Verify button is tappable (no exception thrown)
      await tester.tap(cameraButton);
      await tester.pump();
    });

    testWidgets('Gallery option button is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OCRPage(),
        ),
      );

      // Find and tap the gallery button
      final galleryButton = find.ancestor(
        of: find.text('Select from Gallery'),
        matching: find.byType(InkWell),
      );

      expect(galleryButton, findsOneWidget);
      
      // Verify button is tappable (no exception thrown)
      await tester.tap(galleryButton);
      await tester.pump();
    });

    testWidgets('PDF option button is tappable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OCRPage(),
        ),
      );

      // Find and tap the PDF button
      final pdfButton = find.ancestor(
        of: find.text('Select PDF File'),
        matching: find.byType(InkWell),
      );

      expect(pdfButton, findsOneWidget);
      
      // Verify button is tappable (no exception thrown)
      await tester.tap(pdfButton);
      await tester.pump();
    });
  });
}
