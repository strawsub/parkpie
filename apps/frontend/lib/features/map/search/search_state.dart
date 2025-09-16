import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchSuccess extends SearchState {
  final LatLng location;
  final String query;
  final String markerId;

  const SearchSuccess({
    required this.location,
    required this.query,
    required this.markerId,
  });

  @override
  List<Object> get props => [location, query, markerId];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object> get props => [message];
}

class SearchCleared extends SearchState {}