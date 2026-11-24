import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/azure_functions_service.dart';
import '../../../core/repositories/schedule_repository.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/telemetry_service.dart';
import '../../../core/utils/error_utils.dart';

part 'advising_notifier.g.dart';

class AdvisingState {
  final Map<String, List<String>> selectedCourses;
  final String? generationId;
  final bool isGenerating;
  final String? error;

  AdvisingState({
    required this.selectedCourses,
    this.generationId,
    this.isGenerating = false,
    this.error,
  });

  AdvisingState copyWith({
    Map<String, List<String>>? selectedCourses,
    String? generationId,
    bool? isGenerating,
    String? error,
    bool clearError = false,
    bool clearGenerationId = false,
  }) {
    return AdvisingState(
      selectedCourses: selectedCourses ?? this.selectedCourses,
      generationId: clearGenerationId ? null : (generationId ?? this.generationId),
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@riverpod
class AdvisingNotifier extends _$AdvisingNotifier {
  @override
  AdvisingState build() {
    return AdvisingState(selectedCourses: {});
  }

  void toggleCourse(String code) {
    final current = state.selectedCourses;
    final updated = Map<String, List<String>>.from(current);
    if (updated.containsKey(code)) {
      updated.remove(code);
    } else {
      updated[code] = [];
    }
    state = state.copyWith(selectedCourses: updated, clearError: true);
  }

  void resumeGeneration(String id) {
    state = state.copyWith(generationId: id, isGenerating: false, clearError: true);
  }

  void toggleFaculty(String code, String facultyInitial) {
    final current = state.selectedCourses;
    if (!current.containsKey(code)) return;
    
    final updated = Map<String, List<String>>.from(current);
    final faculties = List<String>.from(updated[code]!);
    
    if (faculties.contains(facultyInitial)) {
      faculties.remove(facultyInitial);
    } else {
      faculties.add(facultyInitial);
    }
    
    updated[code] = faculties;
    state = state.copyWith(selectedCourses: updated);
  }

  Future<void> startGeneration({
    required String userId,
    required String semester,
  }) async {
    if (state.selectedCourses.isEmpty) return;

    state = state.copyWith(isGenerating: true, clearError: true, clearGenerationId: true);

    try {
      final apiService = ref.read(azureFunctionsServiceProvider);
      // Clean 'Spring 2026' into 'Spring2026'
      final semesterClean = semester.replaceAll(' ', '');
      
      final genId = await apiService.generateSchedules(
        userId: userId,
        semester: semesterClean,
        courses: state.selectedCourses.keys.toList(),
        filters: {'selected_faculties': state.selectedCourses},
      );

      state = state.copyWith(
        isGenerating: false,
        generationId: genId,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: AuthErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  Future<void> saveSchedule({
    required String semesterCode,
    required Map<String, dynamic> combination,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await ref.read(scheduleRepositoryProvider).saveSchedule(
        userId: user.id,
        semesterCode: semesterCode,
        combinationData: combination,
      );
      TelemetryService.trackEvent(
        'advising_plan_saved',
        properties: {'semester': semesterCode},
      );
      
      // Refresh the saved schedules list if any provider is watching it
      // ref.invalidate(savedSchedulesProvider); 
    } catch (e, st) {
      TelemetryService.recordError(e, st, context: 'advising_save_schedule');
      state = state.copyWith(error: AuthErrorUtils.getFriendlyMessage(e));
    }
  }

  void reset() {
    state = AdvisingState(selectedCourses: {});
  }
}

/// Backwards compatibility alias for `advisingProvider`
final advisingNotifierProvider = advisingProvider;
