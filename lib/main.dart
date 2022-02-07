import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapPage()
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Location location = Location();
  late GoogleMapController _mapController;
  final Completer<GoogleMapController> _controller = Completer();

  void _onMapCreated(GoogleMapController mapController) {
    _controller.complete(mapController);
    _mapController = mapController;
  }

  _checkLocationPermission() async {
    bool locationServiceEnabled = await location.serviceEnabled();
    if (!locationServiceEnabled) {
      locationServiceEnabled = await location.requestService();
      if (!locationServiceEnabled) {
        return;
      }
    }

    PermissionStatus locationForAppStatus = await location.hasPermission();
    if (locationForAppStatus == PermissionStatus.denied) {
      await location.requestPermission();
      locationForAppStatus = await location.hasPermission();
      if (locationForAppStatus != PermissionStatus.granted) {
        return;
      }
    }
    LocationData initLocationData = await location.getLocation();
    _mapController.moveCamera(CameraUpdate.newLatLng(LatLng(initLocationData.latitude!, initLocationData.longitude!)));
  }

  Future<LatLng> getCenter() async {
    final GoogleMapController controller = await _controller.future;
    LatLngBounds visibleRegion = await controller.getVisibleRegion();
    LatLng centerLatLng = LatLng(
      (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
      (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
    );
    return centerLatLng;
  }

  Set<Marker> markers = {};
  Set<Polyline> polyline = {};

  void _addMarker() async {
    LocationData locationData = await location.getLocation();

    markers.add(Marker(
      markerId: const MarkerId("current location"),
      infoWindow: const InfoWindow(title: "current location"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      position: LatLng(locationData.latitude!, locationData.longitude!),
    ));

    LatLng pointerLocation = await getCenter();

    markers.add(Marker(
      markerId: const MarkerId("current location"),
      infoWindow: const InfoWindow(title: "current location"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      position: pointerLocation,
    ));

    polyline.add(Polyline(
      polylineId: const PolylineId("polyline"),
      color: Colors.indigoAccent,
      width: 4,
      points: markers.map((marker) => marker.position).toList(),
    ));

    double centerLat = (locationData.latitude! + pointerLocation.latitude) / 2;
    double centerLon = (locationData.longitude! + pointerLocation.latitude) / 2;

    _mapController.moveCamera(CameraUpdate.newLatLng(LatLng(centerLat, centerLon)));

    /*if (markers.isEmpty) {
      markers.add(Marker(
          markerId: const MarkerId("start"),
          infoWindow: const InfoWindow(title: "Start"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          position: position));
    } else {
      markers.add(Marker(
          markerId: const MarkerId("finish"),
          infoWindow: const InfoWindow(title: "Finish"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: position));

      polyline.removeWhere((element) => element.polylineId.value == "polyline");
      polyline.add(Polyline(
        polylineId: const PolylineId("polyline"),
        color: Colors.indigoAccent,
        width: 4,
        points: markers.map((marker) => marker.position).toList(),
      ));
    }*/
    setState(() {});
  }

  @override
  initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map page"),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
        GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(50.45, 30.52),
          zoom: 15,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: _onMapCreated,
        markers: markers,
        polylines: polyline,
        //onTap: _addMarker,
        ),
        _centerPointer(context),
      ]),
    floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    floatingActionButton: Row( children: [
      FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            markers.clear();
            polyline.clear();
          });
        },
        label: const Text("Сброс"),
      ),
      SizedBox(width: 15,),
      FloatingActionButton.extended(
        onPressed: () {
          _addMarker();
        },
        label: const Text("Проложить"),
      )
    ])
    );
  }
  
  Widget _centerPointer(BuildContext context) {
    return Icon(
      Icons.accessibility_new,
      color: Colors.purpleAccent,
      size: 50,
    );
  }
}