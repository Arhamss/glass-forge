# Reference: KiBU glass/blur surface inventory

Captured 2026-08-28 from `kibu-app` @ `develop`. This is the demand side of
the package — the real surfaces it would have to serve.

## Headline

| Metric | Count |
|---|---|
| Files using `BackdropFilter` / `ImageFilter.blur` | 63 |
| Files using real refraction (`liquid_glass_renderer`) | 1 |
| Purpose-named glass/frosted widgets | 7 |

~98% of KiBU's glass is Gaussian blur. That gap is the upgrade the package exists to deliver.

## Blur sigma values in use

No scale, no tokens — eighteen distinct values across the call sites. Imposing a
blur scale is one of the first things the package should do.

| sigmaX | occurrences |
|---|---|
| 1 | 2 |
| 2 | 4 |
| 4 | 4 |
| 6 | 1 |
| 8 | 6 |
| 12 | 6 |
| 13.25 | 1 |
| 14 | 1 |
| 15 | 1 |
| 18 | 2 |
| 20 | 4 |
| 24 | 8 |
| 30 | 12 |
| 40 | 4 |
| 50 | 2 |
| 70 | 1 |
| 80 | 2 |
| 100 | 3 |

## Named glass widgets (the embryonic design system)

- `lib/utils/widgets/core_widgets/buttons/glass_back_button.dart`
- `lib/utils/widgets/core_widgets/buttons/glass_icon_action.dart`
- `lib/utils/widgets/core_widgets/decorations/frosted_pinned_backing.dart`
- `lib/utils/widgets/core_widgets/navigation/header_glass_circle.dart`
- `lib/utils/widgets/core_widgets/navigation/header_glass_pill.dart`
- `lib/utils/widgets/core_widgets/navigation/nav_glass_indicator.dart`
- `lib/utils/widgets/core_widgets/sheets/frosted_surface.dart`

## All blur call sites

```
features/common/badge_celebration/presentation/widgets/badge_celebration_card.dart
features/kid/kid_missions/presentation/widgets/celebration/mission_celebration_card.dart
features/kid/kid_missions/presentation/widgets/detail/mission_status_banner.dart
features/kid/kid_missions/presentation/widgets/detail/mission_status_pill.dart
features/kid/kid_missions/presentation/widgets/missions/mission_coin_chip.dart
features/kid/kid_missions/presentation/widgets/missions/mystery_crate.dart
features/kid/kid_missions/presentation/widgets/missions/mystery_mission_disc.dart
features/kid/kid_profile/presentation/widgets/menu/kid_profile_menu.dart
features/kid/kid_shop/presentation/widgets/detail/kid_inventory_status_badge.dart
features/kid/kid_shop/presentation/widgets/detail/kid_inventory_status_footer.dart
features/kid/kid_shop/presentation/widgets/detail/kid_redeemed_ambient_glow.dart
features/kid/kid_shop/presentation/widgets/inventory/kid_inventory_card.dart
features/parent/parent_home/presentation/widgets/kibu/kibu_speech_bubble.dart
features/parent/parent_home/presentation/widgets/mission_control/friend_approval_face.dart
features/parent/parent_home/presentation/widgets/mission_control/mission_control_header.dart
features/parent/parent_home/presentation/widgets/mission_control/mystery_mission_card_footer.dart
features/parent/parent_home/presentation/widgets/mission_control/mystery_mission_revealed_face.dart
features/parent/parent_home/presentation/widgets/mission_control/reward_redemption_face.dart
features/parent/parent_home/presentation/widgets/mission_control/reward_redemption_footer.dart
features/parent/parent_home/presentation/widgets/parent_home_card_ambience.dart
features/parent/parent_home/presentation/widgets/parent_home_glow.dart
features/parent/parent_home/presentation/widgets/parent_home_hero_glow.dart
features/parent/parent_home/presentation/widgets/parent_streak_pill.dart
features/parent/parent_home/presentation/widgets/sheet_glow.dart
features/parent/parent_home/presentation/widgets/weekly_hero_pill.dart
features/parent/parent_home/presentation/widgets/weekly_report/share/weekly_report_share_glow.dart
features/parent/parent_home/presentation/widgets/weekly_report/share/weekly_report_share_loading_overlay.dart
features/parent/parent_home/presentation/widgets/weekly_report/weekly_report_building_top_band.dart
features/parent/parent_kid_profile/presentation/widgets/activity/activity_delete_confirmation.dart
features/parent/parent_kid_profile/presentation/widgets/kid_profile_remove_action.dart
features/parent/parent_navigation/presentation/widgets/parent_ai_button.dart
features/parent/parent_onboarding/presentation/widgets/family_ready/family_circle.dart
features/parent/parent_onboarding/presentation/widgets/family_ready/family_ready_skip_bar.dart
features/parent/parent_rewards/presentation/widgets/pending/pending_redemption_card.dart
features/parent/parent_rewards/presentation/widgets/reward_flash_badge.dart
features/parent/parent_settings/presentation/widgets/settings_premium_card.dart
utils/widgets/core_widgets/activity/reaction_picker.dart
utils/widgets/core_widgets/buttons/custom_button.dart
utils/widgets/core_widgets/cards/coin_reward_badge.dart
utils/widgets/core_widgets/cards/kid_badge_card.dart
utils/widgets/core_widgets/cards/kid_level_coin_card.dart
utils/widgets/core_widgets/cards/kid_persona_badge.dart
utils/widgets/core_widgets/cards/reward_coin_badge.dart
utils/widgets/core_widgets/chat/chat_closed_notice.dart
utils/widgets/core_widgets/chat/chat_composer.dart
utils/widgets/core_widgets/chat/chat_scroll_to_bottom_button.dart
utils/widgets/core_widgets/decorations/frosted_pinned_backing.dart
utils/widgets/core_widgets/dialogs/confirmation_dialog.dart
utils/widgets/core_widgets/dialogs/ticket_dialog_card.dart
utils/widgets/core_widgets/feedback/level_progress_bar.dart
utils/widgets/core_widgets/feedback/toast_icon_glow.dart
utils/widgets/core_widgets/media/ai_glyph_avatar.dart
utils/widgets/core_widgets/navigation/header_close_circle.dart
utils/widgets/core_widgets/navigation/header_glass_circle.dart
utils/widgets/core_widgets/navigation/header_glass_pill.dart
utils/widgets/core_widgets/navigation/header_share_pill.dart
utils/widgets/core_widgets/overlays/plan_lock_overlay.dart
utils/widgets/core_widgets/overlays/username_rules_popover.dart
utils/widgets/core_widgets/pickers/inline_calendar.dart
utils/widgets/core_widgets/pickers/translucent_date_picker.dart
utils/widgets/core_widgets/pickers/translucent_time_picker.dart
utils/widgets/core_widgets/sheets/frosted_surface.dart
utils/widgets/core_widgets/sheets/sheet_ambient_glow.dart
```
