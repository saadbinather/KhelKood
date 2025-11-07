import express from "express";
import cors from "cors";
import authRoutes from "./authRoutes.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { db } from "./config/firebase.js";

const app = express();
app.use(express.json());
app.use(cors());

// Routes
app.use("/api/auth", authRoutes);

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

const PORT = 5000;
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}`));
