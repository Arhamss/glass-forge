import 'package:glass_forge_workbench/features/components/data/models/component_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/bottom_sheet_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/button_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/circle_button_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/context_menu_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/media_card_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/mini_player_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/search_bar_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/segmented_control_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/slider_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/stat_card_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/stepper_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/switch_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/tab_bar_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/toast_story.dart';
import 'package:glass_forge_workbench/features/components/presentation/stories/top_bar_story.dart';
import 'package:glass_forge_workbench/utils/enums/component_id.dart';

/// The story behind each component's playground.
ComponentStory storyFor(ComponentId id) => switch (id) {
  ComponentId.tabBar => tabBarStory(),
  ComponentId.topBar => topBarStory(),
  ComponentId.circleButton => circleButtonStory(),
  ComponentId.segmentedControl => segmentedControlStory(),
  ComponentId.button => buttonStory(),
  ComponentId.glassSwitch => switchStory(),
  ComponentId.slider => sliderStory(),
  ComponentId.stepper => stepperStory(),
  ComponentId.mediaCard => mediaCardStory(),
  ComponentId.statCard => statCardStory(),
  ComponentId.toast => toastStory(),
  ComponentId.bottomSheet => bottomSheetStory(),
  ComponentId.contextMenu => contextMenuStory(),
  ComponentId.miniPlayer => miniPlayerStory(),
  ComponentId.searchBar => searchBarStory(),
};
