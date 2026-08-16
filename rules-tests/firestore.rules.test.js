const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { after, before, beforeEach, describe, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  Bytes,
  Timestamp,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require("firebase/firestore");

const PROJECT_ID = "demo-health-hub-rules";
const RULES = readFileSync(join(__dirname, "..", "firestore.rules"), "utf8");

let testEnv;

function emulatorAddress() {
  const value = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  const separator = value.lastIndexOf(":");
  return {
    host: value.slice(0, separator),
    port: Number(value.slice(separator + 1)),
  };
}

function dbFor(uid, email = `${uid}@example.test`) {
  return testEnv.authenticatedContext(uid, { email }).firestore();
}

function profile(uid, overrides = {}) {
  return {
    email: `${uid}@example.test`,
    name: "Test User",
    phone: "+8801712345678",
    profile_complete: true,
    role: "patient",
    organization_id: null,
    access_revoked: false,
    ...overrides,
  };
}

function organization(overrides = {}) {
  return {
    name: "Mirpur General Hospital",
    type: "hospital",
    verified: true,
    archived: false,
    ...overrides,
  };
}

function bedInventory(overrides = {}) {
  return {
    type: "General",
    total_beds: 10,
    held_beds: 0,
    admitted_beds: 0,
    price_per_day: 1500,
    hold_duration_minutes: 60,
    ...overrides,
  };
}

async function seed(entries) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all(
      entries.map(([path, data]) => setDoc(doc(db, path), data)),
    );
  });
}

function bedBooking(overrides = {}) {
  return {
    type: "bed",
    organization_id: "hospital-1",
    organization_name: "Mirpur General Hospital",
    user_id: "patient-1",
    patient_name: "Patient One",
    contact_number: "+8801712345678",
    status: "pending",
    held_until: null,
    estimated_price: 1500,
    created_at: serverTimestamp(),
    bed_id: "general",
    bed_type: "General",
    prescription_document_id: "bed-request-1",
    ...overrides,
  };
}

function createBedBooking(db, requestId, overrides = {}) {
  const booking = bedBooking({
    prescription_document_id: requestId,
    ...overrides,
  });
  const batch = writeBatch(db);
  batch.set(doc(db, "booking_requests", requestId), booking);
  batch.set(doc(db, "prescription_documents", requestId), {
    booking_id: requestId,
    user_id: booking.user_id,
    organization_id: booking.organization_id,
    booking_type: "bed",
    content_type: "image/png",
    image_bytes: Bytes.fromUint8Array(new Uint8Array([1, 2, 3])),
    created_at: serverTimestamp(),
  });
  return batch.commit();
}

function dhakaDateParts(dayOffset = 0) {
  const date = new Date(Date.now() + 6 * 60 * 60 * 1000);
  date.setUTCDate(date.getUTCDate() + dayOffset);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}

function diagnosticBooking({ requestId, serial, arrival, date }) {
  return {
    type: "test",
    organization_id: "hospital-1",
    organization_name: "Mirpur General Hospital",
    user_id: "patient-1",
    patient_name: "Patient One",
    contact_number: "+8801712345678",
    status: "pending",
    estimated_price: 500,
    created_at: serverTimestamp(),
    called_at: null,
    completed_at: null,
    test_id: "cbc",
    test_name: "CBC",
    serial_number: serial,
    queue_date: `${date.year}-${date.month}-${date.day}`,
    queue_year: date.year,
    queue_month: date.month,
    queue_day: date.day,
    queue_counter_id: "cbc",
    estimated_arrival_time: arrival,
    request_id: requestId,
  };
}

function claimData(requestId, date) {
  return {
    organization_id: "hospital-1",
    test_id: "cbc",
    user_id: "patient-1",
    booking_id: requestId,
    queue_year: date.year,
    queue_month: date.month,
    queue_day: date.day,
    created_at: serverTimestamp(),
  };
}

