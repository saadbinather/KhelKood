const admin = require("firebase-admin");

// ✅ Initialize Firebase Admin SDK
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🏟️ Function to add a court owner
async function addCourtOwner() {
  try {
    const courtOwnerData = {
      Name: "Ali Khan",
      Number: "+92 300 1234567",
      Email: "ali.khan@example.com",
      User_ID: "user123", // ID of the user from 'users' collection
      Created_At: new Date().toISOString(),
    };

    // ✅ Add to the "courtOwners" collection
    const ownerRef = await db.collection("courtOwners").add(courtOwnerData);

    console.log(`✅ Court Owner added successfully with ID: ${ownerRef.id}`);
  } catch (error) {
    console.error("🔥 Error adding court owner:", error);
  }
}

// Run the function
addCourtOwner();
