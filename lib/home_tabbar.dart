import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:w0001/controller/add_cost_controller.dart';
import 'package:w0001/controller/calendar_controller.dart';
import 'package:w0001/controller/place_list_controller.dart';
import 'package:w0001/controller/worker_controller.dart';
import 'package:w0001/screen/2_add/add_screen.dart';
import 'package:w0001/screen/3_calendar/calendar_screen.dart';
import 'package:w0001/screen/4_human/work_cost_screen.dart';
import 'package:w0001/screen/1_place/place_list_screen.dart';

class HomeTabBar extends StatefulWidget {
  const HomeTabBar({super.key});

  @override
  State<HomeTabBar> createState() => _HomeTabBarState();
}

class _HomeTabBarState extends State<HomeTabBar>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initControllers();
  }

  void _initControllers() {
    Get.put(CalendarController());
    Get.put(AddCostController());
    Get.put(WorkerController());
    Get.put(PlaceListController());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => Column(
                    children: [
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: const [
                            PlaceListScreen(),
                            AddScreen(),
                            CalendarScreen(),
                            WorkCostScreen(),
                          ],
                        ),
                      ),
                      Divider(height: 0, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildTabBar(context),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.15), // 원하는 배경색 설정
      ),
      child: TabBar(
        controller: _tabController,
        tabAlignment: TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.tab,
        unselectedLabelColor: const Color.fromARGB(255, 146, 146, 146),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.house, size: 30),
            text: '현장 관리',
          ),
          Tab(
            icon: Icon(Icons.add_circle, size: 30),
            text: '금액 추가',
          ),
          Tab(
            icon: Icon(Icons.calendar_month, size: 30),
            text: '캘린더',
          ),
          Tab(
            icon: Icon(Icons.person, size: 30),
            text: '인건비',
          ),
        ],
      ),
    );
  }
}