function createDiagnosticBooking(db, { requestId, serial, arrival, date }) {
  const dailyId = `${date.year}_${date.month}_${date.day}_cbc`;
  const claimId = `hospital-1_${dailyId}`;
  const batch = writeBatch(db);

  batch.set(
    doc(db, "booking_requests", requestId),
    diagnosticBooking({ requestId, serial, arrival, date }),
  );

  const counterRef = doc(
    db,
    "organizations/hospital-1/test_queue_counters/cbc",
  );
  const dailyRef = doc(
    db,
    `organizations/hospital-1/test_daily_capacity/${dailyId}`,
  );

  if (serial === 1) {
    batch.set(counterRef, {
      test_id: "cbc",
      queue_year: date.year,
      queue_month: date.month,
      queue_day: date.day,
      last_serial: 1,
      last_called_serial: 0,
      active_request_id: null,
      last_queue_action_id: null,
      last_estimated_arrival: arrival,
      last_request_id: requestId,
    });
    batch.set(dailyRef, {
      test_id: "cbc",
      queue_year: date.year,
      queue_month: date.month,
      queue_day: date.day,
      capacity: 10,
      used: 1,
      remaining: 9,
      last_request_id: requestId,
    });
  } else {
    batch.update(counterRef, {
      last_serial: serial,
      last_estimated_arrival: arrival,
      last_request_id: requestId,
      updated_at: serverTimestamp(),
    });
    batch.update(dailyRef, {
      capacity: 10,
      used: serial,
      remaining: 10 - serial,
      last_request_id: requestId,
      updated_at: serverTimestamp(),
    });
  }

  batch.set(
    doc(db, `users/patient-1/diagnostic_serial_claims/${claimId}`),
    claimData(requestId, date),
  );
  return batch.commit();
}

function confirmBed(db, shape) {
  const bookingRef = doc(db, "booking_requests/bed-confirmation");
  const bedRef = doc(db, "organizations/hospital-1/beds/general");
  const batch = writeBatch(db);
  const update = {
    status: "confirmed",
    bed_id: "general",
  };

  if (shape === "legacy" || shape === "mixed") {
    update.held_until = Timestamp.fromMillis(Date.now() + 30 * 60 * 1000);
  } else {
    update.held_until = null;
  }
  if (shape === "new" || shape === "mixed") {
    update.confirmed_at = serverTimestamp();
    update.hold_duration_minutes = 60;
  }

  batch.update(bookingRef, update);
  batch.update(bedRef, { held_beds: 1 });
  return batch.commit();
}

async function dischargeBed(db, decrement) {
  const bookingRef = doc(db, "booking_requests/bed-discharge");
  const bedRef = doc(db, "organizations/hospital-1/beds/general");
  return runTransaction(db, async (transaction) => {
    const bookingSnapshot = await transaction.get(bookingRef);
    const bedSnapshot = await transaction.get(bedRef);
    if (!bookingSnapshot.exists() || !bedSnapshot.exists()) {
      throw new Error("Discharge fixture is missing");
    }
    transaction.update(bookingRef, {
      status: "discharged",
      discharged_at: serverTimestamp(),
    });
    transaction.update(bedRef, {
      admitted_beds: bedSnapshot.data().admitted_beds - decrement,
    });
  });
}

