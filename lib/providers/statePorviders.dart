
import 'package:flutter_riverpod/flutter_riverpod.dart';

final directoryProvider = StateProvider<String>((ref) => "");
final isConfigured = StateProvider<bool>((ref) => true);

