import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// ✏️ Update Team Profile
router.put("/edit-profile", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid; // Automatically from logged-in user
    const updates = req.body;

    // Reference the team document
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();

    if (!teamDoc.exists) {
      return res.status(404).json({ error: "Team not found." });
    }

    // Update the team's Firestore document
    await teamRef.update({
      ...updates,
      updatedAt: new Date(),
    });

    res.json({
      message: "Team profile updated successfully ✅",
      updatedFields: updates,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 🏆 Get Logged-in Team Details
router.get("/profile", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid;
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();

    if (!teamDoc.exists) {
      return res.status(404).json({ error: "Team not found." });
    }

    res.json({
      message: "Team profile fetched successfully ✅",
      team: { id: teamDoc.id, ...teamDoc.data() },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.post("/add-player", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid;
    const { playerName } = req.body;
    if (!playerName) return res.status(400).json({ error: "Player name is required." });

    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    if (!teamDoc.exists) return res.status(404).json({ error: "Team not found." });

    // Add player to team's array
    await teamRef.update({
      players: [...(teamDoc.data().players || []), playerName],
      updatedAt: new Date(),
    });

    // Optionally, add to players collection
    await db.collection("players").add({
      name: playerName,
      teamID,
      createdAt: new Date(),
    });

    res.json({ message: `Player "${playerName}" added successfully ✅` });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ➖ Remove Player
router.post("/remove-player", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid;
    const { playerName } = req.body;
    if (!playerName) return res.status(400).json({ error: "Player name is required." });

    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    if (!teamDoc.exists) return res.status(404).json({ error: "Team not found." });

    const updatedPlayers = (teamDoc.data().players || []).filter(p => p !== playerName);
    await teamRef.update({ players: updatedPlayers, updatedAt: new Date() });

    // Also remove from players collection
    const snapshot = await db.collection("players")
      .where("teamID", "==", teamID)
      .where("name", "==", playerName)
      .get();
    snapshot.forEach(doc => doc.ref.delete());

    res.json({ message: `Player "${playerName}" removed successfully ✅` });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
