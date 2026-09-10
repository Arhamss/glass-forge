import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:glass_forge_workbench/features/onboarding/domain/repository/onboarding_repository.dart';
import 'package:glass_forge_workbench/features/onboarding/presentation/cubit/state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required this.repository})
      : super(const OnboardingState());

  final OnboardingRepository repository;

  // TODO(codeable): Add cubit methods (login, register, etc.)
}
