import 'package:equatable/equatable.dart';

class AppTab extends Equatable {
  /// Unique identifier. Generated via timestamp or UUID.
  final String id;
  final String? folderPath;
  final String displayName;

  const AppTab({
    required this.id,
    this.folderPath,
    this.displayName = 'New Tab',
  });

  @override
  List<Object?> get props => <Object?>[id, folderPath, displayName];

  AppTab copyWith({
    String? id,
    String? folderPath,
    String? displayName,
    bool clearFolderPath = false,
  }) {
    return AppTab(
      id: id ?? this.id,
      folderPath: clearFolderPath ? null : (folderPath ?? this.folderPath),
      displayName: displayName ?? this.displayName,
    );
  }
}
