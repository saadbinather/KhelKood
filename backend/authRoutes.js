import express from "express";
import axios from "axios";
import { db } from "./config/firebase.js";

const router = express.Router();

// Replace with your Firebase project's web API key
const FIREBASE_WEB_API_KEY = "AIzaSyDOJ8Ah8PRwqiQAJgAhiPWJAReYOchgGh4";

// -------------------- SIGNUP --------------------
router.post("/signup", async (req, res) => {
  const { email, password, name, role } = req.body;

  try {
    // 1️⃣ Create Firebase Auth user
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_WEB_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const { localId: firebase_uid } = response.data;

    // 2️⃣ Create a base user record in "users"
    const userData = {
      name,
      email,
      role,
      verificationStatus: "pending",
      createdAt: new Date(),
    };

    await db.collection("users").doc(firebase_uid).set(userData);

    // 3️⃣ Also insert into role-specific collection
    if (role === "admin") {
      await db.collection("admins").doc(firebase_uid).set({
        userId: firebase_uid,
        name,
        email,
        createdAt: new Date(),
      });
    } else if (role === "courtowner") {
      await db.collection("courtowners").doc(firebase_uid).set({
        userId: firebase_uid,
        name,
        email,
        courtName: "",
        location: "",
        createdAt: new Date(),
      });
    } else if (role === "team") {
      await db.collection("teams").doc(firebase_uid).set({
        userId: firebase_uid,
        teamName: name,
        email,
        players: [],
        createdAt: new Date(),
      });
    }

    res.status(201).json({
      message: `Signup successful as ${role}`,
      uid: firebase_uid,
    });
  } catch (error) {
    console.error("Signup error:", error.response?.data || error.message);
    res.status(400).json({
      error: error.response?.data?.error?.message || error.message,
    });
  }
});

// -------------------- LOGIN --------------------
router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  try {
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const { idToken, localId: firebase_uid } = response.data;
    res.status(200).json({ token: idToken, firebase_uid });
  } catch (error) {
    res.status(400).json({
      error: error.response?.data?.error?.message || error.message,
    });
  }
});

export default router;
