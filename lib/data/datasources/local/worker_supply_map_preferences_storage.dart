import 'package:shared_preferences/shared_preferences.dart';

enum WorkerSupplyFuelPriceDisplayMode {
  gasoline('gasoline'),
  diesel('diesel');

  const WorkerSupplyFuelPriceDisplayMode(this.storageValue);
  final String storageValue;

  static WorkerSupplyFuelPriceDisplayMode fromStorage(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    for (final mode in WorkerSupplyFuelPriceDisplayMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return WorkerSupplyFuelPriceDisplayMode.gasoline;
  }
}

class WorkerSupplyMapPreferencesStorage {
  static const _fuelDisplayModeKey = 'worker_supply_fuel_display_mode_v1';

  Future<WorkerSupplyFuelPriceDisplayMode> loadFuelDisplayMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_fuelDisplayModeKey);
      return WorkerSupplyFuelPriceDisplayMode.fromStorage(raw);
    } catch (_) {
      return WorkerSupplyFuelPriceDisplayMode.gasoline;
    }
  }

  Future<void> saveFuelDisplayMode(
      WorkerSupplyFuelPriceDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fuelDisplayModeKey, mode.storageValue);
  }
}
