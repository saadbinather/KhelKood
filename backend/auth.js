import express from "express";
import axios from "axios";
import { db } from "./config/firebase.js";

const router = express.Router();

// Replace with your Firebase project's web API key
const FIREBASE_WEB_API_KEY = "AIzaSyDOJ8Ah8PRwqiQAJgAhiPWJAReYOchgGh4";

// -------------------- SIGNUP --------------------
router.post("/signup", async (req, res) => {
  const {
    email,
    password,
    name,
    role,
    teamName,
    sports,
    phone,
    players, // array of player names for team
    courtName,
    location,
    courtAddress,
    courtTitle,
    numOfCricketFields,
    numOfPadelCourts,
    numOfPadelFields,
    rating,
  } = req.body;

  try {
    // 1️⃣ Create Firebase Auth user
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_WEB_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const { localId: firebase_uid } = response.data;

    // 2️⃣ Base user record in "users" collection
    const userData = {
      name,
      email,
      role,
      verificationStatus: "pending",
      createdAt: new Date(),
    };

    await db.collection("users").doc(firebase_uid).set(userData);

    // 3️⃣ Role-specific handling
    if (role === "courtowner") {
      // Step 1: Add to "courtowners" table
      const courtownerData = {
        userId: firebase_uid,
        name,
        email,
        courtName: courtName || "",
        location: location || "",
        createdAt: new Date(),
      };

      await db.collection("courtowners").doc(firebase_uid).set(courtownerData);

      // Step 2: Add to "courts" table
      const courtData = {
        name: courtTitle || "Sports Arena DHA",
        address: courtAddress || "Johar Town Lahore",
        courtownerID: firebase_uid,
        numOfCricketFields: Number(numOfCricketFields) || 1,
        numOfPadelCourts: Number(numOfPadelCourts) || 2,
        numOfPadelFields: Number(numOfPadelFields) || 1,
        rating: Number(rating) || 9.0,
        createdAt: new Date(),
      };

      await db.collection("courts").add(courtData);
    }

    // ---------------- TEAM ROLE ----------------
    else if (role === "team") {
      // Step 1: Add team info to "teams"
      const teamData = {
        userId: firebase_uid,
        email,
        phone: phone || "",
        teamName: teamName || name,
        sports: sports || "futsal",
        players: players || [],
        createdAt: new Date(),
      };

      await db.collection("teams").doc(firebase_uid).set(teamData);

      // Step 2: Add each player to "players" table
      if (Array.isArray(players) && players.length > 0) {
        for (const playerName of players) {
          const playerData = {
            name: playerName,
            teamID: firebase_uid,
            createdAt: new Date(),
          };
          await db.collection("players").add(playerData);
        }
      }
    }

    // ✅ Success Response
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
