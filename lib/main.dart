import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map page',
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

  //включена ли геолокация
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

  //координаты центра видимой области карты
  //здесь находится фиксированный указатель
  Future<LatLng> getCenter() async {
    final GoogleMapController controller = await _controller.future;
    LatLngBounds visibleRegion = await controller.getVisibleRegion();
    LatLng centerLatLng = LatLng(
      (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) / 2,
      (visibleRegion.northeast.longitude + visibleRegion.southwest.longitude) / 2,
    );
    return centerLatLng;
  }

  //передвижение карты к заданной позиции
  Future<void> _goToLatLng(LatLng latLng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: latLng,
        zoom: 14
    )));
  }

  //получение текущей позиции
  Future<LatLng> _getLocationData() async {
    LocationData locationData = await location.getLocation();
    return LatLng(locationData.latitude!, locationData.longitude!);
  }

  //маркеры и линии, которые будут показаны на карте
  Set<Marker> markers = {};
  Set<Polyline> polyline = {};

  //действия по кнопке "Проложить"
  void _addMarker() async {
    _reset();

    //получить текущую позицию
    LatLng currentLocation = await _getLocationData();

    //добавить на неё красный маркер
    markers.add(Marker(
      markerId: const MarkerId("current location"),
      infoWindow: const InfoWindow(title: "current location"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      position: currentLocation,//currentLocation,
    ));

    //получить позицию центра карты (местонаходждение фиксированного указателя)
    LatLng pointerLocation = await getCenter();

    //добавить на неё зелёный маркер
    markers.add(Marker(
      markerId: const MarkerId("pointer location"),
      infoWindow: const InfoWindow(title: "pointer location"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      position: pointerLocation,
    ));

    //провести между двумя маркерами линию
    polyline.add(Polyline(
      polylineId: const PolylineId("polyline"),
      color: Colors.indigoAccent,
      width: 4,
      points: markers.map((marker) => marker.position).toList(),
    ));

    //координаты центра линии между маркерами
    /*double centerLat = (currentLocation.latitude + pointerLocation.latitude) / 2;
    double centerLon = (currentLocation.longitude + pointerLocation.longitude) / 2;*/

    //передвижение карты на центр линии
    //_goToLatLng(LatLng(centerLat, centerLon));

    //расчёт координат противоположных углов (нижнего левого и верхнего правого) прямоугольника,
    //диагональ которого - линия между маркерами
    final LatLng southwest = LatLng(
      min(currentLocation.latitude, pointerLocation.latitude),
      min(currentLocation.longitude, pointerLocation.longitude),
    );
    final LatLng northeast = LatLng(
      max(currentLocation.latitude, pointerLocation.latitude),
      max(currentLocation.longitude, pointerLocation.longitude),
    );
    LatLngBounds bounds = LatLngBounds(
      southwest: southwest,
      northeast: northeast,
    );
    //передвижение карты и изменение масштаба
    //фиксированный указатель автоматически оказывается в центре
    await _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );

    setState(() {});

  }

  void _reset() {
    setState(() {
      markers.clear();
      polyline.clear();
    });
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
        ),
        //фиксированный указатель, находится над картой посередине
        const Icon(
          Icons.accessibility_new,
          color: Colors.purpleAccent,
          size: 50,
        )
      ]),
    floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    floatingActionButton: Row( children: [
      FloatingActionButton.extended(
        onPressed: () {
          _reset();
          _getLocationData().then((latLng) {
            _goToLatLng(latLng);
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
}