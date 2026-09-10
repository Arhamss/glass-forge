import 'package:flutter_bloc/flutter_bloc.dart';

class CustomDropdownState {
  const CustomDropdownState({
    this.isOpen = false,
    this.errorText,
  });

  final bool isOpen;
  final String? errorText;

  CustomDropdownState copyWith({
    bool? isOpen,
    String? errorText,
    bool clearError = false,
  }) {
    return CustomDropdownState(
      isOpen: isOpen ?? this.isOpen,
      errorText: clearError ? null : (errorText ?? this.errorText),
    );
  }
}

class CustomDropdownCubit extends Cubit<CustomDropdownState> {
  CustomDropdownCubit() : super(const CustomDropdownState());

  void toggleDropdown() {
    emit(state.copyWith(isOpen: !state.isOpen));
  }

  void closeDropdown() {
    emit(state.copyWith(isOpen: false));
  }

  void openDropdown() {
    emit(state.copyWith(isOpen: true));
  }

  void setError(String? error) {
    emit(state.copyWith(errorText: error, clearError: error == null));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
