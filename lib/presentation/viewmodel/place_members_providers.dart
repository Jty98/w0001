import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:w0001/data/datasources/remote/http_client.dart';
import 'package:w0001/data/datasources/remote/place/place_members_api.dart';
import 'package:w0001/data/model/place_member_model.dart';
import 'package:w0001/data/repository/place_members_repository_impl.dart';
import 'package:w0001/domain/repository/place_members_repository.dart';
import 'package:w0001/domain/use_case/place_members_use_case.dart';

final placeMembersApiProvider = Provider<PlaceMembersApi>(
  (ref) => PlaceMembersApi(AppHttpClient.I),
);

final placeMembersRepositoryProvider = Provider<PlaceMembersRepository>(
  (ref) => PlaceMembersRepositoryImpl(
    ref.read(placeMembersApiProvider),
  ),
);

final placeMembersUseCaseProvider = Provider<PlaceMembersUseCase>(
  (ref) => PlaceMembersUseCase(
    ref.read(placeMembersRepositoryProvider),
  ),
);

/// 현장 멤버 목록 Provider.
final placeMembersProvider = FutureProvider.autoDispose
    .family<List<PlaceMemberRead>, int>((ref, pid) async {
  return ref.read(placeMembersUseCaseProvider).getPlaceMembers(pid);
});
