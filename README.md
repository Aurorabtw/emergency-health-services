# Emergency Healthcare Access Platform

A unified emergency healthcare coordination platform built with **Flutter Web** and **Firebase** (Spark/free tier). The platform centralizes four critical services — emergency bed booking, ambulance dispatch, blood bank access, and diagnostic test lookup — so patients can find availability, compare prices, and request resources instantly during a crisis.

## Services

| Service | Patient Flow | Admin Flow |
|---------|-------------|------------|
| **Emergency Beds** | Browse hospitals, view bed availability and pricing, book a bed | Manage bed types/counts/pricing, approve/reject/admit requests |
| **Emergency Ambulance** | Browse operators, select ambulance type, get fare estimate, book | Manage fleet and fares, confirm trips, mark completed |
| **Emergency Blood Bank** | Search by blood type, check unit availability, request blood | Manage blood stock per type, approve/hold/issue units |
| **Diagnostic Tests** | Search tests by name, compare prices across hospitals, tap-to-call | Manage test catalog with pricing and turnaround times |

## Tech Stack

- **Frontend:** Flutter Web (Dart)
- **Backend:** Firebase (Auth, Cloud Firestore, Storage)
- **State Management:** Provider (ChangeNotifier)
- **Routing:** GoRouter with role-based route guards
- **Auth:** Firebase Google Sign-In (`signInWithPopup`)
- **Image Storage:** Cloudinary (free tier, unsigned uploads)
- **Maps:** flutter_map + OpenStreetMap (free, no API key, real street maps)
- **Distances:** OSRM road distances (actual driving distance, free API)
- **Currency:** Bangladeshi Taka (৳) formatting

## Prerequisites

- **Flutter SDK** >= 3.11.0 — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Firebase CLI** — `npm install -g firebase-tools`
- **FlutterFire CLI** — `dart pub global activate flutterfire_cli`
- **Google Chrome** (for web development)
- A **Google account** for Firebase project setup

Verify your setup:

```bash
flutter doctor
firebase --version
flutterfire --version
```

## Setup Guide

### 1. Clone the Repository

```bash
git clone https://github.com/rayhan19122/emergency-health-services.git
cd emergency-health-services
flutter pub get
```

### 2. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add Project** → name it (e.g., `emergency-healthcare`) → create
3. Enable these services in the Firebase console:

**Authentication:**
- Go to **Authentication** → **Sign-in method**
- Enable **Google** provider
- Set a support email and save

