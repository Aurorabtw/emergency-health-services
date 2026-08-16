# Emergency Healthcare Access Platform — SDP Report Diagrams

---

## Figure 1: System Architecture Diagram

```mermaid
graph TB
    subgraph PL["🖥️ Presentation Layer — Flutter Web UI"]
        direction LR
        HS[Home Screen]
        BLS[Bed Listings]
        ALS[Ambulance Listings]
        BBS[Blood Bank Listings]
        TSS[Test Search]
        BKS[My Bookings]
        PS[Profile Screen]
        AD[Admin Dashboard]
        SAD[Super Admin Dashboard]
    end

    subgraph SML["⚙️ State Management Layer — Providers"]
        direction LR
        AP[AuthProvider]
        OP[OrganizationProvider]
        BP[BookingProvider]
        BedP[BedProvider]
        BloodP[BloodProvider]
        AmbP[AmbulanceProvider]
        TP[TestProvider]
        LP[LocationProvider]
    end

    subgraph SL["🔧 Service Layer"]
        direction LR
        AS[AuthService]
        FS[FirestoreService]
        PRS[PrescriptionService]
        LS[LocationService]
        SDS[SeedDataService]
    end

    subgraph FL["☁️ Firebase Cloud + External"]
        direction LR
        FA[Firebase Auth]
        CF[Cloud Firestore]
        OSM[OpenStreetMap / OSRM]
    end

    subgraph SEC["🔒 Security"]
        FSR[Firestore Security Rules]
    end

    PL --> SML
    SML --> SL
    AS --> FA
    FS --> CF
    PRS --> CF
    LS --> OSM
    SDS --> CF
    FSR -.->|enforces access| CF

    style PL fill:#e3f2fd,stroke:#1565c0,color:#000
    style SML fill:#fff3e0,stroke:#e65100,color:#000
    style SL fill:#e8f5e9,stroke:#2e7d32,color:#000
    style FL fill:#fce4ec,stroke:#c62828,color:#000
    style SEC fill:#f3e5f5,stroke:#6a1b9a,color:#000
```

---

## Figure 2: Use Case Diagram

```mermaid
graph LR
    Patient((👤 Patient))
    OrgAdmin((🏥 Org Admin))
    SuperAdmin((👑 Super Admin))

    subgraph System["Emergency Healthcare Access Platform"]
        UC1[Sign In / Register]
        UC2[Browse Bed Listings]
        UC3[Book Emergency Bed]
        UC4[Browse Ambulance Operators]
        UC5[Book Ambulance]
        UC6[Browse Blood Banks]
        UC7[Request Blood Units]
        UC8[Search Diagnostic Tests]
        UC9[View Booking History]
        UC10[Manage Profile]
        UC11[Manage Beds / Fleet / Stock / Tests]
        UC12[Approve / Reject Bookings]
        UC13[Admit Patient / Complete Trip]
        UC14[Clean Terminal Requests]
        UC15[Manage Organizations]
        UC16[Assign User Roles]
        UC17[View All Platform Requests]
        UC18[Seed Demo Data]
        UC19[Sort by Distance / Price]
        UC20[Filter by Type]
    end

    Patient --- UC1
    Patient --- UC2
    Patient --- UC3
    Patient --- UC4
    Patient --- UC5
    Patient --- UC6
    Patient --- UC7
    Patient --- UC8
    Patient --- UC9
    Patient --- UC10
    Patient --- UC19
    Patient --- UC20

    OrgAdmin --- UC1
    OrgAdmin --- UC11
    OrgAdmin --- UC12
    OrgAdmin --- UC13
    OrgAdmin --- UC14

    SuperAdmin --- UC1
    SuperAdmin --- UC15
    SuperAdmin --- UC16
    SuperAdmin --- UC17
    SuperAdmin --- UC18

    style System fill:#f5f5f5,stroke:#333,color:#000
```

---

## Figure 3: Context Level Diagram (DFD-0)

