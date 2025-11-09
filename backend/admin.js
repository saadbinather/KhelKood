import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 🟢 Verify a user by Firebase UID and log in verification table
router.post("/verify-user", verifyToken(["admin"]), async (req, res) => {
  try {
    const userId = req.body.userId?.trim();
    if (!userId) return res.status(400).json({ error: "Missing userId" });

    // 1️⃣ Try to find the user by `uid` field (not document ID)
    const userQuery = await db
      .collection("users")
      .where("uid", "==", userId)
      .limit(1)
      .get();

    if (userQuery.empty)
      return res.status(404).json({ error: "User not found in Firestore" });

    const userDoc = userQuery.docs[0];
    const userRef = userDoc.ref;
    const userData = userDoc.data();

    // 2️⃣ Update verification status
    await userRef.update({ verificationStatus: "verified" });

    // 3️⃣ Log verification in 'verifications' collection
    await db.collection("verifications").add({
      User_ID: userId,
      Name: userData.name || "Unknown",
      Email: userData.email || "Unknown",
      Status: "Verified",
      Created_At: new Date().toISOString(),
    });

    res.json({
      message: "✅ User verified successfully",
      user: {
        userId,
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
