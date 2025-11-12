import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 🏆 Create a Challenge
router.post("/create", verifyToken(["team"]), async (req, res) => {
  try {
    const { courtFirebaseUID, stime, etime } = req.body;
    const hostTeamUID = req.user.uid; // logged-in team's Firebase UID

    // 🔹 Get team info by userId
    const teamQuery = await db
      .collection("teams")
      .where("userId", "==", hostTeamUID)
      .limit(1)
      .get();

    if (teamQuery.empty) {
      return res.status(404).json({ error: "Team not found" });
    }

    const teamDoc = teamQuery.docs[0];
    const teamData = teamDoc.data();
    const sport = teamData.sports;

    // ✅ Build challenge data
    const challengeData = {
      hostTeamID: hostTeamUID,
      teamName: teamData.teamName,
      sport,
      courtFirebaseUID,
      stime,
      etime,
      status: "pending",
      createdAt: new Date(),
    };

    // ✅ Save to Firestore
    const docRef = await db.collection("challenges").add(challengeData);

    res.status(201).json({
      message: "Challenge created successfully ✅",
      challengeID: docRef.id,
      challenge: challengeData,
    });
  } catch (error) {
    console.error("Error creating challenge:", error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
