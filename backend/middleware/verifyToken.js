// middleware/verifyToken.js
import { admin, db } from "../config/firebase.js";

/**
 * Middleware to verify Firebase token and optionally restrict by role.
 * Usage:
 *   router.get("/route", verifyToken()); // any logged-in user
 *   router.get("/route", verifyToken(["team"])); // only team role
 *   router.get("/route", verifyToken(["courtowner"])); // only courtowner
 */

export const verifyToken = (allowedRoles = []) => {
  return async (req, res, next) => {
    const header = req.headers.authorization;

    if (!header || !header.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Missing or invalid token" });
    }

    const token = header.split(" ")[1];

    try {
      // 🔹 Verify Firebase token
      const decoded = await admin.auth().verifyIdToken(token);
      const uid = decoded.uid;

      // 🔹 Fetch user role from Firestore
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        return res.status(404).json({ error: "User not found" });
      }

      const userData = userDoc.data();

      // 🔹 Role-based restriction (if any)
      if (allowedRoles.length > 0 && !allowedRoles.includes(userData.role)) {
        return res.status(403).json({ error: "Access denied for this role" });
      }

      // 🔹 Attach user info to request for downstream handlers
      req.user = { uid, email: decoded.email, role: userData.role };

      next();
    } catch (error) {
      console.error("Token verification error:", error.message);
      return res.status(403).json({ error: "Invalid or expired token" });
    }
  };
};
