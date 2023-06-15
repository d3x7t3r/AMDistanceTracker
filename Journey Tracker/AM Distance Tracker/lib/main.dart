import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';

void main() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  runApp(const JourneyTrackerApp());
}

class JourneyTrackerApp extends StatelessWidget {
  const JourneyTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AM Distance Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}

class JourneyTrackerPage extends StatefulWidget {
  const JourneyTrackerPage({Key? key}) : super(key: key);

  @override
  JourneyTrackerPageState createState() => JourneyTrackerPageState();
}

class JourneyTrackerPageState extends State<JourneyTrackerPage> {
  Position? _currentPosition;
  double _totalDistance = 0.0;
  final List<LatLng> _routeCoordinates = [];
  Set<Polyline> polylines = {};
  List<List<LatLng>> _routeHistory = [];
  GoogleMapController? _mapController;

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadRouteHistory();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _currentPosition = position;
      _routeCoordinates.add(LatLng(position.latitude, position.longitude));
      _calculateDistance();
      _updateMarkers();
    });
    _updateMapCamera();
  }

  void _updateMarkers() {
    final marker = Marker(
      markerId: const MarkerId('current_position'),
      position: LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
    );
    setState(() {
      _markers = {marker};
    });
  }

  void _calculateDistance() {
    if (_routeCoordinates.length > 1) {
      final distanceInMeters = Geolocator.distanceBetween(
        _routeCoordinates[_routeCoordinates.length - 2].latitude,
        _routeCoordinates[_routeCoordinates.length - 2].longitude,
        _routeCoordinates.last.latitude,
        _routeCoordinates.last.longitude,
      );
      setState(() {
        _totalDistance += distanceInMeters;
      });
      _updatePolylines();
    }
  }

  void _updatePolylines() {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: List.of(_routeCoordinates),
      color: Colors.blue,
      width: 4,
    );

    setState(() {
      polylines = {polyline};
    });
  }

  void _updateMapCamera() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
        ),
      );
    }
  }

  Future<void> _loadRouteHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRoutes = prefs.getStringList('route_history');
    if (encodedRoutes != null) {
      final routes = encodedRoutes
          .map((encodedRoute) => _decodeRoute(encodedRoute))
          .toList();
      setState(() {
        _routeHistory = routes;
      });
    }
  }

  Future<void> _saveRouteHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRoutes =
        _routeHistory.map((route) => _encodeRoute(route)).toList();
    await prefs.setStringList('route_history', encodedRoutes);
  }

  void _startNewRoute() {
    setState(() {
      _totalDistance = 0.0;
      _routeCoordinates.clear();
    });
  }

  void _finishRoute() {
    setState(() {
      _routeHistory.add(List.from(_routeCoordinates));
      _saveRouteHistory();
    });
    _startNewRoute();
  }

  List<LatLng> _decodeRoute(String encodedRoute) {
    final coordinates = encodedRoute.split('|');
    return coordinates
        .map(
          (coord) => LatLng(
            double.parse(coord.split(',')[0]),
            double.parse(coord.split(',')[1]),
          ),
        )
        .toList();
  }

  String _encodeRoute(List<LatLng> route) {
    return route
        .map((point) => '${point.latitude},${point.longitude}')
        .join('|');
  }

  void _viewRouteHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteHistoryPage(routeHistory: _routeHistory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('AM Distance Tracker'),
        actions: [
          IconButton(
            onPressed: _viewRouteHistory,
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 15,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            polylines: polylines,
            markers: _markers,
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_totalDistance.toStringAsFixed(2)} meters',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  child: const Text('Track Distance'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _finishRoute,
                  child: const Text('Finish Route'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate to the next screen after the splash screen animation is completed
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const JourneyTrackerPage()),
        );
      }
    });

    getAppVersion();
  }

  Future<void> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to AM Distance Tracker',
              style: TextStyle(
                fontSize: 36.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _animation,
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/ic_launcher.png',
                    width: 200.0,
                  ),
                  const SizedBox(
                    height: 5.0,
                  ),
                  const SpinKitWave(color: Colors.white, size: 50.0),
                  const SizedBox(height: 200.0),
                  // ignore: unnecessary_null_comparison
                  if (_appVersion != null)
                    const Text(
                      'Version: 1.0.0',
                      style: TextStyle(
                        fontSize: 18.0,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteHistoryPage extends StatelessWidget {
  final List<List<LatLng>> routeHistory;

  const RouteHistoryPage({Key? key, required this.routeHistory})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route History'),
      ),
      body: ListView.builder(
        itemCount: routeHistory.length,
        itemBuilder: (context, index) {
          final route = routeHistory[index];
          final totalDistance = _calculateTotalDistance(route);
          return ListTile(
            title: Text('Route ${index + 1}'),
            subtitle: Text('${totalDistance.toStringAsFixed(2)} meters'),
            onTap: () {
              _viewRouteOnMap(context, route);
            },
          );
        },
      ),
    );
  }

  double _calculateTotalDistance(List<LatLng> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      final distanceInMeters = Geolocator.distanceBetween(
        route[i].latitude,
        route[i].longitude,
        route[i + 1].latitude,
        route[i + 1].longitude,
      );
      totalDistance += distanceInMeters;
    }
    return totalDistance;
  }

  void _viewRouteOnMap(BuildContext context, List<LatLng> route) {
    final polylines = _createPolylines(route);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteMapPage(route: route, polylines: polylines),
      ),
    );
  }

  Set<Polyline> _createPolylines(List<LatLng> route) {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: route,
      color: Colors.blue,
      width: 4,
    );
    return {polyline};
  }
}

class RouteMapPage extends StatefulWidget {
  final List<LatLng> route;
  final Set<Polyline> polylines;

  const RouteMapPage({Key? key, required this.route, required this.polylines})
      : super(key: key);

  @override
  RouteMapPageState createState() => RouteMapPageState();
}

class RouteMapPageState extends State<RouteMapPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.route.first,
          zoom: 15,
        ),
        onMapCreated: (controller) {
          setState(() {
            _mapController = controller;
            _markers.add(
              Marker(
                markerId: const MarkerId('start'),
                position: widget.route.first,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueViolet),
              ),
            );
            _markers.add(
              Marker(
                markerId: const MarkerId('end'),
                position: widget.route.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
              ),
            );
          });
          _drawPolylines();
        },
        polylines: widget.polylines,
        markers: _markers,
      ),
    );
  }

  Future<void> _drawPolylines() async {
    await Future.delayed(const Duration(microseconds: 500));
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFromLatLngList(widget.route), 50.0),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;

    for (final latLng in list) {
      if (minLat == null || latLng.latitude < minLat) {
        minLat = latLng.latitude;
      }
      if (maxLat == null || latLng.latitude > maxLat) {
        maxLat = latLng.latitude;
      }
      if (minLng == null || latLng.longitude < minLng) {
        minLng = latLng.longitude;
      }
      if (maxLng == null || latLng.longitude > maxLng) {
        maxLng = latLng.longitude;
      }
    }

    return LatLngBounds(
      northeast: LatLng(maxLat!, maxLng!),
      southwest: LatLng(minLat!, minLng!),
    );
  }
}
