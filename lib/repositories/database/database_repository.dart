import 'package:rxdart/rxdart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/repositories/repositories.dart';
import '/models/models.dart';

class DatabaseRepository extends BaseDatabaseRepository {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  @override
  Stream<User> getUser(String userId) {
    print('Getting user images from DB');
    return _firebaseFirestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => User.fromSnapshot(snap));
  }

  @override
  Stream<List<User>> getUsers(String gender) {
    return _firebaseFirestore
        .collection('users')
        .where('gender', isEqualTo: gender)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => User.fromSnapshot(doc)).toList();
    });
  }

  @override
  Stream<List<User>> getUsersToSwipe(User user) {
    String genderFilter = (user.gender == 'Female') ? 'Male' : 'Female';

    return Rx.combineLatest2(getUser(user.id!), getUsers(genderFilter), (
      User currentUser,
      List<User> users,
    ) {
      return users.where((user) {
        return !(currentUser.swipeLeft!.contains(user.id) ||
            currentUser.swipeRight!.contains(user.id) ||
            currentUser.matches!.contains(user.id));
      }).toList();
    });
  }

  @override
  Stream<List<Match>> getMatches(User user) {
    String genderFilter = (user.gender == 'Female') ? 'Male' : 'Female';

    return Rx.combineLatest2(getUser(user.id!), getUsers(genderFilter), (
      User currentUser,
      List<User> users,
    ) {
      return users
          .where((user) {
            return currentUser.matches!.contains(user.id);
          })
          .map(
            (user) => Match(
              userId: user.id!,
              matchedUser: user,
            ),
          )
          .toList();
    });
  }

  @override
  Future<void> updateUserSwipe(
    String userId,
    String matchId,
    bool isSwipeRight,
  ) async {
    if (isSwipeRight) {
      await _firebaseFirestore.collection('users').doc(userId).update({
        'swipeRight': FieldValue.arrayUnion([matchId])
      });
    } else {
      await _firebaseFirestore.collection('users').doc(userId).update({
        'swipeLeft': FieldValue.arrayUnion([matchId])
      });
    }
  }

  Future<void> updateUserMatch(
    String userId,
    String matchId,
  ) async {
    // Add the match into the current user document.
    await _firebaseFirestore.collection('users').doc(userId).update({
      'matches': FieldValue.arrayUnion([matchId])
    });
    // Add the match into the other user document.
    await _firebaseFirestore.collection('users').doc(matchId).update({
      'matches': FieldValue.arrayUnion([userId])
    });
  }

  @override
  Future<void> createUser(User user) async {
    await _firebaseFirestore.collection('users').doc(user.id).set(user.toMap());
  }

  @override
  Future<void> updateUser(User user) async {
    return _firebaseFirestore
        .collection('users')
        .doc(user.id)
        .update(user.toMap())
        .then(
          (value) => print('User document updated.'),
        );
  }

  @override
  Future<void> updateUserPictures(User user, String imageName) async {
    String downloadUrl =
        await StorageRepository().getDownloadURL(user, imageName);

    return _firebaseFirestore.collection('users').doc(user.id).update({
      'imageUrls': FieldValue.arrayUnion([downloadUrl])
    });
  }
}
