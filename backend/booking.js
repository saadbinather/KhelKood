import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 🏟️ Create a Booking
router.post("/book-court", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid; // Logged-in team UID
    const { courtID, startTime, endTime } = req.body;

    if (!courtID || !startTime || !endTime) {
      return res.status(400).json({ error: "courtID, startTime and endTime are required" });
    }

    // Optional: Check if court exists
    const courtRef = db.collection("courts").doc(courtID);
    const courtDoc = await courtRef.get();
    if (!courtDoc.exists) {
      return res.status(404).json({ error: "Court not found" });
    }

    // Create booking object
    const bookingData = {
      courtID,
      teamID,
      startTime: new Date(startTime),
      endTime: new Date(endTime),
      status: "Pending", // You can later add "Confirmed", "Cancelled"
      createdAt: new Date(),
    };

    // Save to Firestore
    const docRef = await db.collection("bookings").add(bookingData);

    res.status(201).json({
      message: "Booking created successfully ✅",
      bookingID: docRef.id,
      booking: bookingData,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
