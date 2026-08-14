import 'package:dio/dio.dart';
import 'package:social_app/core/di/service_locator.dart';
import 'package:social_app/core/errors/app_exception.dart';
import 'package:social_app/core/storage/token_storage.dart';
import 'package:social_app/core/storage/user_cache.dart';
import 'package:social_app/models/auth_response_model.dart';
import 'package:social_app/models/auth_tokens.dart';
import 'package:social_app/models/login_model.dart';
import 'package:social_app/models/registration_model.dart';
import 'package:social_app/models/user_model.dart';

class AuthRepository {
  final Dio _dio = getIt<Dio>();
  final TokenStorage _tokenStorage = getIt<TokenStorage>();
  final UserCache _userCache = getIt<UserCache>();

  UserModel? get cachedUser => _userCache.current;

  Future<AuthResponseModel> register(RegistrationModel registerData) async {
    try {
      final result = await _dio.post(
        '/auth/register',
        data: registerData.toJson(),
      );

      final auth = AuthResponseModel.fromJson(
        result.data as Map<String, dynamic>,
      );
      await _persistAuth(auth);
      return auth;
    } on DioException catch (e) {
      throw _mapError(e, 'Registration failed');
    }
  }

  Future<AuthResponseModel> login(LoginModel loginData) async {
    try {
      final result = await _dio.post('/auth/login', data: loginData.toJson());

      final auth = AuthResponseModel.fromJson(
        result.data as Map<String, dynamic>,
      );
      await _persistAuth(auth);
      return auth;
    } on DioException catch (e) {
      throw _mapError(e, 'Login failed');
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(
        '/auth/logout',
        data: {'refreshToken': _tokenStorage.current?.refreshToken},
      );
    } on DioException catch (e) {
      throw _mapError(e, 'Error logging out');
    } finally {
      await _tokenStorage.clear();
      await _userCache.clear();
    }
  }

  Future<UserModel> getAuthUser() async {
    try {
      final result = await _dio.get('/auth/me');
      final user = UserModel.fromJson(
        (result.data as Map<String, dynamic>)['user'],
      );
      await _userCache.save(user);
      return user;
    } on DioException catch (e) {
      throw _mapError(e, 'Error fetching authenticated user');
    }
  }

  Future<void> _persistAuth(AuthResponseModel auth) async {
    await _tokenStorage.save(
      AuthTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
      ),
    );
    await _userCache.save(auth.user);
  }

  AppException _mapError(DioException e, String fallback) {
    final data = e.response?.data;
    final message = data is Map ? data['error'] as String? : null;
    return AppException(message ?? fallback, statusCode: e.response?.statusCode);
  }
}
