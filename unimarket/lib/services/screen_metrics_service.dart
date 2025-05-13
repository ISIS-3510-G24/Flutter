import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScreenMetricsService {
  // Singleton pattern
  static final ScreenMetricsService _instance = ScreenMetricsService._internal();
  factory ScreenMetricsService() => _instance;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Map to store entry timestamps for active screens
  final Map<String, DateTime> _screenEntryTimes = {};
  
  // Queue for offline operations
  final List<Map<String, dynamic>> _offlineQueue = [];
  bool _isInitialized = false;
  bool _isSyncing = false;
  
  ScreenMetricsService._internal() {
    _initialize();
  }
  
  // Initialize the service
  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load queued operations from storage
      await _loadQueueFromStorage();
      
      // Set up periodic sync
      _setupPeriodicSync();
      
      _isInitialized = true;
      debugPrint('📊 ScreenMetrics: Service initialized');
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error initializing: $e');
    }
  }
  
  // Record when a user enters a screen
  void recordScreenEntry(String screenName) {
    try {
      // Store the entry time
      _screenEntryTimes[screenName] = DateTime.now();
      
      // Queue the interaction increment
      _queueOperation({
        'type': 'increment_interaction',
        'screenName': screenName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('📊 ScreenMetrics: Entered $screenName');
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error recording screen entry: $e');
    }
  }
  
  // Record when a user exits a screen
  Future<void> recordScreenExit(String screenName) async {
    try {
      // Check if we have an entry time for this screen
      final entryTime = _screenEntryTimes[screenName];
      if (entryTime == null) {
        debugPrint('⚠️ ScreenMetrics: No entry time found for $screenName');
        return;
      }
      
      // Calculate time spent (in seconds, rounded)
      final exitTime = DateTime.now();
      final timeSpentSeconds = exitTime.difference(entryTime).inSeconds;
      
      // Queue the time update
      _queueOperation({
        'type': 'update_time',
        'screenName': screenName,
        'seconds': timeSpentSeconds,
        'timestamp': exitTime.millisecondsSinceEpoch,
      });
      
      // Remove the entry time from our map
      _screenEntryTimes.remove(screenName);
      
      debugPrint('📊 ScreenMetrics: Exited $screenName, spent $timeSpentSeconds seconds');
      
      // Try to sync immediately
      _syncQueueWithFirestore();
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error recording screen exit: $e');
    }
  }
  
  // Add an operation to the queue
  void _queueOperation(Map<String, dynamic> operation) {
    _offlineQueue.add(operation);
    _saveQueueToStorage();
    
    // Try to sync immediately if there's a good connection
    _syncQueueWithFirestore();
  }
  
  // Save the queue to persistent storage
  Future<void> _saveQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_offlineQueue);
      await prefs.setString('screen_metrics_queue', queueJson);
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error saving queue to storage: $e');
    }
  }
  
  // Load the queue from persistent storage
  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('screen_metrics_queue');
      
      if (queueJson != null) {
        final List<dynamic> decodedQueue = jsonDecode(queueJson);
        _offlineQueue.clear();
        _offlineQueue.addAll(decodedQueue.cast<Map<String, dynamic>>());
        debugPrint('📊 ScreenMetrics: Loaded ${_offlineQueue.length} queued operations');
      }
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error loading queue from storage: $e');
    }
  }
  
  // Set up periodic sync (every 5 minutes)
  void _setupPeriodicSync() {
    Future.delayed(const Duration(minutes: 5), () {
      _syncQueueWithFirestore();
      _setupPeriodicSync(); // Schedule the next sync
    });
  }
  
  // Process all queued operations
  Future<void> _syncQueueWithFirestore() async {
    // Skip if already syncing or queue is empty
    if (_isSyncing || _offlineQueue.isEmpty) return;
    
    // Get current user ID
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('⚠️ ScreenMetrics: No user logged in, skipping sync');
      return;
    }
    
    _isSyncing = true;
    
    try {
      debugPrint('📊 ScreenMetrics: Syncing ${_offlineQueue.length} operations');
      
      final List<Map<String, dynamic>> processedOperations = [];
      
      // Group operations by screen name for more efficient processing
      final Map<String, List<Map<String, dynamic>>> operationsByScreen = {};
      
      for (final operation in _offlineQueue) {
        final screenName = operation['screenName'] as String;
        operationsByScreen.putIfAbsent(screenName, () => []).add(operation);
      }
      
      // Process each screen's operations
      for (final entry in operationsByScreen.entries) {
        final screenName = entry.key;
        final operations = entry.value;
        
        // Count interactions and time updates
        int interactionCount = 0;
        int totalTimeSeconds = 0;
        
        for (final op in operations) {
          if (op['type'] == 'increment_interaction') {
            interactionCount++;
          } else if (op['type'] == 'update_time') {
            totalTimeSeconds += op['seconds'] as int;
          }
          
          processedOperations.add(op);
        }
        
        // Update Firestore atomically
        if (interactionCount > 0 || totalTimeSeconds > 0) {
          try {
            final docRef = _firestore.collection('screen_metrics').doc(screenName);
            
            await _firestore.runTransaction((transaction) async {
              final docSnapshot = await transaction.get(docRef);
              
              if (docSnapshot.exists) {
                // Document exists, update counters
                final currentInteractions = docSnapshot.data()?['interactions'] as int? ?? 0;
                final currentTime = docSnapshot.data()?['time'] as int? ?? 0;
                
                transaction.update(docRef, {
                  'interactions': currentInteractions + interactionCount,
                  'time': currentTime + totalTimeSeconds,
                });
              } else {
                // Document doesn't exist, create it
                transaction.set(docRef, {
                  'interactions': interactionCount,
                  'time': totalTimeSeconds,
                });
              }
            });
            
            debugPrint('📊 ScreenMetrics: Updated $screenName with $interactionCount interactions, $totalTimeSeconds seconds');
          } catch (e) {
            // If this specific operation fails, we'll keep it in the queue
            debugPrint('❌ ScreenMetrics: Error updating $screenName: $e');
            // Remove these operations from the processed list so they stay in the queue
            for (final op in operations) {
              processedOperations.remove(op);
            }
          }
        }
      }
      
      // Remove processed operations from the queue
      _offlineQueue.removeWhere((op) => processedOperations.contains(op));
      
      // Save the updated queue
      await _saveQueueToStorage();
      
      debugPrint('📊 ScreenMetrics: Sync complete, ${_offlineQueue.length} operations remaining');
    } catch (e) {
      debugPrint('❌ ScreenMetrics: Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }
}