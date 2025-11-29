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
import courtownerRoutes from "./courtOwner.js";
import adminRoutes from "./admin.js";
import userRoutes from "./user.js";
import courtsRoutes from "./courts.js";
import { sendSuccess, sendError, sendNotFoundError } from "./utils/response.js";

const app = express();
app.use(express.json());
app.use(cors());

// ==================== ROUTES ====================
app.use("/api/admin", adminRoutes);
app.use("/api/user", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/courtowner", courtownerRoutes);
app.use("/api/team", teamRoutes);
app.use("/api/booking", bookingRoutes);
app.use("/api/match", matchRoutes);
app.use("/api/challenges", challengeRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/courts", courtsRoutes);

// ==================== ADDITIONAL ROUTES ====================
// Example protected route
app.get(
  "/api/profile",
  verifyToken(["team", "courtowner", "admin"]),
  async (req, res) => {
    try {
      const userDoc = await db.collection("users").doc(req.user.uid).get();
      if (!userDoc.exists) {
        return sendNotFoundError(res, "User");
      }
      return sendSuccess(res, 200, "Profile fetched successfully", {
        uid: req.user.uid,
        ...userDoc.data(),
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  }
);

// Courtowner dashboard route
app.get(
  "/courtowner/dashboard",
  verifyToken(["courtowner"]),
  async (req, res) => {
    try {
      return sendSuccess(res, 200, "Welcome, Court Owner 👋", {
        note: "You can manage your courts here!",
        user: req.user,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  }
);

// Team players route
app.get("/team/players", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user.uid;
    const snapshot = await db
      .collection("players")
      .where("teamID", "==", teamID)
      .get();
    const players = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));

    return sendSuccess(res, 200, "Team player list fetched successfully ✅", {
      count: players.length,
      players,
    });
  } catch (error) {
    return sendError(res, 500, error.message);
  }
});

// ==================== SERVER START ====================
const PORT = 5000;
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
