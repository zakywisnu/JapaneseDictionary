# Review implementation plan

Implements the approved design in `review-flow.md`. Execute inline in this workspace and preserve the earlier UI refinements.

- [x] Add session transition and saved-content mapping tests; enable the existing SwiftUIApps test target and verify the missing-feature failure.
- [x] Add value snapshots and an @Observable session view model. Keep all transitions in bounds, require reveal before advancing, reset answers when moving back or restarting, and use no persistence dependencies.
- [x] Build the scrollable review screen with a bottom primary action, word/kanji definitions, empty state, and completion. Wire AppComposer, AppRoutes, and the pushed-route filter. Offer a neutral review action only when today's selected list has items.
- [x] Regenerate the Tuist projects, run framework tests and the app build, and inspect both themes and an accessibility text size. Check completion, repeat, and return navigation; defer VoiceOver testing as requested.
- [x] Update the design guide and specification to describe the implemented feature.

Constraints: iOS 18, Swift 5, local data only, Forest tokens and existing components, stable bundled order and saved indexes unchanged, native AppNavigationStack, no mastery counts or SwiftData changes.

Validation: seven SwiftUIApps tests passed; the simulator app builds and runs. Word reveal/completion/repeat and kanji next/previous were exercised. Light, dark, and accessibility-large text were inspected. VoiceOver remains deferred.