```mermaid
graph LR
    P["👤 Patient"]
    OA["🏥 Organization Admin"]
    SA["👑 Super Admin"]
    FB["☁️ Firebase Cloud"]

    EHAP(["🔷 Emergency Healthcare\nAccess Platform"])

    P -->|Booking requests,\nPersonal info,\nSearch queries| EHAP
    EHAP -->|Availability data,\nPricing info,\nBooking status| P

    OA -->|Resource data,\nBed/stock/fleet updates,\nRequest decisions| EHAP
    EHAP -->|Booking notifications,\nDashboard data,\nRequest queue| OA

    SA -->|Org data,\nRole assignments,\nSeed commands| EHAP
    EHAP -->|Platform analytics,\nUser list,\nOrg list| SA

    EHAP <-->|CRUD operations,\nAuth tokens,\nReal-time sync| FB

    style EHAP fill:#1565c0,stroke:#0d47a1,color:#fff
    style P fill:#e8f5e9,stroke:#2e7d32,color:#000
    style OA fill:#fff3e0,stroke:#e65100,color:#000
    style SA fill:#fce4ec,stroke:#c62828,color:#000
    style FB fill:#f3e5f5,stroke:#6a1b9a,color:#000
```

---

## Figure 4: Data Flow Diagram (DFD-1) — Bed Booking

```mermaid
flowchart TD
    P["👤 Patient"]
    D1[("D1: Beds Store")]
    D2[("D2: Booking Requests")]
    D3[("D3: Users Store")]

    P1["1.0\nAuthenticate\nUser"]
    P2["2.0\nBrowse\nHospital Beds"]
    P3["3.0\nSubmit Bed\nBooking"]
    P4["4.0\nManage Bed\nRequests"]

    OA["🛏️ Bed Admin"]

    P -->|"Email/password or\nGoogle credentials"| P1
    P1 -->|"Auth token"| D3
    D3 -->|"User profile"| P1
    P1 -->|"Authenticated session"| P2

    D1 -->|"Bed types, availability, pricing"| P2
    P2 -->|"Sorted and filtered listings"| P

    P -->|"Patient name, contact, bed type"| P3
    P3 -->|"Validate profile"| D3
    P3 -->|"Create booking - status: pending"| D2
    P3 -->|"Estimated price"| P

    D2 -->|"Pending requests"| P4
    OA -->|"Approve, Reject, or Admit"| P4
    P4 -->|"Update status, set held_until"| D2
    P4 -->|"Decrement held_beds"| D1
    P4 -->|"Decision notification"| P

    style P1 fill:#e3f2fd,stroke:#1565c0,color:#000
    style P2 fill:#e3f2fd,stroke:#1565c0,color:#000
    style P3 fill:#e3f2fd,stroke:#1565c0,color:#000
    style P4 fill:#e3f2fd,stroke:#1565c0,color:#000
    style D1 fill:#fff9c4,stroke:#f57f17,color:#000
    style D2 fill:#fff9c4,stroke:#f57f17,color:#000
    style D3 fill:#fff9c4,stroke:#f57f17,color:#000
```

---

## Figure 5: Data Flow Diagram (DFD-1) — Blood Request

```mermaid
flowchart TD
    P["👤 Patient"]
    D1[("D1: Blood Stock Store")]
    D2[("D2: Booking Requests")]
    D3[("D3: Users Store")]

    P1["1.0\nAuthenticate\nUser"]
    P2["2.0\nBrowse Blood\nBanks"]
    P3["3.0\nSubmit Blood\nRequest"]
    P4["4.0\nManage Blood\nRequests"]

    OA["🩸 Blood Bank Admin"]

    P -->|"Email/password or\nGoogle credentials"| P1
    P1 -->|"Auth and profile"| D3
    D3 -->|"User data"| P1
    P1 -->|"Authenticated session"| P2

    D1 -->|"Blood types, unit counts, fees"| P2
    P2 -->|"Filtered listings by blood type"| P

    P -->|"Blood type, units needed, doctor"| P3
    P3 -->|"Validate profile"| D3
    P3 -->|"Create request - status: pending"| D2
    P3 -->|"Processing fee estimate"| P

    D2 -->|"Pending requests"| P4
    OA -->|"Approve, Reject, or Issue"| P4
    P4 -->|"Update status, set held_until 60min"| D2
    P4 -->|"Decrement held_units"| D1
    P4 -->|"Decision notification"| P

    style P1 fill:#fce4ec,stroke:#c62828,color:#000
    style P2 fill:#fce4ec,stroke:#c62828,color:#000
    style P3 fill:#fce4ec,stroke:#c62828,color:#000
    style P4 fill:#fce4ec,stroke:#c62828,color:#000
    style D1 fill:#fff9c4,stroke:#f57f17,color:#000
    style D2 fill:#fff9c4,stroke:#f57f17,color:#000
    style D3 fill:#fff9c4,stroke:#f57f17,color:#000
```

