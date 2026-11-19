# Pastel reference redesign — 1.5.6+15

This revision follows the owner's two supplied mobile references and supersedes
the monochrome/nude presentation in 1.5.5. It is implemented in the production
Flutter application under `hyzen_flutter/`.

The reference fonts were not identified by name. Poppins is the closest licensed
geometric match used here; these are reference-led layouts, not a claim of exact
pixel or font identity. All controls, progress, navigation and content remain
native Flutter widgets backed by the existing app state.

- Home: photographic/profile header, lavender challenge card with generated 3D
  shapes, outlined date pills, asymmetric orange/blue/pink plan cards, compact
  activity summaries and real recent/download state.
- Onboarding: generated student portrait, pastel arches, rounded white content
  panel and compact Continue control. The remaining pages retain Hyzen's panda.
- Study: mint-to-cream feature card and rounded resource rows. Office uses a pink
  feature card with a separate document illustration. Downloads uses a blue card.
- Poppins type, white/peach static canvas, consistent card radii and pill controls
  extend through forms, account/settings, goals/progress, rankings and admin.
- Buttons use a 36dp visual minimum and padded 48dp tap targets. Actions wrap when
  text grows. The five-tab dock keeps existing navigation stacks and accessible
  labels; only the active label is visible at ordinary font sizes.
- Light mode is enforced, including legacy dark preferences and Android launch
  resources. Theme selection was removed. Old preference values stay stored;
  study, account, notification and download data are not reset.

Four app-owned illustrations were generated for this revision. The onboarding
student is fictional. Existing panda artwork is retained. Poppins is shipped
with its SIL Open Font License; Unslop/Magic UI notices remain under
[third-party](third-party/README.md). The owner's explicit gradient/illustration
requirements take precedence over Unslop's default visual restrictions.

## Review actual Flutter captures

[Previous 1.5.5 screens](../hyzen_flutter/qa/monochrome/after/) ·
[Current captures](../hyzen_flutter/qa/reference/after/)

| Screen | Current capture |
| --- | --- |
| Home | [Home](../hyzen_flutter/qa/reference/after/light_home.png) |
| Onboarding | [Welcome](../hyzen_flutter/qa/reference/after/light_welcome.png) |
| Study | [Study](../hyzen_flutter/qa/reference/after/light_study.png) |
| Office | [Office](../hyzen_flutter/qa/reference/after/light_pdf-studio.png) |
| Downloads | [Downloads](../hyzen_flutter/qa/reference/after/light_downloads.png) |
| Profile | [Account](../hyzen_flutter/qa/reference/after/light_profile.png) |
| Settings | [Settings](../hyzen_flutter/qa/reference/after/light_settings.png) |
| Goals | [Goals](../hyzen_flutter/qa/reference/after/light_study-goals.png) |
| Admin | [Admin](../hyzen_flutter/qa/reference/after/light_admin.png) |

These captures render the actual app with isolated fixtures. Production data,
Firebase settings, authorization and routes are not replaced by fixture data.
The separate 1.5.5 Sites preview remains an older build; it is not the current
reference redesign. GitHub live-preview work was paused at the owner's request.

## Preserved and removed

Preserved: study sessions and persistence; daily/weekly/custom goals; tasks,
streaks, reminders and professional ranks; Firebase/OneSignal; announcements;
unpublished-year fallback; scanning, OCR, PDF editing/viewing and document search;
offline downloads; profile/preferences; shop/orders and admin routes.

Changed presentation: typography, surfaces, imagery, card proportions, buttons
and dock. Removed: dark-mode selection/runtime and old decorative presentation.
The six automatic landscape backgrounds remain removed. No continuous background
animation was added. Motion remains finite and respects reduced motion.

Android build 15 / version 1.5.6 is used so the new design can update the already
published 1.5.5+14 app with its original package ID and signing certificate.
Physical GPU smoothness, camera/OCR quality, battery and live account/push flows
require separate device verification. The [release validation report](https://github.com/Horizon003/pharm-d-with-hyzen/releases/download/v1.5.6-15/validation-1.5.6.md) records native frame timings, checksum, certificate and update/install checks after validation.
