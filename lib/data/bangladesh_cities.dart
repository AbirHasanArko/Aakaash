import '../models/weather_models.dart';

/// Hand-curated list of major Bangladesh cities, districts and towns with
/// coordinates. Used for typeahead search; OWM geocoding is used as fallback
/// when a query doesn't match any local entry.
const List<City> kBangladeshCities = [
  City(name: 'Dhaka', district: 'Dhaka', division: 'Dhaka', lat: 23.8103, lon: 90.4125, population: 8906000),
  City(name: 'Chittagong', district: 'Chattogram', division: 'Chattogram', lat: 22.3569, lon: 91.7832, population: 3222000),
  City(name: 'Khulna', district: 'Khulna', division: 'Khulna', lat: 22.8456, lon: 89.4403, population: 1493000),
  City(name: 'Rajshahi', district: 'Rajshahi', division: 'Rajshahi', lat: 24.3745, lon: 88.6042, population: 1031000),
  City(name: 'Sylhet', district: 'Sylhet', division: 'Sylhet', lat: 24.8949, lon: 91.8687, population: 745000),
  City(name: 'Barishal', district: 'Barishal', division: 'Barishal', lat: 22.7010, lon: 90.3535, population: 530000),
  City(name: 'Rangpur', district: 'Rangpur', division: 'Rangpur', lat: 25.7439, lon: 89.2752, population: 700000),
  City(name: 'Mymensingh', district: 'Mymensingh', division: 'Mymensingh', lat: 24.7471, lon: 90.4203, population: 576000),
  City(name: 'Comilla', district: 'Cumilla', division: 'Chattogram', lat: 23.4607, lon: 91.1809, population: 568000),
  City(name: 'Gazipur', district: 'Gazipur', division: 'Dhaka', lat: 23.9999, lon: 90.4203, population: 1200000),
  City(name: 'Narayanganj', district: 'Narayanganj', division: 'Dhaka', lat: 23.6238, lon: 90.5000, population: 967000),
  City(name: 'Savar', district: 'Dhaka', division: 'Dhaka', lat: 23.8583, lon: 90.2667, population: 580000),
  City(name: 'Tangail', district: 'Tangail', division: 'Dhaka', lat: 24.2513, lon: 89.9167, population: 350000),
  City(name: 'Jessore', district: 'Jashore', division: 'Khulna', lat: 23.1667, lon: 89.2167, population: 300000),
  City(name: 'Cox\u2019s Bazar', district: 'Cox\u2019s Bazar', division: 'Chattogram', lat: 21.4272, lon: 92.0078, population: 250000),
  City(name: 'Dinajpur', district: 'Dinajpur', division: 'Rangpur', lat: 25.6273, lon: 88.6287, population: 200000),
  City(name: 'Bogra', district: 'Bogura', division: 'Rajshahi', lat: 24.8500, lon: 89.3711, population: 350000),
  City(name: 'Habiganj', district: 'Habiganj', division: 'Sylhet', lat: 24.3745, lon: 91.4153, population: 70000),
  City(name: 'Kushtia', district: 'Kushtia', division: 'Khulna', lat: 23.9017, lon: 89.1227, population: 220000),
  City(name: 'Pabna', district: 'Pabna', division: 'Rajshahi', lat: 24.0020, lon: 89.2473, population: 190000),
  City(name: 'Brahmanbaria', district: 'Brahmanbaria', division: 'Chattogram', lat: 23.9574, lon: 91.1116, population: 190000),
  City(name: 'Faridpur', district: 'Faridpur', division: 'Dhaka', lat: 23.6061, lon: 89.8408, population: 130000),
  City(name: 'Jamalpur', district: 'Jamalpur', division: 'Mymensingh', lat: 24.9196, lon: 89.9483, population: 150000),
  City(name: 'Noakhali', district: 'Noakhali', division: 'Chattogram', lat: 22.8724, lon: 91.0973, population: 200000),
  City(name: 'Patuakhali', district: 'Patuakhali', division: 'Barishal', lat: 22.3596, lon: 90.3297, population: 90000),
  City(name: 'Khagrachhari', district: 'Khagrachhari', division: 'Chattogram', lat: 23.1192, lon: 91.9847, population: 50000),
  City(name: 'Bagerhat', district: 'Bagerhat', division: 'Khulna', lat: 22.6602, lon: 89.7855, population: 60000),
  City(name: 'Satkhira', district: 'Satkhira', division: 'Khulna', lat: 22.7172, lon: 89.0836, population: 60000),
  City(name: 'Lakshmipur', district: 'Lakshmipur', division: 'Chattogram', lat: 22.9445, lon: 90.8309, population: 80000),
  City(name: 'Chandpur', district: 'Chandpur', division: 'Chattogram', lat: 23.2357, lon: 90.6717, population: 100000),
  City(name: 'Feni', district: 'Feni', division: 'Chattogram', lat: 23.0156, lon: 91.3976, population: 170000),
  City(name: 'Munshiganj', district: 'Munshiganj', division: 'Dhaka', lat: 23.5522, lon: 90.5310, population: 95000),
  City(name: 'Manikganj', district: 'Manikganj', division: 'Dhaka', lat: 23.8617, lon: 90.0003, population: 70000),
  City(name: 'Narsingdi', district: 'Narsingdi', division: 'Dhaka', lat: 23.9362, lon: 90.7153, population: 200000),
  City(name: 'Kishoreganj', district: 'Kishoreganj', division: 'Dhaka', lat: 24.4260, lon: 90.7823, population: 200000),
  City(name: 'Gopalganj', district: 'Gopalganj', division: 'Dhaka', lat: 23.0050, lon: 89.8266, population: 70000),
  City(name: 'Madaripur', district: 'Madaripur', division: 'Dhaka', lat: 23.1707, lon: 90.1985, population: 60000),
  City(name: 'Shariatpur', district: 'Shariatpur', division: 'Dhaka', lat: 23.2051, lon: 90.3491, population: 50000),
  City(name: 'Rajbari', district: 'Rajbari', division: 'Dhaka', lat: 23.7577, lon: 89.6452, population: 60000),
  City(name: 'Sherpur', district: 'Sherpur', division: 'Mymensingh', lat: 25.0194, lon: 90.0157, population: 70000),
  City(name: 'Netrokona', district: 'Netrokona', division: 'Mymensingh', lat: 24.8815, lon: 90.7279, population: 90000),
  City(name: 'Panchagarh', district: 'Panchagarh', division: 'Rangpur', lat: 26.3356, lon: 88.5533, population: 60000),
  City(name: 'Thakurgaon', district: 'Thakurgaon', division: 'Rangpur', lat: 26.0316, lon: 88.4699, population: 80000),
  City(name: 'Nilphamari', district: 'Nilphamari', division: 'Rangpur', lat: 25.9316, lon: 88.8562, population: 90000),
  City(name: 'Kurigram', district: 'Kurigram', division: 'Rangpur', lat: 25.8050, lon: 89.6369, population: 90000),
  City(name: 'Gaibandha', district: 'Gaibandha', division: 'Rangpur', lat: 25.3257, lon: 89.5430, population: 100000),
  City(name: 'Lalmonirhat', district: 'Lalmonirhat', division: 'Rangpur', lat: 25.9170, lon: 89.4466, population: 70000),
  City(name: 'Joypurhat', district: 'Joypurhat', division: 'Rajshahi', lat: 25.0968, lon: 89.0239, population: 60000),
  City(name: 'Naogaon', district: 'Naogaon', division: 'Rajshahi', lat: 24.8020, lon: 88.9486, population: 150000),
  City(name: 'Natore', district: 'Natore', division: 'Rajshahi', lat: 24.4126, lon: 89.0023, population: 100000),
  City(name: 'Chapainawabganj', district: 'Chapainawabganj', division: 'Rajshahi', lat: 24.5972, lon: 88.2770, population: 80000),
  City(name: 'Nawabganj', district: 'Chapainawabganj', division: 'Rajshahi', lat: 24.5877, lon: 88.2735, population: 70000),
  City(name: 'Sirajganj', district: 'Sirajganj', division: 'Rajshahi', lat: 24.4533, lon: 89.7006, population: 200000),
  City(name: 'Meherpur', district: 'Meherpur', division: 'Khulna', lat: 23.7856, lon: 88.6397, population: 50000),
  City(name: 'Chuadanga', district: 'Chuadanga', division: 'Khulna', lat: 23.6333, lon: 88.8500, population: 80000),
  City(name: 'Jhenaidah', district: 'Jhenaidah', division: 'Khulna', lat: 23.5410, lon: 89.1667, population: 90000),
  City(name: 'Magura', district: 'Magura', division: 'Khulna', lat: 23.4874, lon: 89.4192, population: 80000),
  City(name: 'Narail', district: 'Narail', division: 'Khulna', lat: 23.1685, lon: 89.4950, population: 60000),
  City(name: 'Pirojpur', district: 'Pirojpur', division: 'Barishal', lat: 22.5806, lon: 89.9758, population: 60000),
  City(name: 'Jhalokati', district: 'Jhalokati', division: 'Barishal', lat: 22.6420, lon: 90.1980, population: 50000),
  City(name: 'Barguna', district: 'Barguna', division: 'Barishal', lat: 22.1543, lon: 90.1264, population: 60000),
  City(name: 'Bhola', district: 'Bhola', division: 'Barishal', lat: 22.6853, lon: 90.6488, population: 80000),
  City(name: 'Sunamganj', district: 'Sunamganj', division: 'Sylhet', lat: 25.0658, lon: 91.3950, population: 100000),
  City(name: 'Moulvibazar', district: 'Moulvibazar', division: 'Sylhet', lat: 24.4820, lon: 91.7833, population: 90000),
  City(name: 'Rangamati', district: 'Rangamati', division: 'Chattogram', lat: 22.6533, lon: 92.1768, population: 70000),
  City(name: 'Bandarban', district: 'Bandarban', division: 'Chattogram', lat: 22.1953, lon: 92.2183, population: 50000),
  City(name: 'Teknaf', district: 'Cox\u2019s Bazar', division: 'Chattogram', lat: 20.8583, lon: 92.2978, population: 30000),
  City(name: 'Khagrachari', district: 'Khagrachari', division: 'Chattogram', lat: 23.1192, lon: 91.9847, population: 50000),
  City(name: 'Saint Martin\u2019s Island', district: 'Cox\u2019s Bazar', division: 'Chattogram', lat: 20.6270, lon: 92.3250, population: 8000),
  City(name: 'Purbachal', district: 'Narayanganj', division: 'Dhaka', lat: 23.8290, lon: 90.5327, population: 100000),
  City(name: 'Uttara', district: 'Dhaka', division: 'Dhaka', lat: 23.8759, lon: 90.3795, population: 200000),
  City(name: 'Mirpur', district: 'Dhaka', division: 'Dhaka', lat: 23.8069, lon: 90.3687, population: 1000000),
];

/// Match a free-text query against the Bangladesh dataset.
List<City> searchCities(String query, {int limit = 8}) {
  if (query.trim().isEmpty) {
    return const [];
  }
  final q = query.trim().toLowerCase();
  final results = <_ScoredCity>[];

  for (final c in kBangladeshCities) {
    final name = c.name.toLowerCase();
    final district = c.district.toLowerCase();
    final division = c.division.toLowerCase();
    final fullLabel = c.fullLabel.toLowerCase();

    int score = 0;
    if (name == q) {
      score = 100;
    } else if (name.startsWith(q)) {
      score = 80;
    } else if (district.startsWith(q)) {
      score = 70;
    } else if (division.startsWith(q)) {
      score = 60;
    } else if (name.contains(q)) {
      score = 50;
    } else if (district.contains(q)) {
      score = 40;
    } else if (division.contains(q)) {
      score = 30;
    } else if (fullLabel.contains(q)) {
      score = 20;
    }

    if (score > 0) {
      results.add(_ScoredCity(c, score + (c.population ~/ 100000).clamp(0, 10)));
    }
  }

  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(limit).map((e) => e.city).toList(growable: false);
}

class _ScoredCity {
  final City city;
  final int score;
  const _ScoredCity(this.city, this.score);
}