---

## Figure 6: Data Flow Diagram (DFD-1) — Ambulance Booking

```mermaid
flowchart TD
    P["👤 Patient"]
    D1[("D1: Ambulances Store")]
    D2[("D2: Booking Requests")]
    D3[("D3: Users Store")]

    P1["1.0\nAuthenticate\nUser"]
    P2["2.0\nBrowse Ambulance\nOperators"]
    P3["3.0\nSubmit Ambulance\nBooking"]
    P4["4.0\nManage Ambulance\nRequests"]

    OA["🚑 Ambulance Admin"]

    P -->|"Email/password or\nGoogle credentials"| P1
    P1 -->|"Auth and profile"| D3
    D3 -->|"User data"| P1
    P1 -->|"Authenticated session"| P2

    D1 -->|"Vehicle types, status, fares"| P2
    P2 -->|"Available operators with estimates"| P

    P -->|"Pickup, destination, vehicle type"| P3
    P3 -->|"Validate profile"| D3
    P3 -->|"Create booking - status: pending"| D2
    P3 -->|"Fare estimate"| P

    D2 -->|"Pending requests"| P4
    OA -->|"Confirm, Reject, or Complete"| P4
    P4 -->|"Update status, set held_until 30min"| D2
    P4 -->|"Update vehicle status to busy"| D1
    P4 -->|"Decision notification"| P

    style P1 fill:#fff3e0,stroke:#e65100,color:#000
    style P2 fill:#fff3e0,stroke:#e65100,color:#000
    style P3 fill:#fff3e0,stroke:#e65100,color:#000
    style P4 fill:#fff3e0,stroke:#e65100,color:#000
    style D1 fill:#fff9c4,stroke:#f57f17,color:#000
    style D2 fill:#fff9c4,stroke:#f57f17,color:#000
    style D3 fill:#fff9c4,stroke:#f57f17,color:#000
```

---

## Figure 7: Database Schema Diagram

```mermaid
erDiagram
    ORGANIZATIONS {
        string id PK
        string type "hospital | blood_bank | ambulance_operator"
        string name
        string address
        double latitude
        double longitude
        string phone
        string email
        boolean verified
        timestamp created_at
        timestamp updated_at
    }

    BEDS {
        string id PK
        string org_id FK
        string type "General | ICU | NICU"
        int total_beds
        int held_beds
        int admitted_beds
        double price_per_day
        int hold_duration_minutes
    }

    BLOOD_STOCK {
        string id PK
        string org_id FK
        string blood_type "A+ | A- | B+ | B- | AB+ | AB- | O+ | O-"
        int total_units
        int held_units
        int issued_units
        double processing_fee_per_unit
        timestamp last_updated
    }

    AMBULANCES {
        string id PK
        string org_id FK
        string type "Basic | AC | ICU"
        string status "available | busy"
        double base_fare
        double per_km_rate
    }

    TESTS {
        string id PK
        string org_id FK
        string test_name
        double price
        string turnaround_time
        boolean home_collection
        double home_collection_surcharge
    }

    BOOKING_REQUESTS {
        string id PK
        string type "bed | blood | ambulance"
        string organization_id FK
        string organization_name
        string user_id FK
        string patient_name
        string contact_number
        string status "pending | confirmed | admitted | expired | rejected"
        timestamp held_until
        double estimated_price
        timestamp created_at
        string bed_type "nullable"
        string bed_id "nullable"
        string prescription_document_id "nullable"
        string blood_type "nullable"
        string blood_stock_id "nullable"
        int units_needed "nullable"
        string hospital_id "nullable"
        string hospital_name "nullable"
        string prescribing_doctor "nullable"
        string ambulance_type "nullable"
        string ambulance_reference_id "nullable"
        string ambulance_id "nullable"
        string pickup_address "nullable"
        string destination_hospital_id "nullable"
        string destination_address "nullable"
        string patient_condition_notes "nullable"
    }

    USERS {
        string uid PK
        string email
        string name
        string phone
        string role "patient | bed_admin | test_admin | blood_bank_admin | ambulance_admin | super_admin"
        string organization_id FK "nullable"
        boolean profile_complete
    }

    ORGANIZATIONS ||--o{ BEDS : "has (hospitals)"
    ORGANIZATIONS ||--o{ BLOOD_STOCK : "has (blood banks)"
    ORGANIZATIONS ||--o{ AMBULANCES : "has (operators)"
    ORGANIZATIONS ||--o{ TESTS : "has (hospitals)"
    ORGANIZATIONS ||--o{ BOOKING_REQUESTS : "receives"
    USERS ||--o{ BOOKING_REQUESTS : "submits"
    USERS |o--o| ORGANIZATIONS : "administers"
```

