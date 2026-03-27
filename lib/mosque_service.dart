import 'package:flutter_google_maps_webservices/places.dart';



class MosqueService {
  // Replace with your actual Google Cloud API Key
  late final GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: "YOUR_GOOGLE_API_KEY");

  Future<List<PlacesSearchResult>> findNearbyMosques(double lat, double lng) async {
    final result = await places.searchNearbyWithRadius(
      Location(lat: lat, lng: lng),
      5000, // 5km radius
      type: "mosque",
    );
    return result.results;
  }
}