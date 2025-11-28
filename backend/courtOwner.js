import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

/*
=====================================================
📝 PUT 1 — Update Courtowner Profile
=====================================================
*/
router.put(
  "/edit-courtowner",
  verifyToken(["courtowner"]),
  async (req, res) => {
    try {
      const ownerID = req.user.uid;
      const updates = req.body;

      const ownerRef = db.collection("courtowners").doc(ownerID);
      const ownerDoc = await ownerRef.get();

      if (!ownerDoc.exists) {
        return res.status(404).json({ error: "Courtowner not found." });
      }

      await ownerRef.update({
        ...updates,
        updatedAt: new Date(),
      });

      res.json({
        message: "Courtowner profile updated successfully ✅",
        updatedFields: updates,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

/*
=====================================================
🏟️ PUT 2 — Update a Court (Single Court by ID)
=====================================================
*/
router.put("/edit-court", verifyToken(["courtowner"]), async (req, res) => {
  try {
    const ownerID = req.user.uid;
    const updates = req.body;

    // Get all courts owned by this courtowner
    const courtsQuery = db
      .collection("courts")
      .where("courtownerID", "==", ownerID);

    const courtsSnapshot = await courtsQuery.get();

    if (courtsSnapshot.empty) {
      return res
        .status(404)
        .json({ error: "No court found for this courtowner." });
    }

    // Batch update all owned courts
    const batch = db.batch();

    courtsSnapshot.forEach((courtDoc) => {
      const courtRef = db.collection("courts").doc(courtDoc.id);
      batch.update(courtRef, {
        ...updates,
        updatedAt: new Date(),
      });
    });

    await batch.commit();

    res.json({
      message: "Court(s) updated successfully for this courtowner ✅",
      updatedFields: updates,
      updatedCourtsCount: courtsSnapshot.size,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/*
=====================================================
📌 GET 1 — Logged-in Courtowner Profile
=====================================================
*/
router.get(  "/courtowner-profile", verifyToken(["courtowner"]),async (req, res) => {
    try {
      const ownerID = req.user.uid;

      const ownerRef = db.collection("courtowners").doc(ownerID);
      const ownerDoc = await ownerRef.get();

      if (!ownerDoc.exists) {
        return res.status(404).json({ error: "Courtowner not found." });
      }

      res.json({
        message: "Courtowner profile fetched successfully ✅",
        courtowner: { id: ownerDoc.id, ...ownerDoc.data() },
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

/*
=====================================================
🏟️ GET 2 — Get Single Court Details (by Court ID)
=====================================================
*/
router.get(
  "/court/:courtID",
  verifyToken(["courtowner", "team", "admin"]),
  async (req, res) => {
    try {
      const courtID = req.params.courtID;

      const courtRef = db.collection("courts").doc(courtID);
      const courtDoc = await courtRef.get();

      if (!courtDoc.exists) {
        return res.status(404).json({ error: "Court not found." });
      }

      res.json({
        message: "Court details fetched successfully ✅",
        court: { id: courtDoc.id, ...courtDoc.data() },
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

// 🟦 GET Court Details for Logged-in Courtowner
router.get("/my-court", verifyToken(["courtowner"]), async (req, res) => {
  try {
    const ownerID = req.user.uid;

    // Find the court that belongs to this courtowner
    const courtQuery = await db
      .collection("courts")
      .where("courtownerID", "==", ownerID)
      .limit(1)
      .get();

    if (courtQuery.empty) {
      return res.status(404).json({
        error: "No court found for this courtowner.",
      });
    }

    const courtDoc = courtQuery.docs[0];

    res.json({
      message: "Court fetched successfully ✅",
      court: {
        id: courtDoc.id,
        ...courtDoc.data(),
      },
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

router.put( "/makewinner/:matchID",verifyToken(["courtowner"]),
  async (req, res) => {
    try {
      const courtownerID = req.user.uid; // logged-in courtowner UID
      const matchID = req.params.matchID;
      const { winnerID } = req.body;

      if (!winnerID) {
        return res.status(400).json({ error: "winnerID is required." });
      }

      // 1️⃣ Fetch match
      const matchRef = db.collection("matches").doc(matchID);
      const matchDoc = await matchRef.get();

      if (!matchDoc.exists) {
        return res.status(404).json({ error: "Match not found." });
      }

      const matchData = matchDoc.data();
      const { Court_ID, Host_Team_ID, Guest_Team_ID } = matchData;

      // 2️⃣ Validate winner ID belongs to one of the two teams
      if (winnerID !== Host_Team_ID && winnerID !== Guest_Team_ID) {
        return res.status(400).json({
          error: "winnerID must be either Host_Team_ID or Guest_Team_ID.",
        });
      }

      // 3️⃣ Fetch court of this match
      const courtDoc = await db.collection("courts").doc(Court_ID).get();

      if (!courtDoc.exists) {
        return res
          .status(404)
          .json({ error: "Court not found for this match." });
      }

      const courtData = courtDoc.data();

      // 4️⃣ Check court belongs to logged-in courtowner
      if (courtData.courtownerID !== courtownerID) {
        return res.status(403).json({
          error: "Unauthorized: You do not own the court for this match.",
        });
      }

      // 5️⃣ Update winner
      await matchRef.update({
        Winner: winnerID,
        updatedAt: new Date(),
      });

      res.json({
        message: "Winner updated successfully ✅",
        matchID,
        winnerID,
      });
    } catch (error) {
      console.error("❌ Error updating winner:", error);
      res.status(500).json({ error: error.message });
    }
  }
);

export default router;
