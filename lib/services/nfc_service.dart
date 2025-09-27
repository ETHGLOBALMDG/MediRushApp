// NFC Service
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;

class NFCService {
  /// Check if NFC is available on the device
  static Future<bool> isNFCAvailable() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      return availability == NFCAvailability.available;
    } catch (e) {
      print('Error checking NFC availability: $e');
      return false;
    }
  }

  /// Poll for an NFC tag and return its basic info
  static Future<NFCTag?> pollTag({int timeout = 10}) async {
    try {
      if (!await isNFCAvailable()) return null;

      // Add additional parameters to help with foreground dispatch
      NFCTag tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );
      return tag;
    } catch (e) {
      print('Error polling NFC: $e');
      // Ensure cleanup even on error
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
      return null;
    }
  }

  /// Poll and read ALL NDEF records (not just text)
  static Future<List<String>> readAllRecords({int timeout = 10}) async {
    List<String> result = [];
    NFCTag? tag;

    try {
      if (!await isNFCAvailable()) return result;

      tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card to read",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      print('Tag detected: ${tag.id}');

      if (tag.ndefAvailable != true) {
        print('No NDEF data on this tag');
        return result;
      }

      var records = await FlutterNfcKit.readNDEFRecords();
      print('Total records found: ${records.length}');

      for (int i = 0; i < records.length; i++) {
        var record = records[i];
        print('Record $i type: ${record.runtimeType}');

        if (record is ndef.TextRecord && record.text != null) {
          result.add('TEXT: ${record.text!}');
          print('Found text record: ${record.text}');
        } else if (record is ndef.UriRecord && record.uri != null) {
          result.add('URL: ${record.uri!}');
          print('Found URI record: ${record.uri}');
          // } else if (record is ndef.) {
          // result.add('WIFI: ${record.ssid}');
          // print('Found WiFi record');
        } else {
          // Handle other record types
          result.add('UNKNOWN: ${record.runtimeType}');
          print('Found unknown record type: ${record.runtimeType}');
        }
      }

      print('Successfully read ${result.length} total records');
    } catch (e) {
      print('Error reading NDEF: $e');
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }

    return result;
  }

  /// Poll and write text to NFC tag with enhanced control
  static Future<bool> writeText(String text, {int timeout = 10}) async {
    if (text.isEmpty) {
      print('Cannot write empty text');
      return false;
    }

    NFCTag? tag;

    try {
      if (!await isNFCAvailable()) return false;

      // The key is to start the session immediately when your app calls this
      // This should prevent the system popup by taking control first
      tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Writing to NFC card...",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      print('Tag detected: ${tag.id}');
      print('Tag NDEF Available: ${tag.ndefAvailable}');
      print('Tag NDEF Writable: ${tag.ndefWritable}');
      print('Tag NDEF Capacity: ${tag.ndefCapacity}');

      // Check if tag supports NDEF
      if (tag.ndefAvailable != true) {
        print('Tag does not support NDEF');
        return false;
      }

      // Check if tag is writable
      if (tag.ndefWritable != true) {
        print('Tag is not writable');
        return false;
      }

      // Create the NDEF record with null safety
      ndef.NDEFRecord record;
      try {
        if (text.startsWith('http://') || text.startsWith('https://')) {
          print('Creating URI record for: $text');
          record = ndef.UriRecord.fromString(text);
        } else {
          print('Creating text record for: $text');
          record = ndef.TextRecord(text: text);
        }
      } catch (recordError) {
        print('Error creating NDEF record: $recordError');
        return false;
      }

      // Verify record was created successfully
      if (record == null) {
        print('Failed to create NDEF record');
        return false;
      }

      print('Record created successfully, writing to tag...');

      // Write NDEF record
      await FlutterNfcKit.writeNDEFRecords([record]);
      print('Text written successfully: "$text"');
      return true;
    } catch (e) {
      print('Error writing NDEF: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    } finally {
      // Always cleanup - this is crucial
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }
  }

  /// Write multiple text records to NFC tag
  static Future<bool> writeMultipleTexts(List<String> texts,
      {int timeout = 10}) async {
    if (texts.isEmpty) {
      print('Cannot write empty text list');
      return false;
    }

    try {
      if (!await isNFCAvailable()) return false;

      var tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      print('Tag detected: ${tag.id}');

      if (tag.ndefWritable != true) {
        print('Tag is not writable');
        return false;
      }

      // Create multiple NDEF Text Records
      var textRecords =
          texts.map((text) => ndef.TextRecord(text: text)).toList();

      // Write NDEF records
      await FlutterNfcKit.writeNDEFRecords(textRecords);
      print('${texts.length} text records written successfully');
      return true;
    } catch (e) {
      print('Error writing multiple NDEF records: $e');
      return false;
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }
  }

  /// Format tag (erase existing NDEF records)
  static Future<bool> formatTag({int timeout = 10}) async {
    try {
      if (!await isNFCAvailable()) return false;

      var tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card to format",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      print('Tag detected for formatting: ${tag.id}');

      if (tag.ndefWritable != true) {
        print('Tag is not writable, cannot format');
        return false;
      }

      await FlutterNfcKit.writeNDEFRecords([]);
      print('Tag formatted successfully');
      return true;
    } catch (e) {
      print('Error formatting NFC tag: $e');
      return false;
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }
  }

  /// Get tag ID without reading NDEF data
  static Future<String?> getTagID({int timeout = 10}) async {
    try {
      if (!await isNFCAvailable()) return null;

      var tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      print('Tag ID retrieved: ${tag.id}');
      return tag.id;
    } catch (e) {
      print('Error getting tag ID: $e');
      return null;
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }
  }

  /// Get detailed tag information
  static Future<Map<String, dynamic>?> getTagInfo({int timeout = 10}) async {
    try {
      if (!await isNFCAvailable()) return null;

      var tag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: timeout),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the NFC card",
        readIso14443A: true,
        readIso14443B: true,
        readIso15693: true,
      );

      return {
        'id': tag.id,
        'standard': tag.standard,
        'type': tag.type,
        'atqa': tag.atqa,
        'sak': tag.sak,
        'historicalBytes': tag.historicalBytes,
        'protocolInfo': tag.protocolInfo,
        'applicationData': tag.applicationData,
        'hiLayerResponse': tag.hiLayerResponse,
        'manufacturer': tag.manufacturer,
        'systemCode': tag.systemCode,
        'dsfId': tag.dsfId,
        'ndefAvailable': tag.ndefAvailable,
        'ndefType': tag.ndefType,
        'ndefWritable': tag.ndefWritable,
        'ndefCanMakeReadOnly': tag.ndefCanMakeReadOnly,
        'ndefCapacity': tag.ndefCapacity,
      };
    } catch (e) {
      print('Error getting tag info: $e');
      return null;
    } finally {
      try {
        await FlutterNfcKit.finish();
      } catch (finishError) {
        print('Error during cleanup: $finishError');
      }
    }
  }

  /// Simple test write method - writes only plain text
  static Future<bool> writeSimpleText(String text, {int timeout = 10}) async {
    if (text.isEmpty) {
      print('Cannot write empty text');
      return false;
    }

    try {
      if (!await isNFCAvailable()) return false;

      var tag = await FlutterNfcKit.poll(timeout: Duration(seconds: timeout));

      print('=== SIMPLE WRITE DEBUG ===');
      print('Tag ID: ${tag.id}');
      print('NDEF Available: ${tag.ndefAvailable}');
      print('NDEF Writable: ${tag.ndefWritable}');
      print('NDEF Capacity: ${tag.ndefCapacity}');
      print('Tag Type: ${tag.type}');
      print('Tag Standard: ${tag.standard}');

      if (tag.ndefAvailable != true) {
        print('❌ Tag does not support NDEF');
        return false;
      }

      if (tag.ndefWritable != true) {
        print('❌ Tag is not writable');
        return false;
      }

      // Create simple text record
      var textRecord = ndef.TextRecord(text: text);
      print('✅ Text record created');

      // Write the record
      await FlutterNfcKit.writeNDEFRecords([textRecord]);
      print('✅ Write operation completed');

      return true;
    } catch (e) {
      print('❌ Error in simple write: $e');
      return false;
    } finally {
      try {
        await FlutterNfcKit.finish();
        print('✅ NFC session finished');
      } catch (finishError) {
        print('❌ Error during cleanup: $finishError');
      }
    }
  }

  static Future<void> stopSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (e) {
      print('Error stopping NFC session: $e');
    }
  }
}
