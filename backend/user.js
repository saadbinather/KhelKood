import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError } from "./utils/response.js";

const router = express.Router();

// ADMIN ONLY API: View all unverified users
router.get("/unverified", verifyToken(["admin"]), async (req, res) => {
  try {
    // Fetch users with verificationStatus = "pending"
    const usersRef = db.collection("users");
    const snapshot = await usersRef.where("verificationStatus", "==", "pending").get();

    const unverifiedUsers = [];
    snapshot.forEach(doc => {
      unverifiedUsers.push({
        id: doc.id,
        ...doc.data()
      });
    });

    return sendSuccess(res, 200, "Unverified users fetched successfully", {
      count: unverifiedUsers.length,
      users: unverifiedUsers
    });
  } catch (error) {
    return sendError(res, 500, error.message);
  }
});

export default router;
