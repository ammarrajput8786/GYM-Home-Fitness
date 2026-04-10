import 'package:flutter/foundation.dart';
import 'pedometer_real.dart' if (dart.library.html) 'pedometer_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/user_profile.dart';
import '../services/step_counter_service.dart';

class StepProvider extends ChangeNotifier {
  int steps = 0;
  int dailyGoal = 6000;
  double calories = 0.0;
  UserProfile? userProfile;
  final StepCounterService _stepCounterService = StepCounterService();

  // Weekly stats
  List<int> weeklySteps = [0, 0, 0, 0, 0, 0, 0];
  List<double> weeklyCalories = [
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0
  ]; // Workout tracking
  int workoutsCompletedThisWeek = 0;
  double totalWorkoutMinutes = 0.0;

  Stream<StepCount>? _stepCountStream;

  StepProvider() {
    _loadSavedData();
    _initPedometer();
  }

  void _initPedometer() {
    // pedometer plugin is not available on web — guard initialization
    if (kIsWeb) {
      // On web, do not initialize native pedometer stream.
      return;
    }
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream!.listen(_onStepData).onError(_onStepError);

      // Also listen to the step counter service for automatic updates
      _stepCounterService.getStepStream().listen((steps) {
        this.steps = steps;
        _calculateCalories();
        _saveData();
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) print('Pedometer initialization failed: $e');
    }
  }

  void _onStepData(StepCount stepData) {
    steps = stepData.steps;
    _calculateCalories();
    _saveData();
    notifyListeners();
  }

  void _onStepError(error) {
    if (kDebugMode) {
      print("Pedometer Error: $error");
    }
  }

  void _calculateCalories() {
    // Formula: 0.04 calories per step (adjustable based on weight)
    if (userProfile != null) {
      // Adjust for weight: heavier people burn more calories
      calories = steps * 0.04 * (userProfile!.weight / 70);
    } else {
      calories = steps * 0.04;
    }
  }

  double get progress => (steps / dailyGoal).clamp(0, 1);

  double get averageWeeklySteps {
    return weeklySteps.isEmpty
        ? 0
        : weeklySteps.reduce((a, b) => a + b) / weeklySteps.length;
  }

  double get totalWeeklyCalories {
    return weeklyCalories.isEmpty ? 0 : weeklyCalories.reduce((a, b) => a + b);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("steps", steps);
    prefs.setDouble("calories", calories);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    dailyGoal = prefs.getInt("dailyGoal") ?? 6000;
    steps = prefs.getInt("steps") ?? 0;
    calories = prefs.getDouble("calories") ?? 0.0;

    // Load profile from local SharedPreferences only
    _loadProfileFromPrefs(prefs);

    notifyListeners();
  }

  void _loadProfileFromPrefs(SharedPreferences prefs) {
    // Load user profile if exists in SharedPreferences
    String? profileJson = prefs.getString("userProfile");
    if (profileJson != null) {
      try {
        // Try to parse from SharedPreferences format
        final name = prefs.getString("name") ?? '';
        final gender = prefs.getString("gender") ?? 'Male';
        final age = prefs.getInt("age") ?? 25;
        final weight = prefs.getDouble("weight") ?? 70.0;
        final height = prefs.getDouble("height") ?? 170.0;
        final stepGoal = prefs.getInt("stepGoal") ?? 6000;

        if (name.isNotEmpty) {
          userProfile = UserProfile(
            name: name,
            age: age,
            weight: weight,
            height: height,
            gender: gender,
            fitnessLevel: 'beginner',
            dailyStepGoal: stepGoal,
          );
          dailyGoal = stepGoal;
        }
      } catch (e) {
        if (kDebugMode) print("Error loading profile from prefs: $e");
      }
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    userProfile = profile;
    dailyGoal = profile.dailyStepGoal;

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("name", profile.name);
    await prefs.setString("gender", profile.gender);
    await prefs.setInt("age", profile.age);
    await prefs.setDouble("weight", profile.weight);
    await prefs.setDouble("height", profile.height);
    await prefs.setInt("stepGoal", profile.dailyStepGoal);

    _calculateCalories();
    notifyListeners();
  }

  Future<void> updateDailyGoal(int newGoal) async {
    dailyGoal = newGoal;

    // Update in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("dailyGoal", newGoal);

    // Update in user profile if exists
    if (userProfile != null) {
      userProfile = UserProfile(
        id: userProfile!.id,
        name: userProfile!.name,
        age: userProfile!.age,
        weight: userProfile!.weight,
        height: userProfile!.height,
        gender: userProfile!.gender,
        fitnessLevel: userProfile!.fitnessLevel,
        dailyStepGoal: newGoal,
        createdAt: userProfile!.createdAt,
      );
    }

    _calculateCalories();
    notifyListeners();
  }

  void recordWorkout(int minutes, double caloriesBurned) {
    workoutsCompletedThisWeek++;
    totalWorkoutMinutes += minutes;
    calories += caloriesBurned;
    notifyListeners();
  }
}
