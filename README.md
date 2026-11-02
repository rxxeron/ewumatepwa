# EWUmate PWA — Architecture, Screen Inventory & Web Platform Documentation

**Production Web Client:** [https://app.ewumate.pro.bd](https://app.ewumate.pro.bd)  
**Target Environment:** Modern Web Browsers, Progressive Web App (PWA), iOS Safari ("Add to Home Screen"), Android Web  
**Core Framework:** Flutter 3.27+ Web (Dart 3.x)  
**Backend & Cloud Services:** Supabase (Auth, PostgreSQL, Storage, Edge Functions), Azure Functions (C# / Node.js Scrapers & PDF Engines), Firebase Cloud Messaging (Web Push VAPID)  
**Client Persistence:** Hive 2.x backed by Browser IndexedDB  

---

## Table of Contents

1. [PWA Purpose, Strategy & Architectural Vision](#1-pwa-purpose-strategy--architectural-vision)
   - [1.1 The Strategic Problem: Cross-Platform Friction & iOS Distribution](#11-the-strategic-problem-cross-platform-friction--ios-distribution)
   - [1.2 Target Platform Matrix: PWA vs. Android Play Store](#12-target-platform-matrix-pwa-vs-android-play-store)
   - [1.3 Core Architectural Overview](#13-core-architectural-overview)
2. [Complete Screen-by-Screen Inventory](#2-complete-screen-by-screen-inventory)
   - [2.1 Advising](#21-advising)
   - [2.2 Authentication & Access Gating](#22-authentication--access-gating)
   - [2.3 Course Browser](#23-course-browser)
   - [2.4 Dashboard](#24-dashboard)
   - [2.5 Faculty Directory](#25-faculty-directory)
   - [2.6 Layout & Navigation Shell](#26-layout--navigation-shell)
   - [2.7 Notifications & Reminders](#27-notifications--reminders)
   - [2.8 Onboarding Flow](#28-onboarding-flow)
   - [2.9 User Profile & Community](#29-user-profile--community)
   - [2.10 Progress Tracking](#210-progress-tracking)
   - [2.11 Results & Grade Management](#211-results--grade-management)
   - [2.12 Class & Exam Schedule](#212-class--exam-schedule)
   - [2.13 Semester Progress & Academic Analytics](#213-semester-progress--academic-analytics)
   - [2.14 Student Services & Academic Tools](#214-student-services--academic-tools)
   - [2.15 Study Vault (Past Papers & Resources)](#215-study-vault-past-papers--resources)
   - [2.16 Tasks & Deadlines](#216-tasks--deadlines)
   - [2.17 Tutorials & Guided Walkthroughs](#217-tutorials--guided-walkthroughs)
3. [Mobile vs. PWA Architectural Divergence & Web Adaptations](#3-mobile-vs-pwa-architectural-divergence--web-adaptations)
   - [3.1 Storage Layer: IndexedDB (Hive) vs. Native SQLite / File System](#31-storage-layer-indexeddb-hive-vs-native-sqlite--file-system)
   - [3.2 Push Notifications: Web Push API (VAPID) vs. Android Native FCM](#32-push-notifications-web-push-api-vapid-vs-android-native-fcm)
   - [3.3 File System & PDF Handling: Blob Object URLs vs. `dart:io` Path Writing](#33-file-system--pdf-handling-blob-object-urls-vs-dartio-path-writing)
   - [3.4 Media & Camera Handling: Browser File Picker vs. Native Image Picker](#34-media--camera-handling-browser-file-picker-vs-native-image-picker)
   - [3.5 Screen Protection: Conditional Safe No-Op vs. Hardware `FLAG_SECURE`](#35-screen-protection-conditional-safe-no-op-vs-hardware-flag_secure)
4. [PWA Web Assets, Manifest & Service Worker Engineering](#4-pwa-web-assets-manifest--service-worker-engineering)
   - [4.1 Web App Manifest (`web/manifest.json`)](#41-web-app-manifest-webmanifestjson)
   - [4.2 Web Bootstrap & Preloader (`web/index.html`)](#42-web-bootstrap--preloader-webindexhtml)
   - [4.3 Firebase Messaging Service Worker (`web/firebase-messaging-sw.js`)](#43-firebase-messaging-service-worker-webfirebase-messaging-swjs)
   - [4.4 Service Worker Update Cycle & Dynamic Reloading](#44-service-worker-update-cycle--dynamic-reloading)
   - [4.5 iOS Safari Web Clip & Media Splash Screen Matrix](#45-ios-safari-web-clip--media-splash-screen-matrix)
5. [Build, Hosting & Production Deployment](#5-build-hosting--production-deployment)
   - [5.1 Flutter Web Build Pipeline & Rendering Engine Flags](#51-flutter-web-build-pipeline--rendering-engine-flags)
   - [5.2 Domain Architecture & Routing Strategy](#52-domain-architecture--routing-strategy)
   - [5.3 CORS Policy & Backend Security Configuration](#53-cors-policy--backend-security-configuration)

---

## 1. PWA Purpose, Strategy & Architectural Vision

### 1.1 The Strategic Problem: Cross-Platform Friction & iOS Distribution
EWUmate was engineered to serve the student body of East West University (EWU) in Dhaka, Bangladesh. In the higher education landscape of Bangladesh, student device demographics are sharply bifurcated:
- **Android Users:** Form approximately 70% of the active student body. Android users enjoy native Android APK/Google Play Store distribution with native home screen widgets, persistent background alarms, and deep system integration.
- **iOS / iPadOS Users:** Form approximately 30% of the student body. Distributing a university assistant via the Apple App Store requires ongoing \$99/year Apple Developer Enterprise/Individual enrollments, stringent App Review Guidelines, and binary verification cycles that conflict with agile university schedule and syllabus changes.

Furthermore, students accessing campus computers in computer labs or browsing on laptops demand instant zero-install access without administrative privileges.

**EWUmate PWA solves this dual challenge:**
1. **Zero-Install Frictionless Onboarding:** Any student can navigate to `https://app.ewumate.pro.bd` and immediately access their routine, degree progress, and course schedules.
2. **Primary Client for iOS/iPadOS:** By leveraging Safari’s Progressive Web App capabilities ("Add to Home Screen"), iOS users obtain a standalone, full-screen, native-feeling app experience complete with custom app icons, splash screens, persistent offline storage via IndexedDB, and Web Push notifications without traversing the App Store.

```
       +-------------------------------------------------------------+
       |                  East West University Student               |
       +-------------------------------------------------------------+
                                      |
                     +----------------+----------------+
                     |                                 |
              [Android Device]                 [iOS / iPadOS Device]
                     |                                 |
            Google Play Store                  Safari Browser
       (Native App with Widgets)                       |
                     |                        "Add to Home Screen"
                     |                                 |
                     v                                 v
        [com.rxxeron.ewumate]              [EWUmate Standalone PWA]
                     |                                 |
                     +----------------+----------------+
                                      |
                                      v
                     +---------------------------------+
                     |    Supabase & Azure Cloud Core  |
                     +---------------------------------+
```

### 1.2 Target Platform Matrix: PWA vs. Android Play Store

| Dimension | Native Android Build (`ewumate_production_build`) | Web / PWA Build (`ewumate_pwa`) |
| :--- | :--- | :--- |
| **Distribution Channel** | Google Play Store (`com.rxxeron.ewumate`) | Web URL (`https://app.ewumate.pro.bd`) & Safari Web Clip |
| **Target Audience** | Android smartphones & tablets | iOS / iPadOS users, Desktop browsers, Instant web users |
| **Installation Mechanism** | Standard APK / App Bundle installation | Browser PWA Install Prompt / Safari "Add to Home Screen" |
| **Local Storage Engine** | Native SQLite + Hive file-system storage | Hive backed by browser **IndexedDB** |
| **Push Notifications** | Native Firebase Cloud Messaging + Android AlarmManager | Web Push API via VAPID + Service Worker background listener |
| **PDF Generation Output** | Written to local disk cache and opened via `OpenFilex` | In-memory `Uint8List` converted to browser `Blob` download |
| **Screen Protection** | Hardware-level `FLAG_SECURE` preventing OS screenshots | Conditional safe no-op (browsers prohibit screenshot blocking) |
| **Routing Mechanism** | Internal Navigator / GoRouter memory stack | `pathUrlStrategy` (Clean URLs without `#` hashes) |
| **Access Gate** | Open to all installed Android devices | Protected by `IosOnlyGateScreen` (Desktop/Android redirected) |

### 1.3 Core Architectural Overview
The `ewumate_pwa` application is built on **Flutter 3.27+ Web**, structured with strict domain and data separation via **Riverpod 2.5+** and **GoRouter 17.1+**:

```
+-----------------------------------------------------------------------------------+
|                                  BROWSER CLIENT                                   |
|                                                                                   |
|  +-----------------------------------------------------------------------------+  |
|  |                           Flutter Web Application                           |  |
|  |  +---------------------+  +----------------------+  +--------------------+  |  |
|  |  | Presentation Layer  |  | State Management     |  | Service Layer      |  |  |
|  |  | (42 Glassmorphic   |  | (Riverpod Notifiers, |  | (PWA, FCM, Cache,  |  |  |
|  |  |  Screens & Widgets) |  |  AsyncValue Streams) |  |  Update, Portal)   |  |  |
|  |  +---------------------+  +----------------------+  +--------------------+  |  |
|  +---------------------------------------|-------------------------------------+  |
|                                          |                                        |
|  +---------------------------------------v-------------------------------------+  |
|  |                               Web Platform APIs                             |  |
|  |  [dart:js_interop] <-> [window.deferredPrompt] <-> [Service Worker Engine]  |  |
|  |  [IndexedDB]       <-> [Browser Blob Engine]   <-> [Web Push API]           |  |
|  +-----------------------------------------------------------------------------+  |
+------------------------------------------|----------------------------------------+
                                           | HTTPS / WSS / JWT
            +------------------------------+------------------------------+
            |                                                             |
            v                                                             v
+-------------------------------+                         +-------------------------------+
|         Supabase BaaS         |                         |      Azure Microservices      |
|  - PostgreSQL Database        |                         |  - Schedule Combinatorics     |
|  - Row Level Security (RLS)   |                         |  - EWU Portal Scraper Proxy   |
|  - GoTrue Auth (Google/Email) |                         |  - PDF Cover Page Renderer    |
|  - Storage Buckets (Vault)    |                         |  - High-Memory Node/C# Jobs   |
|  - Realtime WebSockets        |                         +-------------------------------+
+-------------------------------+
```

---

## 2. Complete Screen-by-Screen Inventory

Every screen in `ewumate_pwa/lib/features/` is enumerated below with its exact purpose, visual widgets, providers/state, user interaction flows, and error handling mechanics.

```
ewumate_pwa/lib/features/
├── advising/             # Pre-Advising generator, Degree Audit & Course Offerings
├── auth/                 # Authentication, Zero-Wait Entry & iOS Hardware Gating
├── course_browser/       # Universal Course Catalog & Prerequisite Explorer
├── dashboard/            # Central Command Center, PWA Banner & Daily Routine
├── faculty_directory/    # Faculty Contacts, Office Hours & Student Reviews
├── layout/               # Shell Route & Navigation Bars
├── notifications/        # Web Push History & Per-Course Offset Configurator
├── onboarding/           # Profile Setup, Program Selection & Course Importer
├── profile/              # User Account, App Settings, Feedback & Dev Support
├── progress/             # Course Assessment Marks & Outline Editor
├── results/              # Academic History & Mandatory Semester-End Grade Entry
├── schedule/             # 2-Week Rolling Schedule & Manual Class Tracker
├── semester_progress/    # Live Attendance, Marks Breakdown & CGPA Goals
├── services/             # Cover Page Generator, Portal Sync & Faculty Verification
├── study_vault/          # Community Past Papers, Notes & File Uploads
├── tasks/                # Assignment/Quiz Manager with Offline IndexedDB Sync
└── tutorials/            # Interactive Video Walkthroughs & Onboarding Replay
```

---

### 2.1 Advising

#### `advising_screen.dart` (Pre-Advising Hub)
- **Exact Purpose:** Manages course pre-advising registration, algorithmic schedule combination generation, and advising routine drafts.
- **Visual Widgets:**
  - `AppBar` with status indicator and `_buildProtectionBadge()` (displays green "Draft: Capture Allowed" on Tab 1 or red "Protected" on Tab 0/2).
  - Segmented 3-tab bar: "Pick Courses", "My Drafts", and "Generations".
  - `AdvisingCourseSelectionTab`: Course checklist with section availability.
  - `AdvisingSavedDraftsTab`: Grid of user-saved schedule configurations.
  - `AdvisingGenerationHistoryTab`: Cloud generation history with completion statuses.
  - `AdvisingGenerationOverviewView`: Full-screen tracking overlay active when schedule generation is in progress.
  - `AdvisingLockedView`: Lock screen shown when the advising portal is closed by dates or admin toggle.
- **Providers & State:**
  - `activeSemesterProvider`: Streams current semester parameters (advising start/end dates).
  - `advisingNotifierProvider`: Holds active `generationId`, selected courses, credit counts, and conflicts.
  - `isAdvisingOpenProvider`: Admin feature flag override for manual access control.
  - `availableAdvisingCoursesProvider`: Courses cataloged for advising.
- **User Flows:**
  1. Screen mounts -> Checks `isAdvisingOpenProvider` and date thresholds. If locked, shows `AdvisingLockedView`.
  2. If unlocked, user selects 3-5 courses on "Pick Courses" -> taps "Generate Routine".
  3. UI switches to `AdvisingGenerationOverviewView`, polling generation status from Azure.
  4. User views generated schedule options, selects best variation, and saves it to "My Drafts".
- **Error Handling:** Refresh indicator re-fetches active semester configuration. If generation fails, friendly error is parsed via `AuthErrorUtils.getFriendlyMessage()`. Periodic 3-minute timer self-heals stale session data.

#### `degree_progress_screen.dart` (Degree Audit & Milestone Tracker)
- **Exact Purpose:** Provides a visual degree audit tracking completed credits, remaining semesters, and curriculum milestones.
- **Visual Widgets:**
  - `DegreeHeroCard`: Giant circular SVG/Canvas progress gauge displaying percentage completion, program name (e.g., "B.Sc. in CSE"), and track (Bi-Semester vs Tri-Semester).
  - `DegreeStatsGrid`: 2x2 bento card layout (Credits Completed, Credits Remaining, Semesters Completed, Semesters Left).
  - `DegreeMilestonesCard`: 3-phase journey stepper (Foundational -> Core -> Capstone/Graduation).
  - `DegreeCgpaActionCard`: Current CGPA card with direct link to the CGPA Simulator.
  - `DegreeSemesterSummaryLinkCard`: Navigation shortcut to term-by-term summaries.
  - `DegreeAcademicHistoryList`: Chronological list of completed semesters.
- **Providers & State:**
  - `profileRepositoryProvider`: Streams student profile data (`total_credits_earned`, `total_courses_completed`, `cgpa`, `program_code`).
  - `allSemesterSummariesProvider`: Fetches all finalized semester summary rows.
  - `programDetailsProvider`: Returns required degree credits (e.g., 140 credits for CSE).
  - `academicStateProvider`: Provides current academic track.
- **User Flows:**
  1. Student navigates to Degree Progress -> Profile stream provides latest credit totals.
  2. BBA Curriculum Credit Rule is dynamically applied: if admitted before Spring 2025, sets required credits to 123.0; otherwise 130.0.
  3. User taps `edit_note_rounded` in the app bar -> pushes `/onboarding/course-history` with `isEditMode: true` to update completed courses.
- **Error Handling:** If profile data is missing, displays placeholder empty state. Staged reload via `RefreshIndicator` invalidates `profileRepositoryProvider`, `allSemesterSummariesProvider`, and `academicStateProvider`.

#### `next_semester_screen.dart` (Legacy Course Browser Forwarder)
- **Exact Purpose:** Serves as a route redirector backward-compatible with older URLs (`/next-semester`).
- **Visual Widgets:** Clean background scaffold with centered cyan circular progress indicator.
- **Providers & State:** `selectedSemesterScopeProvider`: Mutated to `SemesterScope.upcoming`.
- **User Flows:** On widget initialization, immediately executes post-frame callback setting `selectedSemesterScopeProvider = SemesterScope.upcoming` and invokes `context.go('/courses')`.
- **Error Handling:** Guaranteed safe execution using `mounted` check before navigation.

---

### 2.2 Authentication & Access Gating

#### `check_auth_screen.dart` (Zero-Wait Entry Bootstrapper)
- **Exact Purpose:** The root gateway of EWUmate (`/`). Resolves user authentication status and profile completeness to direct traffic without white screens or login delays.
- **Visual Widgets:**
  - `SkyAnimationWidget`: Animated gradient background rendering dynamic stars/clouds.
  - `AnimatedStartupCover`: High-resolution logo with pulsing status messages ("Securing universe...", "Restoring session...").
  - `_ErrorView`: Connection error card with "Try Again", "Clear Cache", and "Logout and Reset" buttons.
- **Providers & State:**
  - `currentUserProvider`: Reactive Supabase session listener.
  - `profileProvider`: AsyncValue stream fetching user profile row.
  - `requiresGradeEntryProvider`: Blocks navigation if student has unrecorded grades.
- **User Flows:**
  1. App initializes -> checks `currentSession` and Hive `auth_box`.
  2. If session is null -> navigates to `/login` after brief minimum branding duration (3.5s).
  3. If user exists but profile row is missing -> routes to `/onboarding/program`.
  4. If profile status is `pending` or `registered` -> routes to `/onboarding/profile-setup`.
  5. If status is `course_history` -> routes to `/onboarding/course-history`.
  6. If fully onboarded -> executes `_GradeBlockerWrapper`. If grades pending, routes to `/results/grade-entry`; otherwise checks `TutorialService.hasCompletedWelcomeTour()` to route to `/onboarding/welcome-tour` or `/dashboard`.
- **Error Handling:** 45-second stall detection timer (`_stallTimer`). If network freezes, reveals cache-clearing modal to wipe corrupt IndexedDB boxes and restart cleanly.

#### `login_screen.dart` (Student Login)
- **Exact Purpose:** Authenticates existing students via student email/password or Google OAuth.
- **Visual Widgets:**
  - Glowing circular icon with `Icons.school_rounded` and cyan halo blur.
  - Title "EWUmate" with Sora typography and subtitle.
  - Frosted glass container (`GlassContainer`) holding form fields.
  - `TextFormField` for Email with auto-fill hints (`AutofillHints.email`).
  - `TextFormField` for Password with eye-toggle visibility icon.
  - "Forgot Password?" navigation text button.
  - Gradient "Sign In" pill button with loading spinner.
  - "Continue with Google" social login button.
  - Footer with "Don't have an account? Sign Up" navigation.
- **Providers & State:**
  - `authRepositoryProvider`: Implements `signIn(email, password)` and `signInWithGoogle()`.
  - Local state: `_loading`, `_passwordVisible`.
- **User Flows:**
  1. Student enters `@ewubd.edu` or personal email and password -> taps Sign In -> routes to `/`.
  2. Student taps Google Sign-In -> on Web, initiates Supabase OAuth redirect (`signInWithOAuth`), preserving callback URL.
- **Error Handling:** Validation errors displayed inline. Network/auth exceptions caught and translated into user-friendly snackbars via `AuthErrorUtils.getFriendlyMessage(e)`.

#### `register_screen.dart` (Student Registration)
- **Exact Purpose:** Registers new accounts, binding student ID, full name, nickname, and email credentials.
- **Visual Widgets:**
  - Frosted glass registration form with fields: Full Name, Student Nickname, Student ID (formatted as `YYYY-S-DD-NNN`), Student Email, Password, Confirm Password.
  - Verification dialog: `Verify Email` modal alert with cyan envelope icon.
- **Providers & State:** `authRepositoryProvider`, local form validation key `_formKey`.
- **User Flows:** User completes form -> taps "Create Account" -> Supabase registers user and fires email verification link -> popup instructs user to verify email before signing in.
- **Error Handling:** Password confirmation matching validator, duplicate email error catching, regex formatting on Student ID.

#### `forgot_password_screen.dart` & `reset_password_screen.dart` (Recovery)
- **Exact Purpose:** Facilitates self-service password recovery via 6-digit OTP sent to student email.
- **Visual Widgets:**
  - Step 1: Email entry field with "Send Recovery Code" button.
  - Step 2: 6-digit OTP code input and new password field.
- **Providers & State:** Direct Supabase Auth methods (`resetPasswordForEmail`, `verifyOTP`, `updateUser`).
- **User Flows:** Student requests OTP -> receives email -> inputs code with new password -> redirected to `/login`.
- **Error Handling:** Invalid OTP alerts, expired token notices, minimum 6-character password enforcement.

#### `ios_only_gate_screen.dart` (PWA Hardware & User Agent Gate)
- **Exact Purpose:** **CRITICAL PWA ARCHITECTURAL COMPONENT.** Restricts web usage strictly to Apple iOS / iPadOS Safari users (or authorized developer/QA bypasses), directing Android users to download the native Play Store app.
- **Why It Is Present:** Android devices have a dedicated, optimized native build (`com.rxxeron.ewumate`) with home screen widgets and background alarms. Apple iOS users do not have an App Store release; therefore, the PWA is exclusively crafted for Safari iOS. Allowing desktop or Android users into the web app without widgets degrades brand experience.
- **Visual Widgets:**
  - Glowing circular Apple icon badge (`Icons.apple_rounded`) with cyan/blue gradient and soft drop shadow.
  - Pill badge: "EXCLUSIVE FOR IOS & IPADOS".
  - Headline: "EWUmate Web Edition".
  - Explanatory copy clarifying that the web edition is tailored for Safari and iOS home-screen installation.
  - Android recommendation card (`GlassContainer` with green emerald accents, Android robot icon, and "Open on Google Play Store" button linking to `https://play.google.com/store/apps/details?id=com.rxxeron.ewumate`).
- **Providers, Interop & State:**
  - `pwaControllerProvider`: Reads `PwaState.hasAccess` (`isIOS || isBypassed`).
  - Calls `window.isIOSDevice()` via `dart:js_interop` inspecting `navigator.userAgent` (`/iPad|iPhone|iPod/`) and `navigator.maxTouchPoints > 1` on MacIntel (iPadOS).
  - Developer Bypass: Checks for query parameter `?rxxeron=true`. If found, writes `ewumate_rxxeron_bypass = true` to browser `localStorage` and unlocks the gate.
- **User Flows:**
  1. User visits `app.ewumate.pro.bd` on Chrome Android or Windows Desktop -> Router detects `!pwaState.hasAccess` -> redirects to `/ios-only`.
  2. If user is on iPhone or iPad Safari -> `hasAccess` is `true` -> gate passes automatically to `/`.
  3. If QA visits with `app.ewumate.pro.bd/?rxxeron=true` -> gate unlocks permanently for that browser.
- **Error Handling:** If user agent fails detection or changes dynamically, post-frame callback re-verifies `hasAccess` and forwards immediately.

---

### 2.3 Course Browser

#### `course_browser_screen.dart` (Universal Course Catalog)
- **Exact Purpose:** Searchable directory of all departmental university courses with prerequisites, credits, and section availability.
- **Visual Widgets:**
  - Top search bar with 400ms debounce and active cyan focus glow.
  - Department filter button opening filter bottom sheet (`_showFilterSheet`).
  - Semester Scope Switcher: Pill toggle for "Active Term" vs. "Upcoming Term".
  - Filter Tabs: Segmented chips for "Available" vs. "Taken" / "Upcoming Planned".
  - Infinite scroll `ListView` with skeleton loaders and course cards (`CourseCard`).
- **Providers & State:**
  - `courseBrowserTabProvider`: Active tab filter ('available', 'taken').
  - `selectedSemesterScopeProvider`: `SemesterScope.active` or `SemesterScope.upcoming`.
  - `courseSearchQueryProvider`: Search text query string.
  - `paginatedCoursesProvider`: StateNotifier managing infinite scroll and page chunking.
  - `userEnrollmentsProvider`: Identifies courses already taken by the student.
- **User Flows:** Student types "CSE115" -> debouncer fires search query -> catalog filters list -> student taps card to expand prerequisites, syllabus details, and enrolled sections.
- **Error Handling:** Infinite scroll bottom threshold listener detects end-of-scroll and requests next page. 3-minute periodic timer refreshes enrollment cache.

---

### 2.4 Dashboard

#### `dashboard_screen.dart` (Central Command Center)
- **Exact Purpose:** The main hub displaying today's classes, immediate next class, exam countdowns, overdue tasks, attendance alerts, and PWA installation prompts.
- **Visual Widgets:**
  - `DashboardHeader`: Displays student nickname, semester name, current date, and time-of-day vector animation (Sunrise, Sunny, Night).
  - `PwaInstallBanner`: Prompts installation when running in a browser tab.
  - `RemotePromoBanner`: Server-driven announcements from Supabase.
  - `PendingAttendanceWidget`: Alert prompting student to mark attendance for recently completed classes.
  - `DashboardOverdueCheckpoint`: Red alert card listing past-due assignments.
  - `DashboardScheduleTimeline`: Daily routine cards showing class time, room number, faculty initial, and quick attendance button.
  - `DashboardTasksPreview`: Upcoming assignments and quizzes with priority tags.
  - `DashboardExamTimeline`: Countdown dials to midterm and final examinations.
- **PWA Installation Banner Details (`pwa_install_banner.dart`):**
  - If `pwaState.isStandalone` is `true`, widget hides completely (`SizedBox.shrink()`).
  - On iOS Safari: Displays "Add EWUMate to Home Screen" with instruction: "Tap the Share icon (📤) in Safari and select 'Add to Home Screen' to install."
  - On Chromium browsers: Displays "Install" button invoking `ref.read(pwaControllerProvider.notifier).installApp()`.
- **Providers & State:**
  - `DashboardController`: Manages dashboard loading lifecycle, caching routines into IndexedDB, and handling silent background refreshes.
  - `fcmServiceProvider`: Checks for pending notification tap actions queued during startup.
- **User Flows:**
  1. Student opens app -> dashboard loads instantly from Hive cache while fetching fresh updates.
  2. Next class is active -> student taps "Mark Attendance" -> attendance is recorded and synced.
  3. Student taps an upcoming task -> modal sheet opens `AddTaskBottomSheet` for inline editing.
- **Error Handling:** 5-minute silent refresh timer prevents UI disruption. Post-frame initialization safeguards ensure pending FCM notifications trigger dialogs only after widget stability.

---

### 2.5 Faculty Directory

#### `faculty_directory_screen.dart` (Faculty Directory)
- **Exact Purpose:** Searchable directory of all EWU faculty members, designations, emails, and room numbers.
- **Visual Widgets:**
  - Search field with real-time focus glow and 400ms debounced input.
  - Department horizontal pill list: All, CSE, BUS, ENG, EEE, MATH, LAW, PHR.
  - Faculty list displaying avatar, full name, initials, designation, department, and rating badge.
- **Providers & State:**
  - `facultyDirectoryProvider`: AsyncValue list of all faculty members.
  - `facultySearchQueryProvider`: Search query filter.
  - `facultyDepartmentFilterProvider`: Selected department code.
- **User Flows:** Student selects "CSE", types faculty initials (e.g., "MSR") -> directory filters list -> student taps faculty card to open `FacultyDetailsScreen`.
- **Error Handling:** Skeleton loaders displayed during initial fetch. Empty state primitive shown if no matching faculty found.

#### `faculty_details_screen.dart` (Faculty Profile & Office Hours)
- **Exact Purpose:** Deep dive into a faculty member's profile, approved office hours, courses taught, and student reviews.
- **Visual Widgets:**
  - `FacultyHeroCard`: Large avatar, name, designation, department, and contact actions.
  - 5-Tab Bar:
    1. `FacultyAboutTab`: Academic background and bio.
    2. `FacultyCoursesTab`: Sections taught in current and upcoming semesters.
    3. `FacultyOfficeHoursTab`: Weekly office hours table with day, time, and room.
    4. `FacultyReviewsTab`: Student community reviews and ratings.
    5. `FacultyContactTab`: Official email and office room number.
  - `FacultyBottomBar`: Action buttons to copy email, send email, or submit new office hours.
- **Providers & State:**
  - `approvedOfficeHoursProvider.family(initials)`: Fetches verified office hours for active semester.
  - `academicStateProvider`: Provides current semester context.
- **User Flows:** Student views office hours -> taps "Copy Email" -> floating snackbar confirms clipboard copy -> taps "Submit Office Hours" -> opens submission sheet.
- **Error Handling:** Haptic feedback on copy events. Fallback display when office hours are unverified.

---

### 2.6 Layout & Navigation Shell

#### `main_layout_screen.dart` (Legacy 5-Tab Shell)
- **Exact Purpose:** Fallback tab shell used in standalone web previews.
- **Visual Widgets:** Standard Material 3 `NavigationBar` with icons for Home, Tasks, Progress, Schedule, and Services.
- **Providers & State:** Calculates selected index from current `GoRouterState` URI path.

#### `main_shell.dart` (Production Navigation Shell)
- **Exact Purpose:** Root shell wrapping all primary application tabs inside GoRouter `ShellRoute`.
- **Visual Widgets:**
  - `FullGradientScaffold`: Immersive dark blue/cyan background.
  - `AnimatedSwitcher`: Smooth 250ms cross-fade transition between tabs.
  - `AppDrawer`: Side navigation drawer containing secondary features (Profile, Course Browser, Portal Sync, Feedback, Tutorials).
  - `EwuFloatingNavBar`: Custom floating glass navigation bar positioned above bottom edge with 5 pill items: Home (`/dashboard`), Tasks (`/tasks`), Progress (`/semester-progress`), Schedule (`/schedule-manager`), and Services (`/services`).
- **Providers & State:**
  - `requiresGradeEntryProvider`: Listens for semester conclusion. If grades are pending, automatically intercepts navigation and redirects to `/results/grade-entry`.
  - `scaffoldKeyProvider`: Exposes scaffold state for drawer opening.
- **User Flows:** Student taps bottom nav item -> `context.go()` switches child route -> floating pill updates active glow indicator.

---

### 2.7 Notifications & Reminders

#### `notifications_screen.dart` (Notification Center)
- **Exact Purpose:** Chronological feed of push notifications, announcements, class reminders, and administrative alerts.
- **Visual Widgets:**
  - Web permission banner: Displays warning when browser notifications are blocked with an "Enable" trigger button.
  - Category filter chips: "All", "Unread", "Schedule", "Tasks", "System".
  - Notification items with timestamp, read/unread glow pill, optional network image preview, and deep link button.
  - Swipe-to-delete action dismissing items from local IndexedDB cache.
- **Providers & State:**
  - `userNotificationsProvider`: Fetches cached notifications from Hive `notifications_box` and syncs with Supabase.
  - `fcmServiceProvider`: Provides permission status and registration.
- **User Flows:** Student views notifications -> taps a notification containing a URL -> `fcmService._navigateToUrl()` routes directly to target screen.
- **Error Handling:** Graceful image failure using `CachedNetworkImage` error widget. Pull-to-refresh invalidates cache.

#### `reminder_settings_screen.dart` (Per-Course Notification Customizer)
- **Exact Purpose:** Allows students to customize advance reminder intervals (offsets) for their classes.
- **Visual Widgets:**
  - Active semester courses list.
  - Offset chip selector: Allows picking 10 min, 15 min, 30 min, 45 min, 1 hour, or custom duration before class starts.
  - "Schedule Preview" action opening preview bottom sheet.
  - Global notification toggles (task reminders, exam reminders, campus announcements).
- **Providers & State:**
  - `academicStateProvider`: Resolves current semester code.
  - `userProfileProvider`: Student settings and track.
  - Supabase `user_semester_states`: Reads `weekly_grid_cache` to find enrolled course schedule times.
- **User Flows:** Student selects CSE115 -> adds 45-minute reminder offset -> saves settings -> Cloud function schedules Web Push notifications accordingly.
- **Error Handling:** Fallback lookup against `enrollments` table if `weekly_grid_cache` is empty.

---

### 2.8 Onboarding Flow

#### `profile_setup_screen.dart` (Identity Setup)
- **Exact Purpose:** First step in user onboarding. Captures student avatar, full name, nickname, and student ID.
- **Visual Widgets:**
  - Circular avatar picker with camera overlay icon.
  - Full Name, Nickname, and Student ID input fields.
  - "Continue" gradient button with loading state.
- **Providers & State:** `StorageService` for profile picture uploads, `OnboardingRepository`.
- **User Flows:** Student picks avatar from gallery -> `ImagePicker.pickImage` captures bytes -> student fills form -> avatar uploaded as binary to Supabase `avatars` bucket -> profile saved -> navigates to `/onboarding/program`.
- **Error Handling:** Byte size check on image, mandatory field validation.

#### `program_selection_screen.dart` (Academic Program & Batch)
- **Exact Purpose:** Second onboarding step. Configures student degree program, department, track, and admitted semester.
- **Visual Widgets:**
  - Department accordion selector (CSE, BBA, English, EEE, Pharmacy, Law, etc.).
  - Program cards displaying program name, code, and track badge (Bi-Semester vs Tri-Semester).
  - Admitted semester dropdown list (e.g., "Spring 2024", "Summer 2025").
  - Onboarding step overlay tooltip.
- **Providers & State:** `onboardingRepositoryProvider`: Fetches departments, programs, and available semesters.
- **User Flows:** Student chooses "B.Sc. in CSE" -> selects admitted semester -> saves selection -> navigates to `/onboarding/course-history`.
- **Error Handling:** Prevents submission until both program and admitted semester are selected.

#### `course_history_screen.dart` (Transcript & Completed Courses Importer)
- **Exact Purpose:** Third onboarding step (and editable later via Degree Progress). Imports past completed courses with grades to compute initial CGPA.
- **Visual Widgets:**
  - Top header card with earned credits counter and live calculated CGPA.
  - Semester selector tabs (Spring, Summer, Fall across academic years).
  - Course search bar and catalog list.
  - Grade selector modal dialog (`CourseHistoryGradeDialog`) with official letter grades (A+, A, A-, B+, B, B-, C+, C, C-, D, F).
  - Full-screen sync overlay (`CourseHistorySyncOverlay`) during database persistence.
- **Providers & State:** `onboardingRepositoryProvider`: Fetches course catalogs, saves completed courses to `enrollments` table with status `completed`.
- **User Flows:** Student selects past semester -> adds completed courses with grades -> header updates CGPA -> taps "Finish" -> records saved -> routes to `/onboarding/welcome-tour`.
- **Error Handling:** Optimistic local state updates with rollback on network failure.

#### `welcome_tour_screen.dart` (Interactive Product Tour)
- **Exact Purpose:** Final onboarding step. Introduces key features through an interactive 4-slide carousel before the user enters the dashboard.
- **Visual Widgets:**
  - `PageView` with smooth animated transitions.
  - Slide cards featuring illustrations, titles, and descriptions (Routine Manager, Attendance & Marks, Grade Tracker, Services).
  - Pulsing page dot indicators.
  - "Next" / "Get Started" gradient action button.
- **Providers & State:** `TutorialService`: Persists completion flag `welcome_tour_completed` to local cache.
- **User Flows:** Student swipes through 4 slides -> taps "Get Started" -> `TutorialService.markAsSeen()` commits flag -> routes to `/dashboard`.
- **Error Handling:** Guaranteed navigation to `/dashboard` even if cache write fails.

#### `onboarding_screen.dart` (Legacy Monolithic Setup)
- **Exact Purpose:** Preserved fallback screen combining profile, program, and track inputs in a single view for low-bandwidth connections.
- **Visual Widgets:** Single scrollable glass card with all profile and academic dropdown fields.
- **Providers & State:** `profileRepositoryProvider`.

---

### 2.9 User Profile & Community

#### `profile_screen.dart` (Account & App Management)
- **Exact Purpose:** Profile overview, academic status, cache diagnostics, and sign-out hub.
- **Visual Widgets:**
  - Avatar display with edit badge.
  - Student identity card (Name, Nickname, ID, Program, Track, CGPA, Credits).
  - Account actions: Edit Profile, Change Password, Notification Settings.
  - Diagnostics section: Clear Local Cache, App Version info, Build Number.
  - "Sign Out" red button with confirmation dialog.
- **Providers & State:** `profileRepositoryProvider`, `authRepositoryProvider`, `cacheServiceProvider`.
- **User Flows:** Student updates avatar or views student ID -> taps "Sign Out" -> Hive boxes and Supabase session cleared -> redirected to `/login`.
- **Error Handling:** Confirmation dialog prevents accidental sign-outs.

#### `feedback_screen.dart` (Student Feedback & Support Tickets)
- **Exact Purpose:** Two-way feedback portal enabling students to submit bug reports and feature requests, and view replies from developers.
- **Visual Widgets:**
  - 2-Tab bar: "Submit Feedback" and "My Feedback".
  - Category dropdown (Bug Report, Feature Request, Question, Other).
  - Multi-line text field for message.
  - App version metadata banner (`PackageInfo`).
  - Threaded conversation list showing developer replies with admin badges.
- **Providers & State:** Direct Supabase table operations on `feedbacks` and `feedback_replies`.
- **User Flows:** Student submits issue -> switch to "My Feedback" tab -> views real-time replies from admin.
- **Error Handling:** Empty message validation, automated attachment of device/browser metadata.

#### `support_developer_screen.dart` (Developer Support & Contributions)
- **Exact Purpose:** Allows students to support project hosting costs via voluntary contributions (bKash/Nagad).
- **Visual Widgets:**
  - Developer story and server cost transparency cards.
  - Payment method selector (bKash, Nagad).
  - One-tap clipboard copy buttons for merchant numbers.
  - Contribution submission form: Transaction ID (TrxID), Sender Number, Amount, and screenshot upload via `ImagePicker`.
- **Providers & State:** Supabase `donations` table, `StorageService`.
- **User Flows:** Student sends bKash -> copies TrxID -> enters details and uploads receipt -> receives confirmation snackbar.
- **Error Handling:** Validation on transaction ID and numeric amount.

---

### 2.10 Progress Tracking

#### `progress_screen.dart` (Semester Marks Hub)
- **Exact Purpose:** High-level list of currently enrolled courses showing total marks obtained and grading distribution.
- **Visual Widgets:**
  - List of course cards with course code, section, and credit count.
  - Circular progress ring indicating percentage of total coursework graded.
  - Tap action navigating to `CourseMarksEditorScreen`.
- **Providers & State:** `currentSemesterMarksProvider`: Reads marks records for the active term.
- **User Flows:** Student opens Progress -> sees courses -> taps CSE225 -> opens detailed editor.
- **Error Handling:** Displays `ewu_empty_state.dart` if no courses are currently enrolled.

#### `course_marks_editor_screen.dart` (Assessment Breakdown Editor)
- **Exact Purpose:** Fine-grained entry form for marks across Midterm, Final, Quizzes, Assignments, Presentations, Attendance, and Lab.
- **Visual Widgets:**
  - 2-Tab bar: "Distribution" (Syllabus weightings, e.g. Mid = 25%) and "Obtained Marks" (e.g. Scored 22/25).
  - Text controllers for each category with numeric keyboard input.
  - Real-time aggregate calculation card displaying projected total and predicted letter grade.
  - "Save Marks" floating button.
- **Providers & State:** `progressRepositoryProvider`, `semesterProgressRepositoryProvider`.
- **User Flows:** Student enters quiz scores -> projected mark updates immediately -> student taps Save -> persisted locally and queued for Supabase sync.
- **Error Handling:** Validation ensures distribution weights total 100%.

---

### 2.11 Results & Grade Management

#### `results_screen.dart` (Academic Transcript & History)
- **Exact Purpose:** Complete academic record displaying semester-by-semester SGPA, cumulative CGPA, and course grades.
- **Visual Widgets:**
  - Cumulative CGPA hero banner with credit summary.
  - Expandable accordion tiles for each semester (e.g., "Fall 2024 - GPA: 3.85").
  - Table of courses per semester: Course Code, Course Title, Credits, Grade Point, Letter Grade.
- **Providers & State:** `allSemesterSummariesProvider`, `profileRepositoryProvider`.
- **User Flows:** Student reviews past academic performance across semesters.
- **Error Handling:** Pull-to-refresh invalidates cache and queries fresh summary records.

#### `grade_entry_screen.dart` (Mandatory Semester-End Grade Blocker)
- **Exact Purpose:** **CRITICAL SYSTEM COMPONENT.** When a semester ends and grades are published, this screen acts as a navigation blocker, forcing students to input their official letter grades for enrolled courses before accessing the rest of the application.
- **Visual Widgets:**
  - Warning banner explaining that final grades must be logged to finalize degree calculations.
  - List of unfinalized enrolled courses.
  - Letter grade dropdown selector for each course (A+, A, A-, B+, B, B-, C+, C, C-, D, F, W).
  - "Submit Grades" gradient button.
- **Providers & State:**
  - `pendingGradesProvider`: Queries enrollments where `status == 'enrolled'` and `grade == null` for completed semesters.
  - Checks `active_semester.grade_submission_start` to determine Phase 1 (optional entry) vs Phase 2 (mandatory blocker).
- **User Flows:** Student opens app -> `MainShell` intercepts route because `requiresGradeEntryProvider == true` -> redirects to `/results/grade-entry` -> student selects grades -> status updated to `completed` -> blocker clears -> dashboard unlocks.
- **Error Handling:** Prevents submission until every listed course has a selected grade.

---

### 2.12 Class & Exam Schedule

#### `schedule_screen.dart` (Rolling Routine & Calendar)
- **Exact Purpose:** Interactive weekly routine tracker managing 2-week class schedules, day switching, and manual class entries.
- **Visual Widgets:**
  - Horizontal day selector bar (`ScheduleDaySelector`) with dates and weekday labels.
  - 3-Tab bar: "Upcoming", "Past", "Pending Events" (midterms, quizzes, makeup classes).
  - Class cards displaying course code, section, time range, room, faculty, and attendance status.
  - Floating action button to add extra/makeup class via `AddManualClassSheet`.
- **Providers & State:**
  - `scheduleRepositoryProvider`, `dashboardRepositoryProvider`.
  - Supabase `user_semester_states`: Reads `weekly_grid_cache`.
- **User Flows:** Student taps "Wednesday" -> schedule renders Wednesday's classes -> student taps "Add Makeup Class" -> fills modal sheet -> makeup class appended to schedule.
- **Error Handling:** 3-minute periodic sync refreshes schedule cache. Fallback display when no classes scheduled on weekends.

---

### 2.13 Semester Progress & Academic Analytics

#### `semester_progress_screen.dart` (Coursework & Attendance Dashboard)
- **Exact Purpose:** High-level dashboard for active coursework tracking overall attendance percentages and aggregate assessment marks.
- **Visual Widgets:**
  - Course cards with attendance progress rings (e.g. 85% attendance, 10/12 classes attended).
  - Assessment progress bars showing marks earned to date.
  - Target grade simulator launcher.
- **Providers & State:** `semesterProgressRepositoryProvider`, offline sync queue heartbeat running every 2 minutes (`_pushSyncQueue`).
- **User Flows:** Student views course progress card -> taps card -> navigates to `CourseProgressDetailScreen`.
- **Error Handling:** Offline mutations are queued in IndexedDB and drained automatically when connectivity returns.

#### `course_progress_detail_screen.dart` (Course Deep Dive)
- **Exact Purpose:** Comprehensive attendance calendar and marks management for a single enrolled course.
- **Visual Widgets:**
  - 3-Tab bar:
    1. `AttendanceSessionsTab`: Interactive calendar listing every class date with 4 status options: Present, Absent, Late, Cancelled.
    2. `CourseMarksInputTab`: Form to update exam and quiz scores.
    3. `CourseOutlineSetupTab`: Course syllabus weight editor.
- **Providers & State:** `CourseMarksController`, `AttendanceCalendarService`.
- **User Flows:** Student attends class -> opens Attendance tab -> marks date as "Present" -> attendance percentage recalculates.
- **Error Handling:** Autosave state persistence with debounce.

#### `semester_summary_screen.dart` (CGPA Planner & Scholarship Predictor)
- **Exact Purpose:** Long-term academic strategy screen featuring CGPA projections, scholarship qualification checks, and grading scale reference.
- **Visual Widgets:**
  - 4-Tab bar:
    1. "Overview": `CgpaHeroDialCard` (gauge displaying current CGPA), `GradeDistributionChart` (bar chart of earned A's, B's, etc.), and `AcademicYearsTimeline`.
    2. "Scholarships": `ScholarshipSelectorCard` checking eligibility for EWU Merit Scholarships (top 10% per department, minimum CGPA 3.75) and Medals (`AwardsStatusCard`).
    3. "CGPA Planner": `GoalInputGrid` allowing students to simulate target semester GPAs to compute resulting graduation CGPA.
    4. "Grading Policy": `GradeScaleReferenceCard` showing the official East West University letter-grade to grade-point conversion table.
- **Providers & State:** `semesterSummaryProviders`, `allSemesterSummariesProvider`, `scholarshipRulesProvider`.
- **User Flows:** Student wants to know what GPA is needed next term to reach 3.80 -> enters 3.80 goal into simulator -> planner computes required GPA.
- **Error Handling:** Safe clamp functions prevent mathematical division-by-zero on zero credit hours.

---

### 2.14 Student Services & Academic Tools

#### `services_screen.dart` (Services Hub)
- **Exact Purpose:** Grid launcher connecting students to ancillary academic utilities.
- **Visual Widgets:** Bento card grid with icons, subtitles, and badges for Cover Page Generator, Faculty Directory, Study Materials Vault, EWU Portal Sync, Faculty Assignment, and Faculty List PDF.
- **User Flows:** Student taps a service tile -> `context.go()` navigates to the respective tool route.

#### `cover_page_screen.dart` (Assignment Cover Page Generator)
- **Exact Purpose:** Generates professionally formatted East West University cover page PDFs for individual and group assignments.
- **Visual Widgets:**
  - Template selector: Assignment, Lab Report, Project Proposal, Group Report.
  - Academic metadata form: Course Title, Course Code, Section, Department, Topic Title, Teacher Name, Designation.
  - Dynamic student list: Add up to 4 group members with Name, Student ID, and Department.
  - "Generate PDF" gradient action button with loading spinner.
- **Web-Specific Download Adaptation:**
  - Sends payload to Azure Function `$baseUrl/api/generate_pdf`.
  - On 200 response, captures in-memory `Uint8List` bytes.
  - Injects browser DOM `html.Blob([bytes], 'application/pdf')` and triggers `html.AnchorElement(download: fileName).click()`.
- **Error Handling:** Retries network request twice with backoff on connection timeout. Form validation ensures required course codes and teacher designations are specified.

#### `faculty_assignment_screen.dart` (Crowdsourced Faculty Verification)
- **Exact Purpose:** Community platform enabling students to crowdsource and verify which teachers are teaching specific course sections each semester.
- **Visual Widgets:**
  - 2-Step stepper: Step 1 (Assign Courses) -> Step 2 (Upload Proof).
  - Searchable course and faculty selector dropdowns.
  - Section number and session type (Theory / Lab) toggles.
  - File picker attaching proof of assignment (portal screenshot or syllabus PDF).
- **Providers & State:** `FacultyAssignmentRepository`, `academicStateProvider`.
- **User Flows:** Student selects course section and teacher -> attaches verification screenshot -> submits for community approval.
- **Error Handling:** Restricts upload file types to image/PDF formats; catches upload failures gracefully.

#### `faculty_list_screen.dart` (Official Faculty Document Viewer)
- **Exact Purpose:** Displays official departmental faculty PDF sheets and direct links to university Google Drive document repositories.
- **Visual Widgets:**
  - Google Drive card with direct launch button to official repository folder.
  - Departmental snapshot cards with semester filters and PDF download triggers.
- **User Flows:** Student taps Google Drive folder card -> opens official drive folder in external browser tab via `url_launcher`.

#### `portal_sync_screen.dart` (EWU Student Portal Scraper)
- **Exact Purpose:** Automated 7-step wizard that connects to the official EWU student portal, scrapes enrolled courses, routine schedules, and grades, and populates the app database.
- **Visual Widgets:**
  - Step 1 (`PortalSyncStartView`): Student ID and Portal Password inputs with "Remember Credentials" checkbox.
  - Step 2 & 3 (`PortalSyncConnectingView`): Animated progress checklist tracking connection, authentication, routine scraping, and grade parsing.
  - Step 4 (`PortalSyncReadyView`): Confirmation that scraper extracted all data.
  - Step 5 (`PortalSyncPreviewView`): Review screen showing extracted courses and weekly schedule before applying changes.
  - Step 6 (`PortalSyncSyncingView`): Database commit animation.
  - Step 7 (`PortalSyncCompleteView`): Success summary with link to Dashboard.
- **Providers & State:** `portalSyncRepositoryProvider`, `PortalService`, Azure Function scraper endpoint.
- **User Flows:** Student enters portal credentials -> Azure scraper logs into EWU portal -> parses HTML tables -> previews extracted courses -> confirms sync -> Supabase database updated.
- **Error Handling:** Catches invalid portal password, portal server maintenance downtime, or captcha failures with descriptive error dialogs.

---

### 2.15 Study Vault (Past Papers & Resources)

#### `study_vault_screen.dart` (Academic Resource Library)
- **Exact Purpose:** Community-driven repository of past midterm papers, final exam questions, slides, sample code, and lab manuals.
- **Visual Widgets:**
  - Search bar with minimum 3-character threshold and debouncer.
  - Department filter chips (CSE, BUS, ENG, EEE, MATH, LAW, PHR).
  - Material category chips (Mid Questions, Final Questions, Slides, Lab Manual, Book, Notes).
  - Material card with file type icon, file size, uploader nickname, download count, and download button.
  - Floating Action Button: "Upload Material".
- **Providers & State:** `studyVaultRepositoryProvider`, `studyVaultMaterialsProvider`.
- **User Flows:** Student searches "CSE225 Mid" -> filters list -> taps download -> document opens via external browser URL.
- **Error Handling:** Paginated bottom sheet avoids memory bloat on large result sets.

#### `my_study_materials_screen.dart` (User Uploads Manager)
- **Exact Purpose:** Allows students to view, track, and manage documents they have contributed to the Study Vault.
- **Visual Widgets:**
  - List of user-uploaded files with upload date, file size, category badge, and download statistics.
  - Delete / Removal Request button opening `DeleteMaterialSheet`.
- **Providers & State:** `myStudyMaterialsProvider`, `studyVaultRepositoryProvider`.
- **User Flows:** Student selects uploaded document -> taps delete -> confirms action -> file removed from Supabase storage bucket.
- **Error Handling:** Safe deletion verification sheet preventing accidental removals.

#### `upload_study_material_screen.dart` (Resource Contributor)
- **Exact Purpose:** Upload interface for contributing study materials to the university vault.
- **Visual Widgets:**
  - Multi-file picker button (`FilePicker.platform.pickFiles`).
  - Selected files tray with file-type dropdown per file (e.g. labeling File 1 as "Mid Question" and File 2 as "Course Outline").
  - Course autocomplete selector, Faculty Initial picker, Semester dropdown.
  - Progress bar during binary file upload.
- **Providers & State:** `studyVaultRepositoryProvider`, Supabase storage bucket `study-vault`.
- **User Flows:** Student picks PDF files -> tags with Course and Faculty -> taps "Upload" -> files uploaded as binary `Uint8List` to Supabase -> metadata row created in `study_materials` table.
- **Error Handling:** 25MB file size limit enforced client-side before upload; invalid MIME types blocked.

---

### 2.16 Tasks & Deadlines

#### `tasks_screen.dart` (Academic Task Manager)
- **Exact Purpose:** Personal organizer tracking assignments, quizzes, lab submissions, and term projects with deadline alerts and offline sync.
- **Visual Widgets:**
  - 3-Tab bar: "Pending", "Completed", "Overdue".
  - Horizontal category filter pills: "All", "Quiz", "Lab", "Assignment", "Project".
  - Task cards displaying title, course code, due date, countdown tag, and priority indicator.
  - Swipe-to-complete and tap-to-edit actions.
  - Floating Action Button to add new task.
- **Providers & State:**
  - `allTasksStreamProvider`: Real-time stream of student tasks.
  - `taskRepositoryProvider`: CRUD operations on tasks.
  - `cacheServiceProvider`: Manages offline task mutation queue in IndexedDB.
  - Heartbeat timer running every 2 minutes (`_pushSyncQueue`).
- **User Flows:**
  1. Student taps FAB -> opens `AddTaskBottomSheet` -> enters "Quiz 2 on Trees" for CSE225 due tomorrow -> saves task.
  2. If student is offline -> task is saved immediately to local IndexedDB and enqueued in `sync_queue_box`.
  3. When browser reconnects -> `_pushSyncQueue()` drains queue and upserts tasks to Supabase.
- **Error Handling:** Optimistic UI state updates ensure no lag. Failed network mutations retry automatically.

---

### 2.17 Tutorials & Guided Walkthroughs

#### `tutorials_screen.dart` (Video Tutorials & Help Center)
- **Exact Purpose:** Comprehensive video tutorial library guiding students through routine imports, CGPA calculation, advising simulation, and portal sync.
- **Visual Widgets:**
  - Video tutorial cards with thumbnail previews, titles, durations, and play buttons.
  - Top action icon: "Replay Welcome Tour" (opens `/onboarding/welcome-tour`).
- **Providers & State:** `tutorialsRepositoryProvider`: Fetches tutorial video links and metadata.
- **User Flows:** Student taps a tutorial card -> launches official instructional video via YouTube / browser video player (`url_launcher`).
- **Error Handling:** Empty state and network retry actions if video metadata fails to load.

---

## 3. Mobile vs. PWA Architectural Divergence & Web Adaptations

Because Flutter Web runs within a browser sandbox, native mobile OS capabilities (file-system paths, background alarm services, hardware screenshot prevention) do not exist. `ewumate_pwa` implements specific architectural adaptations:

```
+--------------------------------------------------------------------------------------------------+
|                                    PLATFORM ADAPTATION MATRIX                                    |
+------------------------------+----------------------------------+--------------------------------+
| Capability                   | Native Mobile (`ewumate_prod`)   | Web / PWA (`ewumate_pwa`)      |
+------------------------------+----------------------------------+--------------------------------+
| Local Persistence            | SQLite + Hive file-system        | Hive backed by IndexedDB       |
| Push Notifications           | FCM Background Service + Alarms  | Web Push API via VAPID SW      |
| PDF Export & Viewing         | File-path write + OpenFilex      | In-memory Uint8List Blob + URL |
| File / Photo Picking         | File paths via ImagePicker       | In-memory Uint8List bytes      |
| Screenshot Protection        | Hardware FLAG_SECURE             | Conditional safe no-op         |
| URL Routing                  | In-memory Navigator Stack        | pathUrlStrategy (Clean URLs)   |
| Bootup Error Handling        | Native Crashlytics               | Midnight Navy Error Scaffold   |
+------------------------------+----------------------------------+--------------------------------+
```

### 3.1 Storage Layer: IndexedDB (Hive) vs. Native SQLite / File System
- **Native Mobile:** Writes database files (`.hive`, `.db`) directly to the application support directory via `path_provider` and `dart:io`.
- **PWA Adaptation:** On Flutter Web, `path_provider` cannot access local disk paths. `CacheService` initializes Hive via `Hive.initFlutter()`, which automatically maps all Hive boxes (`profile_box`, `dashboard_box`, `schedule_box`, `sync_queue_box`, `semester_progress_box`, `notifications_box`, `routine_cache_box`, `auth_box`) directly to the browser's **IndexedDB** storage engine.
- **Zero-Wait Entry Pattern:** During cold boot, `CheckAuthScreen` reads the cached user identity (`last_user_id`) synchronously from IndexedDB, displaying student routines without blocking on network roundtrips.

### 3.2 Push Notifications: Web Push API (VAPID) vs. Android Native FCM
- **Native Mobile:** Relies on native Google Play Services, the Android FCM SDK, and system-level `NotificationManager` channels.
- **PWA Adaptation:**
  1. Utilizes the **Web Push API** requiring an explicit VAPID public key:  
     `BO0Po4qenG7jOO_N-TIl1Ers3m46ehFoPthGQJ__Wxz9hjfuNtLNu6lqDsM_Cndjw6AADbo_x-E4K3Nu9mr_dI8`.
  2. Subscribes the browser via `FirebaseMessaging.instance.getToken(vapidKey: ...)`.
  3. Registers `firebase-messaging-sw.js` under the dedicated scope `/firebase-cloud-messaging-push-scope`.
  4. In iOS Safari PWAs, push notifications require an explicit user gesture (button tap); auto-prompting on initial load is blocked by Apple. The app exposes `fcmService.requestPermissionAndRegister()` on interactive banners.
  5. Foreground messages on Web do not trigger OS banners; instead, `FCMService.showNotificationPopup()` renders a glassmorphic dialog in-app.

### 3.3 File System & PDF Handling: Blob Object URLs vs. `dart:io` Path Writing
- **Native Mobile:** Generates PDF, writes binary data to `${tempDir.path}/report.pdf`, and launches a native PDF viewer intent using `OpenFilex.open()`.
- **PWA Adaptation:** The `dart:io` library throws runtime exceptions on web. `ewumate_pwa` implements conditional export architecture:
  ```dart
  // core/utils/pdf_saver.dart
  export 'pdf_saver_stub.dart'
    if (dart.library.html) 'pdf_saver_web.dart'
    if (dart.library.io) 'pdf_saver_mobile.dart';
  ```
  In `pdf_saver_web.dart`, binary bytes are wrapped in a browser `Blob`, transformed into an Object URL, attached to a virtual DOM `<a>` tag, and triggered via `.click()`:
  ```dart
  Future<void> saveAndOpenPdf(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
  ```

### 3.4 Media & Camera Handling: Browser File Picker vs. Native Image Picker
- **Native Mobile:** Takes photos using the camera hardware or queries the device gallery, referencing images via absolute disk paths (`/data/user/0/.../image.jpg`).
- **PWA Adaptation:** Browser security prohibits absolute local file paths. Avatar and receipt pickers in `ProfileSetupScreen`, `SupportDeveloperScreen`, and `UploadStudyMaterialScreen` call `pickedFile.readAsBytes()` to extract in-memory `Uint8List` buffers. Uploads to Supabase storage use `storage.from(...).uploadBinary(path, bytes)`.

### 3.5 Screen Protection: Conditional Safe No-Op vs. Hardware `FLAG_SECURE`
- **Native Mobile:** Uses Android WindowManager `FLAG_SECURE` to block OS screenshots during pre-advising generation.
- **PWA Adaptation:** Web standards do not provide APIs to block OS or browser screenshot shortcuts (e.g. `Win+Shift+S` or `Cmd+Shift+4`). `ScreenProtectionService` conditionally detects web environments (`kIsWeb`) and converts security calls into safe no-ops, preventing application crashes.

---

## 4. PWA Web Assets, Manifest & Service Worker Engineering

### 4.1 Web App Manifest (`web/manifest.json`)
The web manifest configures application identity and home screen integration:

```json
{
    "name": "EWUmate",
    "short_name": "EWUmate",
    "id": "/",
    "start_url": ".",
    "display": "standalone",
    "display_override": ["window-controls-overlay", "standalone", "minimal-ui"],
    "background_color": "#0F172A",
    "theme_color": "#0F172A",
    "description": "Premium Mobile Assistant for East West University Students",
    "orientation": "portrait-primary",
    "categories": ["education", "productivity", "utilities"],
    "prefer_related_applications": false,
    "icons": [
        { "src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png" },
        { "src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png" },
        { "src": "icons/Icon-maskable-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
        { "src": "icons/Icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
    ],
    "shortcuts": [
        { "name": "Class Routine", "short_name": "Routine", "description": "View your schedule and routine", "url": "./#/schedule-manager", "icons": [{ "src": "icons/Icon-192.png", "sizes": "192x192" }] },
        { "name": "Marks Tracker", "short_name": "Marks", "description": "Check and log academic progress", "url": "./#/semester-progress", "icons": [{ "src": "icons/Icon-192.png", "sizes": "192x192" }] },
        { "name": "My Tasks", "short_name": "Tasks", "description": "Manage assignments and reminders", "url": "./#/tasks", "icons": [{ "src": "icons/Icon-192.png", "sizes": "192x192" }] }
    ]
}
```

- **Display Modes:** Configured to `standalone` with `display_override: ["window-controls-overlay", "standalone", "minimal-ui"]` to hide browser navigation bars and display edge-to-edge.
- **Orientation:** Locked to `portrait-primary` matching mobile ergonomics.
- **App Shortcuts:** Enables instant launcher shortcuts on Android home screen long-press (Routine, Marks, Tasks).

### 4.2 Web Bootstrap & Preloader (`web/index.html`)
The HTML shell coordinates the JavaScript bridge with Dart:
- **iOS Web Clip Meta Tags:**
  ```html
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="EWUmate">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  ```
- **JavaScript PWA Interop Bridge:**
  - `window.deferredPrompt`: Captures the browser's `beforeinstallprompt` event so Dart can trigger it on demand.
  - `window.isPWAInstallable()`: Returns whether the installation prompt is ready.
  - `window.isPWAStandalone()`: Evaluates `window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true`.
  - `window.isIOSDevice()`: Performs regex inspection on `navigator.userAgent` (`/iPad|iPhone|iPod/`) and checks touch capability on macOS devices.
  - `window.triggerPWAInstall()`: Executes `.prompt()` on the stored event and returns the user's decision.
- **SPA Routing Redirect Engine:** For direct navigation to deep URLs (e.g. `app.ewumate.pro.bd/schedule-manager`), a lightweight inline redirect script intercepts 404s and routes paths cleanly into Flutter's router without hash collisions.

### 4.3 Firebase Messaging Service Worker (`web/firebase-messaging-sw.js`)
Handles background push notifications when the PWA is minimized or closed:
1. Imports Firebase 10.7.1 compatibility scripts from Google's static CDN.
2. Initializes Firebase credentials for project `ewumatefcm`.
3. Intercepts `onBackgroundMessage(payload)`:
   - Extracts notification title, body, icon (`/icons/Icon-192.png`), and optional rich images.
   - Dispatches `self.registration.showNotification(title, options)`.
4. Handles `notificationclick`:
   - Closes notification banner.
   - Extracts payload parameters (`notif_title`, `notif_body`, `notif_url`, `notif_image`).
   - Appends parameters to root URL: `/?notif_title=...&notif_url=...`.
   - Iterates open browser windows via `clients.matchAll({ type: 'window' })`. If found, navigates and focuses the existing window; otherwise launches `clients.openWindow(targetUrl)`.
5. Lifecycle Management: Uses `self.skipWaiting()` on install and `clients.claim()` on activate to ensure background workers take effect without browser restarts.

### 4.4 Service Worker Update Cycle & Dynamic Reloading
- The Flutter service worker caches application scripts and WebAssembly/CanvasKit binaries.
- When a new build is deployed, `index.html` detects the updated worker via `reg.addEventListener('updatefound')`.
- When the worker state reaches `installed`, it calls `window.onServiceWorkerUpdateCallback()`.
- `UpdateService` in Dart (`core/services/update_service.dart`) receives this callback and renders a floating `SnackBar` with a gold **"RELOAD"** button.
- Tapping **RELOAD** triggers `window.location.reload()`, clearing stale assets and running the latest release.

### 4.5 iOS Safari Web Clip & Media Splash Screen Matrix
To eliminate white flashes during standalone iOS startup, `index.html` embeds device-pixel-ratio media queries linking high-resolution splash images:
- **iPhone 15 Pro Max, 14 Pro Max:** `media="(device-width: 430px) and (device-height: 932px) and (-webkit-device-pixel-ratio: 3) and (prefers-color-scheme: dark)"`
- **iPhone 15 Pro, 15, 14 Pro:** `media="(device-width: 393px) and (device-height: 852px) and (-webkit-device-pixel-ratio: 3) and (prefers-color-scheme: dark)"`
- **iPhone 14 Plus, 13 Pro Max, 12 Pro Max:** `media="(device-width: 428px) and (device-height: 926px) and (-webkit-device-pixel-ratio: 3) and (prefers-color-scheme: dark)"`
- **iPhone 14, 13 Pro, 13, 12 Pro, 12:** `media="(device-width: 390px) and (device-height: 844px) and (-webkit-device-pixel-ratio: 3) and (prefers-color-scheme: dark)"`
- **iPhone SE (3rd/2nd Gen), 8, 7:** `media="(device-width: 375px) and (device-height: 667px) and (-webkit-device-pixel-ratio: 2) and (prefers-color-scheme: dark)"`

---

## 5. Build, Hosting & Production Deployment

### 5.1 Flutter Web Build Pipeline & Rendering Engine Flags
To produce the optimized production web bundle, execute:

```bash
flutter build web --release --base-href "/"
```

#### CanvasKit vs. HTML Renderer Analysis
Flutter Web supports two primary rendering engines:
1. **CanvasKit (Default in release):** Utilizes WebAssembly (Wasm) and Skia hardware graphics to deliver exact 1:1 pixel rendering matching mobile native, smooth 60fps animations, custom shaders, and complex glassmorphic blurs (`BackdropFilter`).
2. **HTML / Wasm-GC:** Smaller initial bundle download, but lacks consistent rendering for complex glassmorphic gradients and shadows.

`ewumate_pwa` is optimized for **CanvasKit** to maintain its dark-mode glassmorphic visual identity across browsers.

### 5.2 Domain Architecture & Routing Strategy
- **Production Host:** `https://app.ewumate.pro.bd`
- **Base HREF:** Set to `/` for root domain hosting.
- **URL Strategy:** Configured via `configureUrlStrategy()` in `main.dart`, which invokes `usePathUrlStrategy()` from `flutter_web_plugins/url_strategy.dart`.
- **Result:** URLs are clean and professional (e.g. `app.ewumate.pro.bd/dashboard`, `app.ewumate.pro.bd/tasks`), eliminating `#` hash routing fragments.

### 5.3 CORS Policy & Backend Security Configuration
Because the web client runs in a sandboxed origin (`https://app.ewumate.pro.bd`), strict Cross-Origin Resource Sharing (CORS) rules must be enforced across all backends:

1. **Supabase Authentication & PostgREST:**
   - Allowed Web Origins: `https://app.ewumate.pro.bd`, `http://localhost:5000`, `http://localhost:3000`.
   - Redirect URLs: `https://app.ewumate.pro.bd/`, `https://app.ewumate.pro.bd/login-callback`.
2. **Azure Microservices (`AZURE_FUNCTION_URL`):**
   - Endpoints (`/api/generate_pdf`, `/api/generate_schedules`, `/api/portal_sync`) must include the following CORS response headers:
     ```http
     Access-Control-Allow-Origin: https://app.ewumate.pro.bd
     Access-Control-Allow-Methods: GET, POST, OPTIONS
     Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
     Access-Control-Allow-Credentials: true
     ```
3. **Environment Security:**
   - Client variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `AZURE_FUNCTION_URL`) are read from `.env` via `flutter_dotenv`.
   - No administrative secret keys (e.g., Supabase `service_role` key) reside in the web bundle. All privileged operations execute inside Supabase Edge Functions or Azure Functions behind Row Level Security (RLS).