**Cloud Firestore:**
- Go to **Firestore Database** → **Create database**
- Select **Start in test mode** (we'll deploy proper rules later)
- Choose a region close to your users (e.g., `asia-southeast1`)

### 3. Set Up Cloudinary (Prescription Image Uploads)

Prescription images are stored on [Cloudinary](https://cloudinary.com) (free tier — 25GB storage, 25GB bandwidth/month).

1. Sign up at [cloudinary.com](https://cloudinary.com) (free)
2. From the **Dashboard**, copy your **Cloud Name**
3. Go to **Settings** → **Upload** → scroll to **Upload presets**
4. Click **Add upload preset**:
   - **Preset name:** `hospital_services`
   - **Signing Mode:** `Unsigned`
   - **Folder:** `prescriptions` (optional)
   - Save
5. Open `lib/services/cloudinary_service.dart` and update:

```dart
static const String cloudName = 'YOUR_CLOUD_NAME';
static const String uploadPreset = 'hospital_services';
```

### 4. Connect Firebase to the Project

```bash
firebase login
flutterfire configure --project=YOUR_PROJECT_ID
```

This generates/overwrites `lib/firebase_options.dart` with your project's config. Select **Web** when prompted for platforms.

### 5. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

This deploys the rules from `firestore.rules` which enforce:
- Public read access for organization/service listings
- Authenticated users can create bookings (if profile is complete)
- Org admins can only manage their own organization's data
- Super admin has platform-wide access
- Users can only read their own profile and bookings

### 6. Run the App

```bash
flutter run -d chrome
```

The app launches at `http://localhost:XXXXX` in Chrome.

For a production build:

```bash
flutter build web
firebase deploy --only hosting
```

## First-Time Operation Guide

### Step 1: First User Becomes Super Admin

The **first user** to sign in with Google is automatically promoted to **Super Admin**. This is tracked via a `config/platform` document in Firestore. All subsequent users are created as **patients**.

1. Click **Sign In with Google** on the login page
2. You'll be redirected to the **Platform Admin Dashboard**

### Step 2: Load Demo Data

If the platform has no organizations yet, the Super Admin dashboard shows a **Load Demo Data** card:

1. Click **Load Demo Data**
2. This seeds Firestore with sample Dhaka-based healthcare facilities:
   - **4 Hospitals:** Dhaka Medical College, Square Hospital, United Hospital, Labaid Hospital
   - **2 Blood Banks:** Sandhani Blood Transfusion Center, Red Crescent Blood Center
   - **3 Ambulance Operators:** Dhaka Ambulance Service, Emergency Response BD, City Ambulance

Each organization comes with subcollection data (bed types, blood stock, ambulance vehicles, diagnostic tests).

### Step 3: Assign Admin Roles

From the Super Admin dashboard:

1. Go to **Manage Users**
2. Find a user by email → click the **edit** icon
3. Select a role:
   - `hospital_admin` → assign to a hospital
   - `blood_bank_admin` → assign to a blood bank
   - `ambulance_admin` → assign to an ambulance operator
4. Select the **organization** from the dropdown
5. Click **Save**

The user's nav bar and dashboard update on their next page load.

### Step 4: Add Organizations Manually (Optional)

Instead of (or in addition to) demo data:

1. Go to **Manage Organizations** → **Add Organization**
2. Fill in: name, type, address, coordinates, phone, email
3. Organizations are created as **Verified** by default
4. Assign an admin user to manage it (Step 3)

## User Roles

| Role | Access |
|------|--------|
| **Patient** | Browse all services, make bookings, view booking history |
| **Hospital Admin** | Manage beds, tests, and booking requests for their hospital |
| **Blood Bank Admin** | Manage blood stock and blood requests for their blood bank |
| **Ambulance Admin** | Manage fleet, fares, and trip requests for their operator |
| **Super Admin** | Manage all organizations, assign roles, view all requests, seed data |

### Role-Based Navigation

- **Patients** see: Beds, Ambulance, Blood, Tests, My Bookings, Profile
- **Org Admins** see: Admin Dashboard (with relevant management cards), Profile
- **Super Admin** sees: Platform Dashboard, Profile
- Admins are redirected to their dashboard after login (not the home page)

## Booking Lifecycle

```
Patient submits request
        │
        ▼
    [PENDING] ──── Admin rejects ────► [REJECTED]
        │
   Admin approves
        │
        ▼
   [CONFIRMED] ──── Hold timer expires ────► [EXPIRED]
    (held for N min)        (availability restored)
        │
   Admin admits/completes
        │
        ▼
   [ADMITTED] (terminal)
```

- **Approve & Hold:** Decrements available count, sets a hold timer (configurable per bed type / 60 min for blood / 30 min for ambulance)
- **Lazy Expiry:** When any user reads a confirmed booking past its hold time, the status is auto-updated to `expired` and the held count is restored
- **Clean:** Admins can clear all terminal requests (rejected/expired/admitted) from their request view

## Project Structure

```
lib/
├── main.dart                          # Entry point — Firebase init
├── app.dart                           # MaterialApp + Providers + GoRouter
├── config/
│   ├── routes.dart                    # All routes + guards + admin request views
│   └── theme.dart                     # Material 3 theme
├── models/                            # Firestore data models (fromFirestore/toFirestore)
│   ├── user_model.dart
│   ├── organization_model.dart
│   ├── booking_request_model.dart     # Polymorphic: bed/blood/ambulance fields
│   ├── bed_type_model.dart
│   ├── blood_stock_model.dart
│   ├── ambulance_model.dart
│   └── test_model.dart
├── providers/                         # ChangeNotifier state management
│   ├── auth_provider.dart             # Auth state, role checks, org name
│   ├── booking_provider.dart          # Booking CRUD, confirm/reject/clean
│   ├── organization_provider.dart     # Org listing and lookup
│   └── location_provider.dart         # Browser geolocation
├── services/                          # Firebase service layer
│   ├── auth_service.dart              # Google Sign-In via signInWithPopup
│   ├── firestore_service.dart         # Generic Firestore CRUD + transactions
│   ├── cloudinary_service.dart         # Cloudinary image upload API
│   ├── storage_service.dart           # Image upload wrapper (uses Cloudinary)
│   ├── location_service.dart          # Geolocation API wrapper
│   └── seed_data_service.dart         # Demo data seeder
├── features/
│   ├── auth/screens/                  # Login screen
│   ├── home/screens/                  # Service selection cards
│   ├── profile/screens/               # User profile editing
│   ├── bookings/screens/              # My Bookings + Booking Detail
│   ├── beds/
│   │   ├── providers/                 # BedProvider
│   │   └── screens/                   # Listings, booking form, admin (manage + requests)
│   ├── blood_bank/
│   │   ├── providers/                 # BloodProvider
│   │   └── screens/                   # Listings, request form, admin (stock + requests)
│   ├── ambulance/
│   │   ├── providers/                 # AmbulanceProvider
│   │   └── screens/                   # Listings, booking form, admin (fleet + requests)
│   ├── tests/
│   │   ├── providers/                 # TestProvider
│   │   └── screens/                   # Search screen, admin (manage tests)
│   └── admin/
│       ├── org_admin/screens/         # Org admin dashboard
│       └── super_admin/screens/       # Platform dashboard, manage orgs/users
├── navigation/
│   ├── app_nav_bar.dart               # Role-aware top navigation
│   └── app_shell.dart                 # Scaffold wrapper
└── shared/
    ├── widgets/                       # Reusable: PriceWidget, BookingStatusChip, etc.
    └── utils/                         # LazyExpiry, CurrencyFormatter, Validators
```

## Firestore Data Model

```
organizations/{orgId}
├── type: "hospital" | "blood_bank" | "ambulance_operator"
├── name, address, latitude, longitude, phone, email, verified
├── beds/{bedId}           (hospitals only)
│   └── type, total_beds, held_beds, admitted_beds, price_per_day, hold_duration_minutes
├── blood_stock/{stockId}  (blood banks only)
│   └── blood_type, total_units, held_units, issued_units, processing_fee_per_unit
├── ambulances/{vehicleId} (ambulance operators only)
│   └── type, status, base_fare, per_km_rate
└── tests/{testId}         (hospitals only)
    └── test_name, price, turnaround_time, home_collection, home_collection_surcharge

booking_requests/{requestId}
├── type, organization_id, organization_name, user_id
├── patient_name, contact_number, status, held_until, estimated_price, created_at
├── bed_type, prescription_image_url           (bed bookings)
├── blood_type, units_needed, hospital_name, prescribing_doctor  (blood requests)
└── ambulance_type, pickup_address, destination_address, patient_condition_notes  (ambulance)

users/{uid}
└── email, name, phone, role, organization_id, profile_complete

config/platform
└── initialized, initialized_by, initialized_at
```

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Google Sign-In opens blank popup | OAuth not configured | Add your domain to Firebase Auth → Authorized domains |
| Firestore permission denied | Security rules not deployed | Run `firebase deploy --only firestore:rules` |
| Bookings disappear after refresh | Composite index required | Check browser console for Firestore index creation links, or the app handles this by client-side sorting |
| First user isn't super admin | `config/platform` doc already exists | Delete `config/platform` from Firestore console, then sign in again |
| Bed data not loading for admin | Subcollections not seeded | Load demo data from Super Admin dashboard, or manually add bed types |

## Development Notes

- **No Cloud Functions** — the project runs entirely on Firebase Spark (free tier) with client-side logic
- **Lazy expiry** — hold timers are checked client-side on every booking read, not via server-side cron
- **Denormalized org names** — `organization_name` is stored directly in booking documents to avoid extra reads
- **Client-side search** — test search and hospital autocomplete filter locally after fetching all records
- **Currency** — all prices are in Bangladeshi Taka (৳), formatted via `intl` package
- **Image storage** — uses Cloudinary (free tier) instead of Firebase Storage to avoid billing requirements
- **Maps** — flutter_map with OpenStreetMap tiles (free, no API key); color-coded markers (green >5, yellow 1-4, red 0) on all listing screens
- **Road distances** — uses OSRM Table API to batch-fetch real driving distances (not straight-line); falls back to Haversine if OSRM is unavailable

## Team Workflow

```bash
# Pull latest changes
git pull origin main

# Create a feature branch
git checkout -b feature/your-feature-name

# Run the app
flutter pub get
flutter run -d chrome

# Build and verify
flutter build web

# Push your branch
git push -u origin feature/your-feature-name
```

Then create a Pull Request on GitHub for review.
