// truncate_collections.js
import { db } from "../config/firebase.js";

// All collections to truncate (except admins)
const collectionsToTruncate = [
  "bookings",
  "challenges",
  "courtowners",
  "courts",
  "matches",
  "payments",
  "players",
  "results",
  "reviews",
  "teams",
  "users",
  "verifications"
];

async function truncateCollection(collectionName) {
  try {
    const collectionRef = db.collection(collectionName);
    const snapshot = await collectionRef.get();
    
    if (snapshot.empty) {
      console.log(`✅ ${collectionName}: Already empty`);
      return;
    }

    // Delete in batches (Firestore limit is 500 operations per batch)
    const batchSize = 500;
    const batches = [];
    let batch = db.batch();
    let count = 0;

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;

      if (count === batchSize) {
        batches.push(batch);
        batch = db.batch();
        count = 0;
      }
    });

    if (count > 0) {
      batches.push(batch);
    }

    // Execute all batches
    for (const batchToCommit of batches) {
      await batchToCommit.commit();
    }

    console.log(`✅ ${collectionName}: Deleted ${snapshot.size} documents`);
  } catch (error) {
    console.error(`❌ Error truncating ${collectionName}:`, error.message);
  }
}

async function truncateAll() {
  console.log("🚀 Starting truncation of collections...\n");

  for (const collectionName of collectionsToTruncate) {
    await truncateCollection(collectionName);
  }

  console.log("\n✨ All collections truncated successfully!");
}

// Run the truncation
truncateAll()
  .then(() => {
    console.log("Done!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });
