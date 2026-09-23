import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqconnect/config/env.dart';
import 'package:resqconnect/core/constants/app_constants.dart';
import 'package:resqconnect/core/errors/api_error_parser.dart';
import 'package:resqconnect/core/errors/failures.dart';
import 'package:resqconnect/core/logger/app_logger.dart';
import 'package:resqconnect/core/storage/secure_storage.dart';
import 'package:resqconnect/features/auth/domain/models/user_model.dart';
import 'package:resqconnect/features/auth/domain/repositories/auth_repository.dart';
import 'package:resqconnect/shared/providers/global_providers.dart';

enum AuthStatus { initial, loading, codeSent, profileSetupRequired, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? verificationId;
  final String? phoneNumber;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.verificationId,
    this.phoneNumber,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? verificationId,
    String? phoneNumber,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);
  factory AuthState.loading({String? phoneNumber, String? verificationId}) => AuthState(
        status: AuthStatus.loading,
        phoneNumber: phoneNumber,
        verificationId: verificationId,
      );
  factory AuthState.codeSent({
    required String verificationId,
    required String phoneNumber,
  }) =>
      AuthState(
        status: AuthStatus.codeSent,
        verificationId: verificationId,
        phoneNumber: phoneNumber,
      );
  factory AuthState.profileSetupRequired(UserModel user) =>
      AuthState(status: AuthStatus.profileSetupRequired, user: user);
  factory AuthState.authenticated(UserModel user) =>
      AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String message, {String? phoneNumber, String? verificationId}) => AuthState(
        status: AuthStatus.error,
        errorMessage: message,
        phoneNumber: phoneNumber,
        verificationId: verificationId,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authRepository, this._secureStorage) : super(AuthState.initial()) {
    checkInitialAuth();
  }

  final AuthRepository _authRepository;
  final SecureStorage _secureStorage;

  // Placeholder credentials used only by the development auth bypass; never real tokens.
  static const String _devAccessToken = 'dev-access-token';
  static const String _devRefreshToken = 'dev-refresh-token';

  String? _firebaseVerificationId;
  String? _phoneNumber;
  int? _resendToken;
  bool _otpRequestInFlight = false;
  Timer? _verificationTimeoutTimer;

  String? get phoneNumber => _phoneNumber;
  bool get hasActiveVerificationSession =>
      _firebaseVerificationId != null && _firebaseVerificationId!.isNotEmpty;

  String _maskPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'unknown';
    if (phone.length < 4) return '***';
    final visible = phone.substring(phone.length - 4);
    final prefix = phone.substring(0, phone.length - 4).replaceAll(RegExp(r'\d'), '*');
    return '$prefix$visible';
  }

  void _cancelVerificationTimer() {
    _verificationTimeoutTimer?.cancel();
    _verificationTimeoutTimer = null;
  }

  /// Verifies if user has active tokens saved on the device and restores user session
  Future<void> checkInitialAuth() async {
    state = AuthState.loading();
    try {
      final token = await _secureStorage.read(AppConstants.keyAuthToken);
      if (token == null) {
        state = AuthState.unauthenticated();
        return;
      }

      // A bypass placeholder (e.g. left by an earlier development build) is never
      // honoured, or sent to a backend, when the bypass is disabled.
      if (!Env.isDevAuthBypassEnabled && (token == _devAccessToken ||
          await _secureStorage.read(AppConstants.keyRefreshToken) == _devRefreshToken)) {
        AppLogger.warning('Discarding development-bypass session: bypass is disabled in this build.');
        await _secureStorage.clearAll();
        state = AuthState.unauthenticated();
        return;
      }

      // Development Bypass Session Restoration
      if (Env.isDevAuthBypassEnabled && token == _devAccessToken) {
        final storedRole = await _secureStorage.read(AppConstants.keyUserRole) ?? 'citizen';
        final devUser = UserModel(
          uid: 'dev-user-001',
          firebaseUid: 'dev-firebase-uid',
          phoneNumber: _phoneNumber ?? '+15555555555',
          name: 'ResQConnect User',
          role: storedRole,
          isVerified: true,
          isActive: true,
          createdAt: DateTime.now(),
        );
        state = AuthState.authenticated(devUser);
        AppLogger.info('Development user session restored successfully (Role: ${devUser.role})');
        return;
      }

      final UserModel user = await _authRepository.getMe();
      state = AuthState.authenticated(user);
      AppLogger.info('User session restored successfully (Role: ${user.role})');
    } catch (e) {
      AppLogger.warning('Initial authentication restoration failed. User must log in: $e');
      await _secureStorage.clearAll();
      state = AuthState.unauthenticated();
    }
  }

  Future<void> _dispatchVerifyPhoneNumber({int? forceResendingToken}) async {
    if (_phoneNumber == null) {
      debugPrint('[AUTH] Loading stopped: Phone number is missing');
      state = AuthState.error('Phone number is missing. Please go back and try again.');
      return;
    }

    _cancelVerificationTimer();
    // Safety 30-second timeout in case native SDK hangs without calling any callbacks
    _verificationTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (state.status == AuthStatus.loading) {
        debugPrint('[AUTH] Verification request timed out after 30s');
        debugPrint('[AUTH] Loading stopped');
        state = AuthState.error(
          'Phone verification timed out. Please check network connection and try again.',
          phoneNumber: _phoneNumber,
        );
      }
    });

    debugPrint('[AUTH] Calling Firebase verifyPhoneNumber');
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneNumber!,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _cancelVerificationTimer();
          debugPrint('[AUTH] verificationCompleted');
          try {
            final UserCredential userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final String? idToken = await userCredential.user?.getIdToken();
            if (idToken != null) {
              debugPrint('[AUTH] Automatic verification successful');
              await _processPostFirebaseAuthentication(userCredential, idToken);
            } else {
              _restoreCodeSentState('Failed to retrieve Firebase ID Token.');
            }
          } catch (e) {
            debugPrint('[AUTH] Exception in verificationCompleted: $e');
            _restoreCodeSentState('Automatic verification failed: ${e.toString()}');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _cancelVerificationTimer();
          debugPrint('[AUTH] verificationFailed: [${e.code}] ${e.message}');
          AppLogger.error('Firebase Phone Auth verification failed: ${e.code}', error: e);
          _firebaseVerificationId = null;
          state = AuthState.error(
            '[Firebase ${e.code}] ${e.message ?? 'Phone verification failed. Check phone number format.'}',
            phoneNumber: _phoneNumber,
          );
          debugPrint('[AUTH] Loading stopped');
        },
        codeSent: (String verificationId, int? resendToken) {
          _cancelVerificationTimer();
          debugPrint('[AUTH] codeSent');
          debugPrint('[AUTH] verificationId received: true');
          _firebaseVerificationId = verificationId;
          _resendToken = resendToken;
          state = AuthState.codeSent(
            verificationId: verificationId,
            phoneNumber: _phoneNumber!,
          );
          debugPrint('[AUTH] Navigating to OTP screen');
          debugPrint('[AUTH] Loading stopped');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[AUTH] codeAutoRetrievalTimeout');
          _firebaseVerificationId = verificationId;
          if (state.status == AuthStatus.loading && _phoneNumber != null) {
            state = AuthState.codeSent(
              verificationId: verificationId,
              phoneNumber: _phoneNumber!,
            );
            debugPrint('[AUTH] Navigating to OTP screen');
            debugPrint('[AUTH] Loading stopped');
          }
        },
      );
    } catch (e, stack) {
      _cancelVerificationTimer();
      debugPrint('[AUTH] Exception thrown during verifyPhoneNumber: $e\n$stack');
      state = AuthState.error(
        'Failed to initiate phone verification: ${e.toString()}',
        phoneNumber: _phoneNumber,
      );
      debugPrint('[AUTH] Loading stopped');
    }
  }

  void _restoreCodeSentState(String message) {
    if (_firebaseVerificationId == null || _phoneNumber == null) {
      state = AuthState.error(message, phoneNumber: _phoneNumber);
      return;
    }
    state = AuthState.codeSent(
      verificationId: _firebaseVerificationId!,
      phoneNumber: _phoneNumber!,
    ).copyWith(errorMessage: message);
  }

  /// Triggers Firebase Phone Auth OTP request
  Future<void> requestPhoneOtp(String phoneNumber) async {
    if (_otpRequestInFlight) {
      debugPrint('[AUTH] OTP request already in flight; ignoring duplicate call');
      return;
    }

    final trimmed = phoneNumber.trim();
    _phoneNumber = trimmed;
    final masked = _maskPhoneNumber(trimmed);

    debugPrint('[AUTH] Send OTP started');
    debugPrint('[AUTH] Phone number: $masked');

    _firebaseVerificationId = null;
    _resendToken = null;
    _otpRequestInFlight = true;
    state = AuthState.loading(phoneNumber: _phoneNumber);

    try {
      await _dispatchVerifyPhoneNumber();
    } catch (e, stackTrace) {
      debugPrint('[AUTH] Exception in requestPhoneOtp: $e\n$stackTrace');
      state = AuthState.error(
        'Failed to initiate phone verification: ${e.toString()}',
        phoneNumber: _phoneNumber,
      );
      debugPrint('[AUTH] Loading stopped');
    } finally {
      _otpRequestInFlight = false;
    }
  }

  /// Resends OTP using Firebase forceResendingToken when available
  Future<void> resendOtp() async {
    if (_otpRequestInFlight) {
      debugPrint('[AUTH] Resend ignored; OTP request already in flight');
      return;
    }
    if (_phoneNumber == null) {
      state = AuthState.error('Phone number is missing. Please go back and try again.');
      return;
    }

    final masked = _maskPhoneNumber(_phoneNumber);
    debugPrint('[AUTH] Resend OTP started for $masked');
    _otpRequestInFlight = true;
    state = AuthState.loading(
      phoneNumber: _phoneNumber,
      verificationId: _firebaseVerificationId,
    );

    try {
      await _dispatchVerifyPhoneNumber(forceResendingToken: _resendToken);
    } catch (e, stackTrace) {
      debugPrint('[AUTH] Exception in resendOtp: $e\n$stackTrace');
      _restoreCodeSentState('Failed to resend OTP: ${e.toString()}');
      debugPrint('[AUTH] Loading stopped');
    } finally {
      _otpRequestInFlight = false;
    }
  }

  /// Verifies OTP code using Firebase, exchanges Firebase ID token for backend JWT
  Future<void> verifyOtp(String smsCode) async {
    final verificationId = state.verificationId ?? _firebaseVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      state = AuthState.error(
        'Verification session expired. Please request a new OTP code.',
        phoneNumber: _phoneNumber,
      );
      return;
    }

    _firebaseVerificationId = verificationId;
    debugPrint('[AUTH] OTP verification initiated');
    state = AuthState.loading(
      phoneNumber: _phoneNumber,
      verificationId: verificationId,
    );

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        _restoreCodeSentState('Failed to retrieve Firebase ID token.');
        return;
      }

      debugPrint('[AUTH] Firebase authentication successful');
      await _processPostFirebaseAuthentication(userCredential, idToken);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] verificationFailed during verifyOtp: [${e.code}] ${e.message}');
      AppLogger.error('Firebase OTP verification failed', error: e);
      _restoreCodeSentState(e.message ?? 'Invalid OTP code entered.');
    } catch (e) {
      AppLogger.error('OTP verification error', error: e);
      final message = e is Failure ? e.message : e.toString();
      debugPrint('[AUTH] Authentication error: $message');
      _restoreCodeSentState(message);
    }
  }

  /// Handles post-Firebase auth step (checks for dev bypass vs remote backend JWT exchange)
  Future<void> _processPostFirebaseAuthentication(UserCredential userCredential, String idToken) async {
    if (Env.isDevAuthBypassEnabled) {
      debugPrint('[AUTH] Development authentication bypass enabled');
      debugPrint('[AUTH] Backend JWT exchange skipped in DEVELOPMENT mode');

      final devUser = UserModel(
        uid: 'dev-user-001',
        firebaseUid: userCredential.user?.uid ?? 'dev-firebase-uid',
        phoneNumber: _phoneNumber ?? userCredential.user?.phoneNumber ?? '+15555555555',
        name: null,
        email: userCredential.user?.email,
        role: 'citizen',
        isVerified: true,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _secureStorage.write(AppConstants.keyAuthToken, _devAccessToken);
      await _secureStorage.write(AppConstants.keyRefreshToken, _devRefreshToken);
      await _secureStorage.write(AppConstants.keyUserUid, devUser.uid);
      await _secureStorage.write(AppConstants.keyUserRole, devUser.role);

      _firebaseVerificationId = null;
      _resendToken = null;

      debugPrint('[AUTH] Development user session created');
      state = AuthState.profileSetupRequired(devUser);
      debugPrint('[AUTH] AuthState updated to profileSetupRequired');
      return;
    }

    debugPrint('[AUTH] Firebase ID token retrieved; preparing backend exchange');
    debugPrint('[AUTH] Backend authentication initiated');
    await _handleBackendAuthentication(idToken);
    debugPrint('[AUTH] Backend authentication successful');
  }

  /// Helper function to exchange Firebase ID Token for local JWT tokens
  Future<void> _handleBackendAuthentication(String idToken) async {
    final Map<String, dynamic> response = await _authRepository.verifyFirebaseToken(idToken);

    final String accessToken = response['access_token'] as String;
    final String refreshToken = response['refresh_token'] as String;
    final bool isNewUser = response['is_new_user'] as bool;
    final UserModel user = response['user'] as UserModel;

    await _secureStorage.write(AppConstants.keyAuthToken, accessToken);
    await _secureStorage.write(AppConstants.keyRefreshToken, refreshToken);
    await _secureStorage.write(AppConstants.keyUserUid, user.uid);
    await _secureStorage.write(AppConstants.keyUserRole, user.role);
    debugPrint('[AUTH] JWT persisted to secure storage');

    _firebaseVerificationId = null;
    _resendToken = null;

    if (isNewUser || user.name == null || user.name!.isEmpty) {
      state = AuthState.profileSetupRequired(user);
      debugPrint('[AUTH] AuthState updated to profileSetupRequired');
    } else {
      state = AuthState.authenticated(user);
      debugPrint('[AUTH] AuthState updated to authenticated');
    }
  }

  @visibleForTesting
  Future<void> handleBackendAuthenticationForTesting(String idToken) async {
    await _handleBackendAuthentication(idToken);
  }

  /// Finalizes registration profile setup
  Future<void> finalizeProfileSetup({
    required String fullName,
    String? profilePhoto,
    required String role,
  }) async {
    final currentUser = state.user;
    state = AuthState.loading();

    if (Env.isDevAuthBypassEnabled) {
      final updatedUser = (currentUser ?? UserModel(
        uid: 'dev-user-001',
        firebaseUid: 'dev-firebase-uid',
        phoneNumber: _phoneNumber ?? '+15555555555',
        role: role,
        isVerified: true,
        isActive: true,
        createdAt: DateTime.now(),
      )).copyWith(
        name: fullName,
        profilePhoto: profilePhoto,
        role: role,
      );

      await _secureStorage.write(AppConstants.keyAuthToken, _devAccessToken);
      await _secureStorage.write(AppConstants.keyUserRole, updatedUser.role);

      state = AuthState.authenticated(updatedUser);
      debugPrint('[AUTH] Profile setup completed in DEVELOPMENT mode');
      return;
    }

    try {
      final Map<String, dynamic> response = await _authRepository.setupProfile(
        fullName: fullName,
        profilePhoto: profilePhoto,
        role: role,
      );

      final String newAccessToken = response['access_token'] as String;
      final UserModel updatedUser = response['user'] as UserModel;

      await _secureStorage.write(AppConstants.keyAuthToken, newAccessToken);
      await _secureStorage.write(AppConstants.keyUserRole, updatedUser.role);

      state = AuthState.authenticated(updatedUser);
    } catch (e) {
      // Keep the reason (e.g. a 403 for a role that was not granted) so the setup screen can show it.
      final message = ApiErrorParser.fromError(e, fallbackMessage: 'Unable to complete profile setup.').message;
      state = currentUser != null
          ? AuthState.profileSetupRequired(currentUser).copyWith(errorMessage: message)
          : AuthState.error(message);
    }
  }

  /// Logs out from current device session
  Future<void> logout() async {
    final rt = await _secureStorage.read(AppConstants.keyRefreshToken);
    state = AuthState.loading();

    try {
      if (rt != null && rt != _devRefreshToken) {
        await _authRepository.logout(rt);
      }
    } catch (e) {
      AppLogger.warning('Log out remote revocation request warning: $e');
    } finally {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        AppLogger.warning('Firebase signout warning: $e');
      }
      await _secureStorage.clearAll();
      _firebaseVerificationId = null;
      _phoneNumber = null;
      _resendToken = null;
      state = AuthState.unauthenticated();
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(repository, storage);
});
