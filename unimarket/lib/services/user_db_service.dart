import 'package:unimarket/data/firebase_dao.dart';
import 'package:unimarket/data/sqlite_user_dao.dart';
import 'package:unimarket/models/user_model.dart';
import 'package:unimarket/services/connectivity_service.dart';

class UserDBService {
  final SQLiteUserDAO _sqliteUserDAO = SQLiteUserDAO();
  final FirebaseDAO _firebaseDAO = FirebaseDAO();
  final ConnectivityService _connectivityService = ConnectivityService();
  
  // Initialize
  Future<void> initialize() async {
    await _sqliteUserDAO.initialize();
    
    // After initialization, try to sync current user
    await syncCurrentUser();
  }
  
  // Get user by ID (tries local first, then Firebase if online)
  Future<UserModel?> getUserById(String userId) async {
    try {
      print('UserDBService: Getting user $userId');
      
      // First try to get from local database
      UserModel? user = await _sqliteUserDAO.getUserById(userId);
      
      // If not found locally and online, try to get from Firebase
      if (user == null && await _connectivityService.checkConnectivity()) {
        print('UserDBService: User not found locally, fetching from Firebase');
        try {
          // Add timeout to avoid hanging
          user = await _firebaseDAO.getUserById(userId)
              .timeout(Duration(seconds: 3), onTimeout: () => null);
          
          // If found in Firebase, save to local database
          if (user != null) {
            await _sqliteUserDAO.saveUser(user);
            print('UserDBService: Saved user from Firebase to local database: ${user.displayName}');
          }
        } catch (e) {
          print('UserDBService: Error fetching from Firebase: $e');
        }
      }
      
      // If still null, return a fallback user with just the ID to avoid UI errors
      if (user == null) {
        print('UserDBService: Creating fallback user for $userId');
        return UserModel(
          id: userId,
            displayName: 'User ${userId.substring(0, userId.length < 4 ? userId.length : 4)}',
          email: '',
        );
      }
      
      return user;
    } catch (e) {
      print('UserDBService: Error getting user $userId: $e');
      // Return fallback user to avoid UI errors
      return UserModel(
        id: userId,
        displayName: 'User ${userId.substring(0, userId.length < 4 ? userId.length : 4)}',
        email: '',
      );
    }
  }
  
  // Get current user from local database
  Future<UserModel?> getCurrentUserFromLocal() async {
    return await _sqliteUserDAO.getCurrentUser();
  }
  
  // Sync current user from Firebase to local database
  Future<UserModel?> syncCurrentUser() async {
    try {
      // Check if we're online
      if (!(await _connectivityService.checkConnectivity())) {
        print('UserDBService: Offline, using cached current user');
        return await getCurrentUserFromLocal();
      }
      
      // Get current user from Firebase
      final currentUser = await _firebaseDAO.getCurrentUserDetails();
      if (currentUser == null) {
        print('UserDBService: No current user in Firebase');
        return null;
      }
      
      // Save to local database as current user
      await _sqliteUserDAO.saveUser(currentUser, isCurrentUser: true);
      print('UserDBService: Current user synced from Firebase: ${currentUser.displayName}');
      
      return currentUser;
    } catch (e) {
      print('UserDBService: Error syncing current user: $e');
      return null;
    }
  }
  
  // Save user to local database
  Future<bool> saveUser(UserModel user, {bool isCurrentUser = false}) async {
    return await _sqliteUserDAO.saveUser(user, isCurrentUser: isCurrentUser);
  }
  
  // Get all locally saved users
  Future<List<UserModel>> getAllLocalUsers() async {
    return await _sqliteUserDAO.getAllUsers();
  }
  
  // Get users by name search (for local search)
  Future<List<UserModel>> searchUsersByName(String query) async {
    try {
      final allUsers = await _sqliteUserDAO.getAllUsers();
      
      // Filter by name
      return allUsers.where((user) => 
        user.displayName.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      print('UserDBService: Error searching users: $e');
      return [];
    }
  }
  
  // Get count of local users
  Future<int> getLocalUserCount() async {
    return await _sqliteUserDAO.getUserCount();
  }

  // Preload chat participant users for offline use
  Future<void> preloadChatParticipants(List<String> userIds) async {
    if (!await _connectivityService.checkConnectivity()) {
      print('UserDBService: Offline, skipping preload of chat participants');
      return;
    }

    print('UserDBService: Preloading ${userIds.length} chat participants');
    for (final userId in userIds) {
      final localUser = await _sqliteUserDAO.getUserById(userId);
      if (localUser == null) {
        try {
          final user = await _firebaseDAO.getUserById(userId)
              .timeout(Duration(seconds: 2), onTimeout: () => null);
          if (user != null) {
            await _sqliteUserDAO.saveUser(user);
            print('UserDBService: Preloaded user ${user.displayName}');
          }
        } catch (e) {
          print('UserDBService: Error preloading user $userId: $e');
        }
      }
    }
  }
}