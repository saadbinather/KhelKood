// middleware/verifyToken.js
import { admin } from "../config/firebase.js";

export const verifyToken = async (req, res, next) => {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: "Missing token" });

  const token = header.split(" ")[1];
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded; // { uid, email, ... }
    next();
  } catch (error) {
    res.status(403).json({ error: "Invalid or expired token" });
  }
};