---

## Figure 8: Booking Lifecycle Flowchart

```mermaid
flowchart TD
    A([Patient submits\nbooking request]) --> B{Profile\ncomplete?}
    B -->|No| C[Show Profile\nCompletion Dialog]
    C --> D[Patient completes\nname & phone]
    D --> B

    B -->|Yes| E[Create booking_request\nstatus: PENDING]
    E --> F[Admin receives\nrequest in dashboard]

    F --> G{Admin\ndecision}

    G -->|Reject| H[Status → REJECTED\n🔴 Terminal]

    G -->|Approve| I[Status → CONFIRMED\nSet held_until timer]
    I --> J[Decrement availability\nheld_beds / held_units ++]

    J --> K{Hold timer\nexpired?}

    K -->|No — Admin acts| L{Admin\naction}
    L -->|Admit / Complete| M[Status → ADMITTED\n🔵 Terminal]

    K -->|Yes — Lazy Expiry\ntriggered on read| N[Status → EXPIRED\n⚪ Terminal]
    N --> O[Restore availability\nheld_beds / held_units --]

    P([Admin clicks\nClean Requests]) --> Q[Remove all terminal\nrequests from view]
    H --> Q
    M --> Q
    O --> Q

    style A fill:#e3f2fd,stroke:#1565c0,color:#000
    style E fill:#fff3e0,stroke:#ff9800,color:#000
    style H fill:#ffebee,stroke:#c62828,color:#000
    style I fill:#e8f5e9,stroke:#2e7d32,color:#000
    style M fill:#e3f2fd,stroke:#1565c0,color:#000
    style N fill:#f5f5f5,stroke:#616161,color:#000
    style C fill:#fff9c4,stroke:#f57f17,color:#000
```

---

## Figure 9: Authentication & Role Assignment Flowchart

```mermaid
flowchart TD
    A([User opens\nLogin Screen]) --> B{Auth\nmethod?}
    B -->|Email + Password| C1[Register or Sign In\nwith email/password]
    B -->|Google| C2[Firebase Auth\nsignInWithPopup]
    B -->|Forgot Password| FP[Enter email\nSend reset link]
    FP --> A

    C1 --> C{Sign-in\nsuccessful?}
    C2 --> C
    C -->|No| D[Show error message\nReturn to login]

    C -->|Yes| E{User document\nexists in Firestore?}

    E -->|Yes| F[Load existing\nUserModel]
    F --> G{Check user role}

    E -->|No - First time| L[Assign role:\npatient]
    L --> K[Create user document\nin Firestore]

    P[Trusted operator provisions\ninitial super_admin\nin Firebase Console] --> G

    K --> G

    G -->|super_admin| M[Redirect to\nSuper Admin Dashboard]
    G -->|org_admin| N[Redirect to\nOrg Admin Dashboard]
    G -->|patient| O[Redirect to\nHome Screen]

    style A fill:#e3f2fd,stroke:#1565c0,color:#000
    style C1 fill:#e3f2fd,stroke:#1565c0,color:#000
    style C2 fill:#e3f2fd,stroke:#1565c0,color:#000
    style FP fill:#fff9c4,stroke:#f57f17,color:#000
    style L fill:#e8f5e9,stroke:#2e7d32,color:#000
    style P fill:#fce4ec,stroke:#c62828,color:#000
    style M fill:#f3e5f5,stroke:#6a1b9a,color:#000
    style N fill:#fff3e0,stroke:#e65100,color:#000
    style O fill:#e3f2fd,stroke:#1565c0,color:#000
```

