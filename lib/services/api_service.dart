// import 'package:dio/dio.dart';

// class ApiService {
//   final Dio _dio =
//       Dio(BaseOptions(baseUrl: "https://jsonplaceholder.typicode.com"));

//   /// Get all posts
//   Future<List<dynamic>> getPosts() async {
//     final response = await _dio.get("/posts");
//     return response.data;
//   }

//   /// Get a single post by ID
//   Future<Map<String, dynamic>> getPostById(int id) async {
//     final response = await _dio.get("/posts/$id");
//     return response.data;
//   }

//   /// Get all comments for a post
//   Future<List<dynamic>> getCommentsForPost(int postId) async {
//     final response = await _dio.get("/posts/$postId/comments");
//     return response.data;
//   }

//   /// Get all users
//   Future<List<dynamic>> getUsers() async {
//     final response = await _dio.get("/users");
//     return response.data;
//   }

//   /// Get a single user
//   Future<Map<String, dynamic>> getUserById(int id) async {
//     final response = await _dio.get("/users/$id");
//     return response.data;
//   }
// }
