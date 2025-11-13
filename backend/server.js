import express from "express";
import cors from "cors";
import authRoutes from "./auth.js";
import teamRoutes from "./team.js";
import bookingRoutes from "./booking.js";
import matchRoutes from "./match.js";
import paymentRoutes from "./payments.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { db } from "./config/firebase.js";
import challengeRoutes from "./challenges.js";

const app = express();
app.use(express.json());
app.use(cors());
import adminRoutes from "./admin.js";
app.use("/api/admin", adminRoutes);

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/team", teamRoutes);
app.use("/api/booking", bookingRoutes);
app.use("/api/match",matchRoutes)
app.use("/api/challenges", challengeRoutes);
app.use("/api/payments", paymentRoutes);

// Example protected route
app.get("/api/profile", verifyToken, async (req, res) => {
  try {
    const userDoc = await db.collection("users").doc(req.user.uid).get();
    if (!userDoc.exists)
      return res.status(404).json({ error: "User not found" });
    res.json({ uid: req.user.uid, ...userDoc.data() });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// -------------------- COURTOWNER TEST ROUTE --------------------
app.get(
  "/courtowner/dashboard",
  verifyToken(["courtowner"]),
  async (req, res) => {
    try {
      res.json({
        message: `Welcome, Court Owner 👋`,
        note: "You can manage your courts here!",
        user: req.user,
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);

// -------------------- TEAM TEST ROUTE --------------------
// Edit Profile route
// app.put("/team/edit-profile", verifyToken, async (req, res) => {
//   try {
//     const { name, phone, age } = req.body;
//     const userRef = db.collection("users").doc(req.user.uid);

//     await userRef.update({ name, phone, age });
//     res.json({ message: "Profile updated successfully ✅" });
//   } catch (error) {
//     res.status(500).json({ error: error.message });
//   }
// });

app.get("/team/players", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid;

    // Fetch all players belonging to this team
    const snapshot = await db
      .collection("players")
      .where("teamID", "==", teamID)
      .get();
    const players = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

    res.json({
      message: `Team player list fetched successfully ✅`,
      count: players.length,
      players,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = 5000;
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