---

## Figure 10: Lazy Expiry Algorithm Flowchart

```mermaid
flowchart TD
    A([Any user reads\na booking]) --> B{Status is\nCONFIRMED?}
    B -->|No| C[Return booking\nas-is]

    B -->|Yes| D{held_until\nis set?}
    D -->|No| C

    D -->|Yes| E{"DateTime.now()\n> held_until?"}
    E -->|No — Still valid| C

    E -->|Yes — Expired!| F[Update Firestore:\nstatus → expired]
    F --> G{Booking\ntype?}

    G -->|bed| H[Get bed doc\nheld_beds - 1]
    G -->|blood| I[Get blood_stock doc\nheld_units - 1]
    G -->|ambulance| J[Update vehicle\nstatus → available]

    H --> K[Return booking\nwith status: expired]
    I --> K
    J --> K

    style A fill:#e3f2fd,stroke:#1565c0,color:#000
    style F fill:#ffebee,stroke:#c62828,color:#000
    style K fill:#f5f5f5,stroke:#616161,color:#000
    style C fill:#e8f5e9,stroke:#2e7d32,color:#000
```

---

## Figure 11: Route Guard / Navigation Flowchart

```mermaid
flowchart TD
    A([User navigates\nto a route]) --> B{User\nauthenticated?}

    B -->|No| C{Route requires\nauth?}
    C -->|No| D[Allow navigation]
    C -->|Yes| E[Redirect to\n/login]

    B -->|Yes| F{Route is\n/login?}
    F -->|Yes| G{User role?}
    G -->|super_admin| H[Redirect to\n/super-admin/dashboard]
    G -->|org_admin| I[Redirect to\n/admin/dashboard]
    G -->|patient| J[Redirect to /]

    F -->|No| K{Route starts with\n/super-admin?}
    K -->|Yes| L{Is super_admin?}
    L -->|Yes| D
    L -->|No| M[Redirect to /]

    K -->|No| N{Route starts with\n/admin?}
    N -->|Yes| O{Is org_admin?}
    O -->|Yes| D
    O -->|No| M

    N -->|No| P{Route is\n/my-bookings or\n/booking/:id?}
    P -->|Yes & not logged in| E
    P -->|Otherwise| D

    style A fill:#e3f2fd,stroke:#1565c0,color:#000
    style D fill:#e8f5e9,stroke:#2e7d32,color:#000
    style E fill:#ffebee,stroke:#c62828,color:#000
    style M fill:#fff3e0,stroke:#e65100,color:#000
```

---

## Figure 12: Super Admin — Platform Management Flow

```mermaid
flowchart LR
    SA([Super Admin\nDashboard])

    SA --> MO[Manage\nOrganizations]
    SA --> MU[Manage\nUsers]
    SA --> VR[View All\nRequests]
    SA --> SD[Seed\nDemo Data]

    MO --> MO1[Add Organization\nname, type, address,\ncoordinates, phone]
    MO --> MO2[Edit Organization]
    MO --> MO3[Delete Organization]

    MU --> MU1[Search user\nby email]
    MU --> MU2[Change role\npatient → admin]
    MU --> MU3[Assign to\norganization]

    VR --> VR1[Filter: All]
    VR --> VR2[Filter: Beds]
    VR --> VR3[Filter: Blood]
    VR --> VR4[Filter: Ambulance]

    SD --> SD1{Organizations\nexist?}
    SD1 -->|No| SD2[Batch write:\n4 hospitals\n2 blood banks\n3 ambulance ops]
    SD1 -->|Yes| SD3[Hide seed\ndata card]

    style SA fill:#f3e5f5,stroke:#6a1b9a,color:#000
    style MO fill:#e3f2fd,stroke:#1565c0,color:#000
    style MU fill:#e8f5e9,stroke:#2e7d32,color:#000
    style VR fill:#fff3e0,stroke:#e65100,color:#000
    style SD fill:#fce4ec,stroke:#c62828,color:#000
```

