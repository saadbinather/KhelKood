import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// ✅ Verify user by Firestore doc ID (foreign key style)
router.post("/verify-user", verifyToken(["admin"]), async (req, res) => {
  try {
    const userDocId = req.body.userDocId?.trim();
    if (!userDocId) return res.status(400).json({ error: "Missing userDocId" });

    // 1️⃣ Fetch user doc from 'users' collection by document ID
    const userRef = db.collection("users").doc(userDocId);
    const userDoc = await userRef.get();

    if (!userDoc.exists)
      return res.status(404).json({ error: "User not found in Firestore" });

    const userData = userDoc.data();

    // 2️⃣ Update verification status in 'users'
    await userRef.update({ verificationStatus: "verified" });

    // 3️⃣ Log verification in 'verifications' collection
    await db.collection("verifications").add({
      User_ID: userDocId, // foreign key reference to users doc
      Name: userData.name || "Unknown",
      Email: userData.email || "Unknown",
      Status: "Verified",
      Created_At: new Date().toISOString(),
    });

    // 4️⃣ Respond success
    res.json({
      message: "✅ User verified successfully",
      user: {
        id: userDocId,
        name: userData.name,
        email: userData.email,
      },
    });
  } catch (error) {
    console.error("Verify user error:", error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
