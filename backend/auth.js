import express from "express";
import axios from "axios";
import { db } from "./config/firebase.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
} from "./utils/response.js";
import { validateRequired } from "./utils/validators.js";

const router = express.Router();

// Replace with your Firebase project's web API key
const FIREBASE_WEB_API_KEY = "AIzaSyDOJ8Ah8PRwqiQAJgAhiPWJAReYOchgGh4";

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for authentication

const AuthRepository = {
  async createFirebaseUser(email, password) {
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FIREBASE_WEB_API_KEY}`,
      { email, password, returnSecureToken: true }
    );
    return response.data.localId;
  },

  async createUser(firebase_uid, userData) {
    await db.collection("users").doc(firebase_uid).set(userData);
  },

  async createCourtowner(firebase_uid, courtownerData) {
    await db.collection("courtowners").doc(firebase_uid).set(courtownerData);
  },

  async createCourt(courtData) {
    const docRef = await db.collection("courts").add(courtData);
    return docRef.id;
  },

  async createTeam(firebase_uid, teamData) {
    await db.collection("teams").doc(firebase_uid).set(teamData);
  },

  async createPlayers(players, teamID) {
    if (Array.isArray(players) && players.length > 0) {
      const batch = db.batch();
      players.forEach((playerName) => {
        const playerRef = db.collection("players").doc();
        batch.set(playerRef, {
          name: playerName,
          teamID,
          createdAt: new Date(),
        });
      });
      await batch.commit();
    }
  },

  async findUserByUid(firebase_uid) {
    const userDoc = await db.collection("users").doc(firebase_uid).get();
    return userDoc.exists ? { id: userDoc.id, ...userDoc.data() } : null;
  },

  async findAdminByEmail(email) {
    const adminSnap = await db
      .collection("admins")
      .where("email", "==", email)
      .limit(1)
      .get();
    return !adminSnap.empty;
  },

  async loginFirebaseUser(email, password) {
    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_WEB_API_KEY}`,
      { email, password, returnSecureToken: true }
    );
    return {
      idToken: response.data.idToken,
      localId: response.data.localId,
    };
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle authentication business rules

const AuthService = {
  async signup(signupData) {
    const {
      email,
      password,
      name,
      role,
      teamName,
      sports,
      phone,
      players,
      courtName,
      location,
      courtAddress,
      courtTitle,
      numOfCricketFields,
      numOfPadelCourts,
      numOfFutsalFields,
      rating,
      padelRate,
      cricketRate,
      futsalRate,
      openingTime,
      closingTime,
    } = signupData;

    // Validation
    const validation = validateRequired({ email, password, name, role }, [
      "email",
      "password",
      "name",
      "role",
    ]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Create Firebase Auth user
    const firebase_uid = await AuthRepository.createFirebaseUser(
      email,
      password
    );

    // Create base user record
    const userData = {
      name,
      email,
      role,
      verificationStatus: "pending",
      createdAt: new Date(),
    };
    await AuthRepository.createUser(firebase_uid, userData);

    // Role-specific handling
    if (role === "courtowner") {
      const courtownerData = {
        userId: firebase_uid,
        name,
        email,
        courtName: courtName || "",
        location: location || "",
        createdAt: new Date(),
      };
      await AuthRepository.createCourtowner(firebase_uid, courtownerData);

      const courtData = {
        name: courtTitle || "Default Sports Arena",
        address: courtAddress || "Unknown Location",
        courtownerID: firebase_uid,
        numOfCricketFields: Number(numOfCricketFields) || 0,
        numOfPadelCourts: Number(numOfPadelCourts) || 0,
        numOfPadelFields: Number(numOfFutsalFields) || 0,
        cricketRate: Number(cricketRate) || 0,
        futsalRate: Number(futsalRate) || 0,
        padelRate: Number(padelRate) || 0,
        rating: Number(rating) || 0,
        openingTime: Number(openingTime) || 8,
        closingTime: Number(closingTime) || 23,
        createdAt: new Date(),
      };
      await AuthRepository.createCourt(courtData);
    } else if (role === "team") {
      const teamData = {
        userId: firebase_uid,
        email,
        phone: phone || "",
        teamName: teamName || name,
        sports: sports || "",
        players: players || [],
        createdAt: new Date(),
        points: 0,
      };
      await AuthRepository.createTeam(firebase_uid, teamData);
      await AuthRepository.createPlayers(players, firebase_uid);
    }

    return { firebase_uid, role };
  },

  async login(email, password) {
    // Validation
    const validation = validateRequired({ email, password }, [
      "email",
      "password",
    ]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Login via Firebase Auth
    const { idToken, localId: firebase_uid } =
      await AuthRepository.loginFirebaseUser(email, password);

    // Determine role
    const user = await AuthRepository.findUserByUid(firebase_uid);
    let role = "admin";

    if (user) {
      role = user.role;
      const status = (user.verificationStatus || "pending").toLowerCase();
      if (status !== "verified") {
        if (status === "rejected") {
          throw new Error(
            "Account rejected by admin. Please contact support for assistance."
          );
        }
        throw new Error("Account pending verification. Please wait for approval.");
      }
    } else {
      const isAdmin = await AuthRepository.findAdminByEmail(email);
      if (!isAdmin) {
        throw new Error("No matching user or admin found");
      }
    }

    return { idToken, firebase_uid, role };
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const AuthController = {
  async signup(req, res) {
    try {
      const result = await AuthService.signup(req.body);
      return sendSuccess(res, 201, `Signup successful as ${result.role}`, {
        uid: result.firebase_uid,
      });
    } catch (error) {
      const errorMessage =
        error.response?.data?.error?.message || error.message;
      if (errorMessage.includes("required")) {
        return sendValidationError(res, errorMessage);
      }
      return sendError(res, 400, errorMessage);
    }
  },

  async login(req, res) {
    try {
      const { idToken, firebase_uid, role } = await AuthService.login(
        req.body.email,
        req.body.password
      );
      return sendSuccess(res, 200, `Login successful as ${role}`, {
        token: idToken,
        firebase_uid,
        role,
      });
    } catch (error) {
      const errorMessage =
        error.response?.data?.error?.message || error.message;
      if (errorMessage === "No matching user or admin found") {
        return sendNotFoundError(res, "User or admin");
      }
      if (errorMessage.includes("required")) {
        return sendValidationError(res, errorMessage);
      }
      return sendError(res, 400, errorMessage);
    }
  },
};

// ==================== ROUTES ====================
router.post("/signup", AuthController.signup);

router.post("/login", AuthController.login);

export default router;
