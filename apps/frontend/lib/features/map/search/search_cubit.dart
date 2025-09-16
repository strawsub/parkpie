import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search_state.dart';

import 'package:geocoding/geocoding.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(SearchInitial());

  Future<void> searchLocation(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    emit(SearchLoading());

    try {
      final locations = await locationFromAddress(trimmedQuery);
      
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final position = LatLng(loc.latitude, loc.longitude);
        final markerId = 'search_${DateTime.now().millisecondsSinceEpoch}';
        
        emit(SearchSuccess(
          location: position,
          query: trimmedQuery,
          markerId: markerId,
        ));
      } else {
        emit(SearchError('No results found for: $trimmedQuery'));
      }
    } catch (e) {
      emit(SearchError('Error searching location: ${e.toString()}'));
    }
  }

  void clearSearch() {
    emit(SearchCleared());
  }
}