---

## Figure 13: State Management Architecture

```mermaid
graph TB
    subgraph UI["Flutter Widget Tree"]
        MS[MaterialApp]
        AS[AppShell + NavBar]
        Screens[Feature Screens]
    end

    subgraph MP["MultiProvider (8 Providers)"]
        AP[AuthProvider\n• user, role, error\n• isAuthenticated\n• email/Google signIn\n• register/reset/signOut]
        LP[LocationProvider\n• lat/lng\n• distanceTo\n• formatDistance]
        OP[OrganizationProvider\n• organizations\n• fetchByType\n• getByType]
        BKP[BookingProvider\n• bookings\n• create/reject/admit\n• fetchByUser/Org]
        BedP[BedProvider\n• beds per hospital\n• fetchBedsForHospitals]
        BlP[BloodProvider\n• stock per bank\n• fetchStockForBanks]
        AmP[AmbulanceProvider\n• fleet per operator\n• fetchFleet]
        TP[TestProvider\n• tests per hospital\n• search by name]
    end

    subgraph SVC["Service Layer"]
        AuthS[AuthService]
        FireS[FirestoreService]
        PresS[PrescriptionService]
        LocS[LocationService]
        SeedS[SeedDataService]
    end

    MS --> MP
    MP --> UI
    Screens -->|context.watch / read| MP
    AP --> AuthS
    AP --> FireS
    OP --> FireS
    BKP --> FireS
    BedP --> FireS
    BlP --> FireS
    AmP --> FireS
    TP --> FireS
    LP --> LocS

    style UI fill:#e3f2fd,stroke:#1565c0,color:#000
    style MP fill:#fff3e0,stroke:#e65100,color:#000
    style SVC fill:#e8f5e9,stroke:#2e7d32,color:#000
```

---

## Figure 14: Firestore Security Rules — Access Control Matrix

```mermaid
flowchart LR
    subgraph Roles
        PAT["👤 Patient"]
        BA["🛏️ Bed Admin"]
        TA["🧪 Diagnostic Test Admin"]
        BBA["🩸 Blood Bank Admin"]
        AA["🚑 Ambulance Admin"]
        SA["👑 Super Admin"]
    end

    subgraph Collections
        Orgs["organizations"]
        Beds["beds subcollection"]
        Blood["blood_stock subcollection"]
        Ambs["ambulances subcollection"]
        Tests["tests subcollection"]
        BReq["booking_requests"]
        UsersCol["users"]
    end

    PAT -->|"read"| Orgs
    PAT -->|"read"| Beds
    PAT -->|"read"| Blood
    PAT -->|"read"| Ambs
    PAT -->|"read"| Tests
    PAT -->|"create if profile complete"| BReq
    PAT -->|"read own bookings"| BReq
    PAT -->|"read and update own"| UsersCol

    BA -->|"read and write"| Beds
    BA -->|"read and update bed requests"| BReq
    TA -->|"read and write"| Tests

    BBA -->|"read and write"| Blood
    BBA -->|"read and update own org"| BReq

    AA -->|"read and write"| Ambs
    AA -->|"read and update own org"| BReq

    SA -->|"read and write ALL"| Orgs
    SA -->|"read and write ALL"| Beds
    SA -->|"read and write ALL"| Blood
    SA -->|"read and write ALL"| Ambs
    SA -->|"read and write ALL"| Tests
    SA -->|"read and update ALL"| BReq
    SA -->|"read and update ALL"| UsersCol

    style PAT fill:#e8f5e9,stroke:#2e7d32,color:#000
    style BA fill:#e3f2fd,stroke:#1565c0,color:#000
    style TA fill:#ede7f6,stroke:#6a1b9a,color:#000
    style BBA fill:#fce4ec,stroke:#c62828,color:#000
    style AA fill:#fff3e0,stroke:#e65100,color:#000
    style SA fill:#f3e5f5,stroke:#6a1b9a,color:#000
```
