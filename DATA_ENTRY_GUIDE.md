# Data Entry Guide

A step-by-step guide for teammates to add and manage all types of data in the Emergency Healthcare Access Platform.

---

## Table of Contents

1. [Getting Started (First-Time Setup)](#1-getting-started)
2. [Super Admin — Platform Setup](#2-super-admin--platform-setup)
   - [Load Demo Data](#21-load-demo-data)
   - [Add Organization Manually](#22-add-an-organization-manually)
   - [Assign Admin Roles to Users](#23-assign-admin-roles-to-users)
   - [Remove Organizations or Users](#24-remove-organizations-or-users)
3. [Bed Admin — Bed Management](#3-bed-admin--bed-management)
   - [Add a Bed Type](#31-add-a-bed-type)
   - [Edit or Delete a Bed Type](#32-edit-or-delete-a-bed-type)
4. [Diagnostic Test Admin — Diagnostic Test Management](#4-diagnostic-test-admin--diagnostic-test-management)
   - [Add a Diagnostic Test](#41-add-a-diagnostic-test)
   - [Edit or Delete a Test](#42-edit-or-delete-a-test)
5. [Blood Bank Admin — Blood Stock Management](#5-blood-bank-admin--blood-stock-management)
   - [Add a Blood Type](#51-add-a-blood-type)
   - [Edit Stock Levels](#52-edit-stock-levels)
6. [Ambulance Admin — Fleet Management](#6-ambulance-admin--fleet-management)
   - [Add a Vehicle](#61-add-a-vehicle)
   - [Toggle Available/Busy](#62-toggle-availablebusy)
   - [Edit or Delete a Vehicle](#63-edit-or-delete-a-vehicle)
7. [Handling Booking Requests (All Admins)](#7-handling-booking-requests)
   - [Bed Booking Requests](#71-bed-booking-requests)
   - [Blood Requests](#72-blood-requests)
   - [Ambulance Requests](#73-ambulance-requests)
   - [Cleaning Old Requests](#74-cleaning-old-requests)
8. [Patient — Profile & Bookings](#8-patient--profile--bookings)
9. [Finding Coordinates (Latitude & Longitude)](#9-finding-coordinates)
10. [Sample Data Reference](#10-sample-data-reference)

---

## 1. Getting Started

### First Login - Who Gets Super Admin?

All users start as **patients**. The initial Super Admin must be provisioned through the trusted Firebase Console; the first person to register is not automatically trusted.

**Option A — Register with Email:**
1. Open the app in Chrome
2. Click **Register** on the login page
3. Enter your **full name**, **email**, and a **password** (at least 6 characters)
4. Click **Create Account**

**Option B — Sign In with Google:**
1. Open the app in Chrome
2. Click **Sign in with Google** on the login page
3. Choose your Google account in the popup

After the intended administrator signs in once:

1. Open **Firebase Console** -> **Firestore Database** -> `users`
2. Open the document whose ID is that administrator's Firebase Auth UID
3. Change `role` from `patient` to `super_admin`
4. Keep `organization_id` set to `null`

The app's live profile listener then redirects that account to the **Platform Admin Dashboard**. Once provisioned, the Super Admin can assign additional roles from **Manage Users**.

### Forgot Your Password?

1. On the login page, click **Forgot password?**
2. Enter the email you registered with
3. Click **Send Reset Link** — check your inbox for the reset email
4. Follow the link to set a new password, then sign in again

---

## 2. Super Admin — Platform Setup

After logging in as Super Admin, you land on the **Platform Administration** dashboard.

### 2.1 Load Demo Data

If the platform has **no organizations**, a yellow card appears:

1. Click **Load Demo Data**
2. This seeds the database with sample Dhaka-based facilities:

| Type | Organizations Added |
|------|-------------------|
| Hospitals | Dhaka Medical College, Square Hospital, United Hospital, Labaid Hospital |
| Blood Banks | Sandhani Blood Bank, Bangladesh Red Crescent Blood Centre |
| Ambulance Operators | Dhaka Ambulance Service, Emergency Rescue BD, LifeLine Ambulance |

Each comes pre-loaded with beds, blood stock, ambulance vehicles, and diagnostic tests.

> 💡 You can skip demo data and add everything manually instead (see below).

---

### 2.2 Add an Organization Manually

**Navigate:** Platform Dashboard → **Manage Organizations** → **Add Organization** button (top right)

Fill in the form:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Organization Type** | Yes | Select from dropdown | `Hospital`, `Blood Bank`, or `Ambulance Operator` |
| **Organization Name** | Yes | Full name of the facility | `Popular Medical College Hospital` |
| **Address** | Yes | Street address with area and postal code | `House 16, Road 2, Dhanmondi, Dhaka 1205` |
| **Latitude** | Yes | GPS latitude coordinate (see [Section 9](#9-finding-coordinates)) | `23.7415` |
| **Longitude** | Yes | GPS longitude coordinate | `90.3755` |
| **Phone** | Yes | Contact phone number with country code | `+880-2-9116551` |
| **Email** | No | Contact email (optional) | `info@popularmc.com` |

Click **Add** — the organization is created as **Verified** immediately.

> 🔑 After adding, you must also **assign an admin user** to manage it (see [2.3](#23-assign-admin-roles-to-users)).

---

### 2.3 Assign Admin Roles to Users

**Navigate:** Platform Dashboard → **Manage Users**

1. Find the user by name or email in the list
2. Click the **edit (pencil) icon** on their row
3. In the dialog:
   - **Role dropdown** — select the admin type:
     - `Bed Admin` — for hospital beds and bed requests
     - `Diagnostic Test Admin` — for a hospital's test catalog
     - `Blood Bank Admin` — for blood banks
     - `Ambulance Admin` — for ambulance operators
   - **Organization dropdown** — appears after selecting a role; pick the organization they'll manage (only shows matching organizations — e.g., bed and test admins see only hospitals)
4. Click **Save**

The user will see their admin dashboard on their next page load.

> 📋 You can also set someone as `Super Admin` or revert them to `Patient` from this same dialog.

---

### 2.4 Remove Organizations or Users

**Remove an organization:** Go to **Manage Organizations** → click the **delete (trash) icon** on the org card → confirm.

**Remove a user:** Go to **Manage Users** → click the **delete (trash) icon** on the user row → confirm.

> ⚠️ Removing an organization does NOT automatically remove its associated booking requests. Removing a user only removes their profile document — their Firebase Auth account remains.

---

## 3. Bed Admin — Bed Management

**Navigate:** Admin Dashboard → **Manage Beds** card

### 3.1 Add a Bed Type

Click **Add Bed Type** (top right). Fill in:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Bed Type** | Yes | Select from dropdown: `General`, `ICU`, or `NICU` | `ICU` |
| **Total Beds** | Yes | Total number of beds of this type | `20` |
| **Price per Day (৳)** | Yes | Cost per day in Bangladeshi Taka | `15000` |
| **Hold Duration (minutes)** | Yes | How long a confirmed booking holds the bed before it expires | `30` |

Click **Save**.

**What the numbers mean:**
- **Total** = physical beds of this type in the hospital
- **Held** = beds currently reserved (confirmed bookings, auto-managed by system)
- **Admitted** = beds occupied by admitted patients (auto-managed by system)
- **Available** = Total − Held − Admitted (calculated automatically, shown to patients)

### 3.2 Edit or Delete a Bed Type

- **Edit:** Click the **edit (pencil) icon** on the bed type card → update fields → Save
- **Delete:** Click the **delete (trash) icon** → confirm

> 💡 When editing, you can change total beds and price. The held and admitted counts are managed by the system through bookings.

---

## 4. Diagnostic Test Admin — Diagnostic Test Management

**Navigate:** Admin Dashboard → **Manage Tests** card

### 4.1 Add a Diagnostic Test

Click **Add Test** (top right). Fill in:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Test Name** | Yes | Full name of the diagnostic test | `MRI Brain with Contrast` |
| **Price (৳)** | Yes | Cost in Bangladeshi Taka | `12000` |
| **Turnaround Time** | No | How long results take (free text) | `6 hours`, `24 hours`, `2-3 days` |
| **Home Collection Available** | No | Toggle ON if the lab collects samples at home | ON/OFF |
| **Home Collection Surcharge (৳)** | No | Extra charge for home collection (shown only if toggle is ON) | `200` |

Click **Save**.

### 4.2 Edit or Delete a Test

- **Edit:** Click the **edit (pencil) icon** → update → Save
- **Delete:** Click the **delete (trash) icon** → confirm

**Common test names to add:**

| Test Name | Typical Price (৳) | Turnaround |
|-----------|-------------------|------------|
| CBC (Complete Blood Count) | 500–800 | 1–2 hours |
| Blood Sugar (Fasting) | 200–400 | 1 hour |
| Lipid Profile | 1000–1500 | 4 hours |
| Thyroid Panel (T3, T4, TSH) | 1500–2500 | 6 hours |
| Liver Function Test (LFT) | 1200–2000 | 4 hours |
| Kidney Function Test (KFT) | 1200–1800 | 4 hours |
| HbA1c | 800–1200 | 4 hours |
| X-Ray Chest | 600–1000 | 1 hour |
| Ultrasound Abdomen | 2000–3000 | 1 hour |
| CT Scan (Abdomen/Chest) | 4000–8000 | 3–4 hours |
| MRI Brain | 8000–15000 | 6–24 hours |
| Echocardiogram | 3000–5000 | 2 hours |
| ECG | 300–500 | 30 minutes |
| Urine R/E | 200–400 | 2 hours |

---

## 5. Blood Bank Admin — Blood Stock Management

**Navigate:** Admin Dashboard → **Manage Blood Stock** card

### 5.1 Add a Blood Type

Click **Add Blood Type** (top right). Fill in:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Blood Type** | Yes | Select from dropdown: `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` | `O+` |
| **Total Units** | Yes | Total units (bags) in stock | `50` |
| **Processing Fee per Unit (৳)** | Yes | Fee charged per unit. Enter `0` for free (e.g., government blood banks) | `500` |

Click **Save**.

**What the numbers mean:**
- **Total** = all units currently in stock
- **Held** = units reserved for confirmed requests (auto-managed)
- **Issued** = units already issued to patients (auto-managed)
- **Available** = Total − Held − Issued (shown to patients)

### 5.2 Edit Stock Levels

Click the **edit (pencil) icon** on any blood type card to update:
- Increase **Total Units** when new donations arrive
- Adjust **Processing Fee** as needed

> 💡 Add all 8 blood types even if some have 0 units — patients can see which types the bank handles.

**Recommended initial stock entry (per blood bank):**

| Blood Type | Typical Total | Notes |
|------------|---------------|-------|
| O+ | 30–50 | Most common in Bangladesh |
| B+ | 25–45 | Second most common |
| A+ | 20–40 | |
| AB+ | 10–20 | |
| O- | 5–10 | Universal donor, rare |
| B- | 5–10 | |
| A- | 5–10 | |
| AB- | 3–5 | Rarest |

---

## 6. Ambulance Admin — Fleet Management

**Navigate:** Admin Dashboard → **Manage Fleet** card

### 6.1 Add a Vehicle

Click **Add Vehicle** (top right). Fill in:

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| **Vehicle Type** | Yes | Select: `Basic`, `AC`, or `ICU` | `AC` |
| **Base Fare (৳)** | Yes | Starting fare for the trip | `3000` |
| **Per-km Rate (৳)** | No | Additional charge per kilometer (leave empty if flat fare only) | `50` |

Click **Save**. New vehicles default to **Available** status.

### 6.2 Toggle Available/Busy

Each vehicle card has a **toggle switch**:
- **Available** (green) = shown to patients, can receive bookings
- **Busy** (grey) = hidden from availability counts, already on a trip

Just flip the switch — it saves instantly.

### 6.3 Edit or Delete a Vehicle

- **Edit:** Click the **edit (pencil) icon** → update fares → Save
- **Delete:** Click the **delete (trash) icon** → confirm

**Recommended fleet setup:**

| Vehicle Type | Base Fare (৳) | Per-km Rate (৳) | Description |
|-------------|---------------|-----------------|-------------|
| Basic | 1000–1500 | 20–30 | Standard ambulance, no AC |
| AC | 2000–3500 | 40–50 | Air-conditioned ambulance |
| ICU | 6000–10000 | 70–100 | Mobile ICU with equipment and paramedic |

> 💡 Add multiple vehicles of the same type. Each vehicle is tracked separately. Example: 3 Basic + 2 AC + 1 ICU = 6 vehicles total.

---

## 7. Handling Booking Requests

When patients submit bookings, they appear in the relevant admin's **Requests** screen.

### 7.1 Bed Booking Requests

**Navigate:** Admin Dashboard → **Booking Requests** card

Each request shows:
- Patient name, phone number, bed type, estimated price
- **View Prescription** button (if the patient uploaded one — opens in a dialog)
- Status badge (Pending / Confirmed / Admitted / Rejected / Expired)

**Actions:**

| Status | Available Actions | What Happens |
|--------|------------------|--------------|
| **Pending** | **Approve & Hold** or **Reject** | Approve decrements available beds, starts hold timer |
| **Confirmed** | **Mark as Admitted** | Moves patient from "held" to "admitted" count |
| Rejected/Expired/Admitted | None (terminal) | Use **Clean** button to remove from list |

### 7.2 Blood Requests

Same flow as beds:
- Shows: patient name, blood type, units needed, hospital name, prescribing doctor
- **Approve & Hold** → decrements available units, starts 60-minute hold
- **Mark Complete** → moves from "held" to "issued"

### 7.3 Ambulance Requests

Same flow:
- Shows: patient name, ambulance type, pickup location, destination, condition notes
- **Approve & Hold** → marks ambulance as held, starts 30-minute hold
- **Mark Complete** → trip completed

### 7.4 Cleaning Old Requests

All three request screens have a **Clean** button (broom icon, top right):
- Only appears when there are terminal requests (Rejected, Expired, or Admitted/Completed)
- Click to batch-delete them from the list
- This is permanent — the requests are removed from the database

---

## 8. Patient — Profile & Bookings

### Sign In or Register

1. Open the app in Chrome
2. Either:
   - **Email:** Click **Register** → fill in name, email, and password → **Create Account**
   - **Google:** Click **Sign in with Google** → pick your Google account
3. If you already have an account, use **Sign In** with your email + password, or Google

### Complete Your Profile

Before booking, patients must complete their profile:

1. Click **Profile** (user icon in nav bar)
2. Fill in:
   - **Name** — your full name (pre-filled if you registered with email or Google)
   - **Phone** — your contact number (e.g., `01712345678`)
3. Click **Save**

### Making a Booking

**Bed Booking:**
1. Go to **Beds** tab → pick a hospital → click to open booking
2. Fill in: bed type, contact number, upload prescription image (optional)
3. Submit → the request goes to the bed admin

**Blood Request:**
1. Go to **Blood** tab → pick a blood bank → click to open request
2. Fill in: blood type, units needed, hospital name (searchable), prescribing doctor
3. Submit → the request goes to the blood bank admin

**Ambulance Booking:**
1. Go to **Ambulance** tab → pick an operator → click to open booking
2. Fill in: ambulance type, pickup address, destination (searchable, optional), condition notes
3. Submit → the request goes to the ambulance operator

### Track Your Bookings

**My Bookings** (in nav bar) shows all your past and active bookings with:
- Current status (Pending → Confirmed → Admitted/Completed, or Rejected/Expired)
- Hold countdown timer (for confirmed bookings)
- Click any booking to see full details

---

## 9. Finding Coordinates

When adding organizations, you need **Latitude** and **Longitude**. Here's how to find them:

### Method 1: Google Maps (Easiest)

1. Go to [Google Maps](https://maps.google.com)
2. Search for the location or right-click on the map
3. Click the coordinates that appear — they copy to clipboard
4. Format: `23.7260, 90.3976` → Latitude: `23.7260`, Longitude: `90.3976`

### Method 2: LatLong.net

1. Go to [latlong.net](https://www.latlong.net)
2. Search for the address
3. Copy the latitude and longitude values

### Common Dhaka Coordinates Reference

| Location | Latitude | Longitude |
|----------|----------|-----------|
| Dhanmondi | 23.7461 | 90.3742 |
| Gulshan | 23.7937 | 90.4150 |
| Uttara | 23.8700 | 90.3990 |
| Mirpur | 23.7956 | 90.3535 |
| Mohammadpur | 23.7650 | 90.3590 |
| Motijheel | 23.7330 | 90.4178 |
| Banani | 23.7940 | 90.4023 |
| Farmgate | 23.7570 | 90.3930 |
| Shahbag | 23.7380 | 90.3960 |
| Old Dhaka (Lalbagh) | 23.7190 | 90.3890 |

---

## 10. Sample Data Reference

If you're adding data manually (instead of using demo data), here are realistic examples:

### Sample Hospital

| Field | Value |
|-------|-------|
| Name | Ibn Sina Medical College Hospital |
| Type | Hospital |
| Address | 1, 1-B Mirpur Rd, Dhaka 1207 |
| Latitude | 23.7630 |
| Longitude | 90.3650 |
| Phone | +880-2-9005601 |
| Email | info@ibnsinatrust.com |

**Beds to add after creating:**

| Bed Type | Total | Price/Day (৳) | Hold (min) |
|----------|-------|---------------|------------|
| General | 30 | 2000 | 30 |
| ICU | 12 | 8000 | 30 |
| NICU | 6 | 10000 | 30 |

**Tests to add:**

| Test Name | Price (৳) | Turnaround | Home Collection |
|-----------|-----------|------------|-----------------|
| CBC | 600 | 2 hours | No |
| Blood Sugar (Fasting) | 250 | 1 hour | Yes (+৳150) |
| X-Ray Chest | 700 | 1 hour | No |
| Lipid Profile | 1200 | 4 hours | Yes (+৳200) |

### Sample Blood Bank

| Field | Value |
|-------|-------|
| Name | Quantum Blood Center |
| Type | Blood Bank |
| Address | 26/1 Green Rd, Dhaka 1205 |
| Latitude | 23.7502 |
| Longitude | 90.3800 |
| Phone | +880-2-8617081 |
| Email | info@quantumbd.org |

**Blood stock to add:**

| Blood Type | Total Units | Fee/Unit (৳) |
|------------|-------------|-------------|
| A+ | 30 | 0 |
| A- | 8 | 0 |
| B+ | 35 | 0 |
| B- | 5 | 0 |
| AB+ | 12 | 0 |
| AB- | 3 | 0 |
| O+ | 40 | 0 |
| O- | 7 | 0 |

### Sample Ambulance Operator

| Field | Value |
|-------|-------|
| Name | City Ambulance Dhaka |
| Type | Ambulance Operator |
| Address | Farmgate, Dhaka 1215 |
| Latitude | 23.7570 |
| Longitude | 90.3930 |
| Phone | +880-1600-999111 |
| Email | dispatch@cityambulance.bd |

**Vehicles to add:**

| Vehicle Type | Base Fare (৳) | Per-km (৳) |
|-------------|---------------|------------|
| Basic | 1200 | 25 |
| Basic | 1200 | 25 |
| AC | 2800 | 45 |
| ICU | 7500 | 80 |

---

## Quick Checklist for Full Platform Setup

- [ ] Intended administrator signs in, then is provisioned as Super Admin through Firebase Console
- [ ] Super Admin loads demo data OR adds organizations manually
- [ ] For each organization:
  - [ ] Add the organization (name, address, coordinates, phone)
  - [ ] Have a teammate register (email) or sign in (Google)
  - [ ] Assign them the correct admin role + organization
- [ ] Each admin logs in and adds their data:
  - [ ] **Bed Admin:** Add bed types and manage bed requests
  - [ ] **Diagnostic Test Admin:** Add diagnostic tests and pricing
  - [ ] **Blood Bank Admin:** Add all 8 blood types with stock levels
  - [ ] **Ambulance Admin:** Add vehicles with fares
- [ ] Test: Sign in as a patient → browse listings → submit a booking → admin approves it
