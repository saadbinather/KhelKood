import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 🏆 Create a Challenge
router.post("/create", verifyToken(["team"]), async (req, res) => {
  try {
    const { courtFirebaseUID, stime, etime } = req.body;
    const hostTeamID = req.user.uid; // logged-in team UID

    // Get team info
    const teamDoc = await db.collection("teams").doc(hostTeamID).get();
    if (!teamDoc.exists)
      return res.status(404).json({ error: "Team not found" });

    const sport = teamDoc.data().sports || "Futsal";

    // Build challenge data
    const challengeData = {
      Court_ID: courtFirebaseUID, // long Firebase UID string
      Host_Team_ID: hostTeamID,
      Sport: sport,
      Status: "Pending",
      StartTime: stime || new Date().toISOString(),
      EndTime: etime,
      createdAt: new Date(),
    };

    // Save to Firestore
    const docRef = await db.collection("challenges").add(challengeData);

    res.status(201).json({
      message: "Challenge created successfully ✅",
      challengeID: docRef.id,
      challenge: challengeData,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
