import admin from "firebase-admin";
import fs from "fs"; // 👈 ye line add karo

// 🔹 Load service account key
const serviceAccount = JSON.parse(
  fs.readFileSync("./serviceAccountKey.json", "utf8")
);

// 🔹 Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const createAdmin = async () => {
  const email = "pitahjee@khelkood.com";
  const password = "admin123";
  const name = "Master Admin";

  try {
    // 1️⃣ Create user in Firebase Authentication
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
    });

    // 2️⃣ Add to Firestore under "admins"
    await db.collection("admins").doc(userRecord.uid).set({
      userId: userRecord.uid,
      email,
      name,
      createdAt: new Date(),
    });

    console.log("✅ Admin created successfully!");
    console.log("UID:", userRecord.uid);
  } catch (error) {
    console.error("❌ Error creating admin:", error.message);
  }
};

// Run the function
createAdmin();
