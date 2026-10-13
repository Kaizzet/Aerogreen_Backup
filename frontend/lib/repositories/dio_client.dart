import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

class DioClient {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  DioClient({
    Dio? dioInstance,
    FlutterSecureStorage? storage,
  })  : dio = dioInstance ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ),
        secureStorage = storage ?? const FlutterSecureStorage() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.read(key: 'access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Attempt refresh if refresh token exists
            final refreshToken = await secureStorage.read(key: 'refresh_token');
            if (refreshToken != null) {
              try {
                final refreshResponse = await dio.post(
                  ApiConstants.refresh,
                  data: {'refreshToken': refreshToken},
                  options: Options(headers: {'Authorization': ''}),
                );
                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['accessToken'];
                  final newRefreshToken = refreshResponse.data['refreshToken'];
                  await secureStorage.write(key: 'access_token', value: newAccessToken);
                  if (newRefreshToken != null) {
                    await secureStorage.write(key: 'refresh_token', value: newRefreshToken);
                  }

                  // Retry the original failed request with new token
                  final originalOptions = error.requestOptions;
                  originalOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  final retryResponse = await dio.fetch(originalOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (_) {
                // If refresh fails, clear tokens
                await secureStorage.delete(key: 'access_token');
                await secureStorage.delete(key: 'refresh_token');
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
