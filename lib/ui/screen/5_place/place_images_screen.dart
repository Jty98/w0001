import 'package:flutter/material.dart';
import 'package:w0001/data/model/place_info_model.dart';

class PlaceImagesScreen extends StatelessWidget {
  final PlaceInfoModel placeInfo;

  const PlaceImagesScreen({super.key, required this.placeInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${placeInfo.pname} 사진관리')),
      body: const Center(
        child: Text('현장 사진관리 화면'),
      ),
    );
  }
}
