## UI Pro Max Stack Guidelines
**Stack:** flutter | **Query:** responsive touch navigation
**Source:** stacks/flutter.csv | **Found:** 5 results

### Result 1
- **Category:** Layout
- **Guideline:** Use LayoutBuilder for responsive
- **Description:** Respond to constraints
- **Do:** LayoutBuilder for adaptive layouts
- **Don't:** Fixed sizes for responsive
- **Code Good:** LayoutBuilder(builder: (context constraints) {})
- **Code Bad:** Container(width: 375)
- **Severity:** Medium
- **Docs URL:** https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html
- **Applies To:** flutter 3.44.x (current stable line)
- **Status:** active
- **Verified At:** 2026-08-13

### Result 2
- **Category:** Navigation
- **Guideline:** Use Navigator 2.0 or GoRouter
- **Description:** Declarative routing
- **Do:** go_router for navigation
- **Don't:** Navigator.push for complex apps
- **Code Good:** GoRouter(routes: [...])
- **Code Bad:** Navigator.push everywhere
- **Severity:** Medium
- **Docs URL:** https://pub.dev/packages/go_router
- **Applies To:** flutter 3.44.x (current stable line)
- **Status:** active
- **Verified At:** 2026-08-13

### Result 3
- **Category:** Navigation
- **Guideline:** Use named routes
- **Description:** Organized navigation
- **Do:** Named routes for clarity
- **Don't:** Anonymous routes
- **Code Good:** Navigator.pushNamed(context '/home')
- **Code Bad:** Navigator.push(context MaterialPageRoute())
- **Severity:** Low
- **Docs URL:** 
- **Applies To:** flutter 3.44.x (current stable line)
- **Status:** active
- **Verified At:** 2026-08-13

### Result 4
- **Category:** Navigation
- **Guideline:** Pass typed arguments
- **Description:** Type-safe route arguments
- **Do:** Typed route arguments
- **Don't:** Dynamic arguments
- **Code Good:** MyRoute(id: '123')
- **Code Bad:** arguments: {'id': '123'}
- **Severity:** Medium
- **Docs URL:** 
- **Applies To:** flutter 3.44.x (current stable line)
- **Status:** active
- **Verified At:** 2026-08-13

### Result 5
- **Category:** Animation
- **Guideline:** Use Hero for transitions
- **Description:** Shared element transitions
- **Do:** Hero for navigation animations
- **Don't:** Manual shared element
- **Code Good:** Hero(tag: 'image' child: Image())
- **Code Bad:** Custom shared element animation
- **Severity:** Low
- **Docs URL:** https://api.flutter.dev/flutter/widgets/Hero-class.html
- **Applies To:** flutter 3.44.x (current stable line)
- **Status:** active
- **Verified At:** 2026-08-13

