import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final uuid = const Uuid();

  // Upload image to Firebase Storage and return the download URL
  Future<String?> uploadProductImage(File imageFile) async {
    try {
      // Create a unique filename with UUID
      final String fileName = '${uuid.v4()}.jpg';
      final String filePath = 'product_images/$fileName';
      
      // Create a reference to the location where the file will be uploaded
      final Reference storageRef = _storage.ref().child(filePath);
      
      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Wait for the upload to complete
      final TaskSnapshot taskSnapshot = await uploadTask;
      
      // Get the download URL
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      print("Image uploaded successfully. URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  // Delete an image from Firebase Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract the path from the URL
      final uri = Uri.parse(imageUrl);
      final path = uri.path;
      final decodedPath = Uri.decodeFull(path);
      final gsPath = decodedPath.startsWith('/') 
          ? decodedPath.substring(1) 
          : decodedPath;
      
      // Create a reference to the file
      final Reference storageRef = _storage.ref().child(gsPath);
      
      // Delete the file
      await storageRef.delete();
      
      print("Image deleted successfully.");
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }
}