before(async () => {
  const { host, port } = emulatorAddress();
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host, port, rules: RULES },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe("revoked access and profiles", () => {
  test("revoked user can read self profile but cannot read or create bookings", async () => {
    await seed([
      ["users/revoked-user", profile("revoked-user", { access_revoked: true })],
      ["organizations/hospital-1", organization()],
      ["organizations/hospital-1/beds/general", bedInventory()],
      [
        "booking_requests/existing-booking",
        {
          type: "bed",
          organization_id: "hospital-1",
          user_id: "revoked-user",
          status: "pending",
        },
      ],
    ]);
    const db = dbFor("revoked-user");

    await assertSucceeds(getDoc(doc(db, "users/revoked-user")));
    await assertFails(getDoc(doc(db, "booking_requests/existing-booking")));
    await assertFails(
      createBedBooking(db, "revoked-booking", { user_id: "revoked-user" }),
    );
  });

  test("active user can complete a profile with a canonical phone", async () => {
    await seed([
      [
        "users/patient-1",
        profile("patient-1", {
          name: null,
          phone: null,
          profile_complete: false,
        }),
      ],
    ]);

    await assertSucceeds(
      updateDoc(doc(dbFor("patient-1"), "users/patient-1"), {
        name: "Patient One",
        phone: "+8801712345678",
        profile_complete: true,
      }),
    );
  });

  test("active user cannot complete a profile with punctuation in the phone", async () => {
    await seed([
      [
        "users/patient-1",
        profile("patient-1", {
          name: null,
          phone: null,
          profile_complete: false,
        }),
      ],
    ]);

    await assertFails(
      updateDoc(doc(dbFor("patient-1"), "users/patient-1"), {
        name: "Patient One",
        phone: "01712-345678",
        profile_complete: true,
      }),
    );
  });
});

describe("organization lifecycle", () => {
  test("active organization accepts a valid bed booking", async () => {
    await seed([
      ["users/patient-1", profile("patient-1")],
      ["organizations/hospital-1", organization()],
      ["organizations/hospital-1/beds/general", bedInventory()],
    ]);

    await assertSucceeds(
      createBedBooking(dbFor("patient-1"), "active-org-booking"),
    );
  });

  test("archived organization rejects a new bed booking", async () => {
    await seed([
      ["users/patient-1", profile("patient-1")],
      ["organizations/hospital-1", organization({ archived: true })],
      ["organizations/hospital-1/beds/general", bedInventory()],
    ]);

    await assertFails(
      createBedBooking(dbFor("patient-1"), "archived-org-booking"),
    );
  });

  test("archived organization rejects a new admin assignment", async () => {
    await seed([
      ["users/super-admin", profile("super-admin", { role: "super_admin" })],
      ["users/target-user", profile("target-user")],
      ["organizations/hospital-1", organization({ archived: true })],
    ]);

    await assertFails(
      updateDoc(doc(dbFor("super-admin"), "users/target-user"), {
        role: "bed_admin",
        organization_id: "hospital-1",
      }),
    );
  });

  test("organization cannot be archived in the same batch as an admin assignment", async () => {
    await seed([
      ["users/super-admin", profile("super-admin", { role: "super_admin" })],
      ["users/target-user", profile("target-user")],
      ["organizations/hospital-1", organization()],
    ]);
    const db = dbFor("super-admin");
    const batch = writeBatch(db);
    batch.update(doc(db, "organizations/hospital-1"), { archived: true });
    batch.update(doc(db, "users/target-user"), {
      role: "bed_admin",
      organization_id: "hospital-1",
    });

    await assertFails(batch.commit());
  });
});

describe("bed inventory and lifecycle", () => {
  test("bed admin cannot save inventory whose held and admitted total is impossible", async () => {
    await seed([
      [
        "users/bed-admin",
        profile("bed-admin", {
          role: "bed_admin",
          organization_id: "hospital-1",
        }),
      ],
      ["organizations/hospital-1", organization()],
      [
        "organizations/hospital-1/beds/general",
        bedInventory({ held_beds: 3, admitted_beds: 4 }),
      ],
    ]);

    await assertFails(
      updateDoc(
        doc(dbFor("bed-admin"), "organizations/hospital-1/beds/general"),
        { total_beds: 6 },
      ),
    );
  });

  test("discharge requires an exact decrement and cannot be repeated", async () => {
    await seed([
      [
        "users/bed-admin",
        profile("bed-admin", {
          role: "bed_admin",
          organization_id: "hospital-1",
        }),
      ],
      ["organizations/hospital-1", organization()],
      [
        "organizations/hospital-1/beds/general",
        bedInventory({ admitted_beds: 2 }),
      ],
      [
        "booking_requests/bed-discharge",
        {
          type: "bed",
          organization_id: "hospital-1",
          user_id: "patient-1",
          bed_id: "general",
          bed_type: "General",
          status: "admitted",
        },
      ],
    ]);
    const db = dbFor("bed-admin");

    await assertFails(dischargeBed(db, 2));
    await assertSucceeds(dischargeBed(db, 1));
    await assertFails(dischargeBed(db, 1));
  });

  for (const shape of ["legacy", "new"]) {
    test(`${shape} hold shape is accepted`, async () => {
      await seed([
        [
          "users/bed-admin",
          profile("bed-admin", {
            role: "bed_admin",
            organization_id: "hospital-1",
          }),
        ],
        ["organizations/hospital-1", organization()],
        ["organizations/hospital-1/beds/general", bedInventory()],
        [
          "booking_requests/bed-confirmation",
          {
            type: "bed",
            organization_id: "hospital-1",
            user_id: "patient-1",
            bed_id: "general",
            bed_type: "General",
            status: "pending",
            held_until: null,
          },
        ],
      ]);

      await assertSucceeds(confirmBed(dbFor("bed-admin"), shape));
    });
  }

  test("mixed legacy and new hold fields are rejected", async () => {
    await seed([
      [
        "users/bed-admin",
        profile("bed-admin", {
          role: "bed_admin",
          organization_id: "hospital-1",
        }),
      ],
      ["organizations/hospital-1", organization()],
      ["organizations/hospital-1/beds/general", bedInventory()],
      [
        "booking_requests/bed-confirmation",
        {
          type: "bed",
          organization_id: "hospital-1",
          user_id: "patient-1",
          bed_id: "general",
          bed_type: "General",
          status: "pending",
          held_until: null,
        },
      ],
    ]);

    await assertFails(confirmBed(dbFor("bed-admin"), "mixed"));
  });
});

describe("diagnostic serial claims", () => {
  test("one current-day claim succeeds and a duplicate claim is rejected", async () => {
    await seed([
      ["users/patient-1", profile("patient-1")],
      ["organizations/hospital-1", organization()],
      [
        "organizations/hospital-1/tests/cbc",
        {
          test_name: "CBC",
          price: 500,
          daily_capacity: 10,
          slot_duration_minutes: 15,
          is_available: true,
        },
      ],
    ]);
    const db = dbFor("patient-1");
    const date = dhakaDateParts();
    const firstArrival = Timestamp.fromMillis(Date.now() + 10 * 60 * 1000);
    const secondArrival = Timestamp.fromMillis(
      firstArrival.toMillis() + 15 * 60 * 1000,
    );

    await assertSucceeds(
      createDiagnosticBooking(db, {
        requestId: "diagnostic-1",
        serial: 1,
        arrival: firstArrival,
        date,
      }),
    );
    await assertFails(
      createDiagnosticBooking(db, {
        requestId: "diagnostic-2",
        serial: 2,
        arrival: secondArrival,
        date,
      }),
    );
  });

  test("stale diagnostic booking can expire but cannot run a queue action", async () => {
    const stale = dhakaDateParts(-1);
    const staleFields = {
      type: "test",
      organization_id: "hospital-1",
      user_id: "patient-1",
      test_id: "cbc",
      queue_counter_id: "cbc",
      serial_number: 1,
      queue_year: stale.year,
      queue_month: stale.month,
      queue_day: stale.day,
      status: "pending",
      called_at: null,
      completed_at: null,
    };
    await seed([
      ["users/patient-1", profile("patient-1")],
      [
        "users/test-admin",
        profile("test-admin", {
          role: "test_admin",
          organization_id: "hospital-1",
        }),
      ],
      ["organizations/hospital-1", organization()],
      ["booking_requests/stale-owner", staleFields],
      ["booking_requests/stale-admin", staleFields],
    ]);

    await assertSucceeds(
      updateDoc(doc(dbFor("patient-1"), "booking_requests/stale-owner"), {
        status: "expired",
      }),
    );
    await assertFails(
      updateDoc(doc(dbFor("test-admin"), "booking_requests/stale-admin"), {
        status: "rejected",
      }),
    );
  });
});
