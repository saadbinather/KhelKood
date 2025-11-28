import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError } from "./utils/response.js";
import { validateRequired, validateDateRange } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for challenges

const ChallengeRepository = {
  async findTeamByUserId(userId) {
    const teamQuery = await db
      .collection("teams")
      .where("userId", "==", userId)
      .limit(1)
      .get();
    
    if (teamQuery.empty) return null;
    const teamDoc = teamQuery.docs[0];
    return { id: teamDoc.id, ...teamDoc.data() };
  },

  async create(challengeData) {
    const docRef = await db.collection("challenges").add(challengeData);
    return { id: docRef.id, ...challengeData };
  },

  async findById(challengeID) {
    const challengeDoc = await db.collection("challenges").doc(challengeID).get();
    return challengeDoc.exists ? { id: challengeDoc.id, ...challengeDoc.data() } : null;
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle challenge business rules

const ChallengeService = {
  async createChallenge(hostTeamUID, { courtFirebaseUID, stime, etime }) {
    // Validation
    const validation = validateRequired(
      { courtFirebaseUID, stime, etime },
      ["courtFirebaseUID", "stime", "etime"]
    );
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const dateValidation = validateDateRange(stime, etime);
    if (!dateValidation.isValid) {
      throw new Error(dateValidation.error);
    }

    // Get team info
    const team = await ChallengeRepository.findTeamByUserId(hostTeamUID);
    if (!team) {
      throw new Error("Team not found");
    }

    // Build challenge data
    const challengeData = {
      hostTeamID: hostTeamUID,
      teamName: team.teamName,
      sport: team.sports,
      courtFirebaseUID,
      stime,
      etime,
      status: "pending",
      createdAt: new Date(),
    };

    return await ChallengeRepository.create(challengeData);
  },

  async getChallengeById(challengeID) {
    const challenge = await ChallengeRepository.findById(challengeID);
    if (!challenge) {
      throw new Error("Challenge not found");
    }
    return challenge;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const ChallengeController = {
  async create(req, res) {
    try {
      const hostTeamUID = req.user.uid;
      const challenge = await ChallengeService.createChallenge(hostTeamUID, req.body);
      
      return sendSuccess(res, 201, "Challenge created successfully ✅", {
        challengeID: challenge.id,
        challenge,
      });
    } catch (error) {
      if (error.message === "Team not found" || error.message === "Challenge not found") {
        return sendNotFoundError(res, error.message.split(" ")[0]);
      }
      if (error.message.includes("required") || error.message.includes("Invalid date")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getChallengeDetails(req, res) {
    try {
      const { challengeID } = req.params;
      const challenge = await ChallengeService.getChallengeById(challengeID);
      
      return sendSuccess(res, 200, "Challenge fetched successfully ✅", { challenge });
    } catch (error) {
      if (error.message === "Challenge not found") {
        return sendNotFoundError(res, "Challenge");
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post("/create", verifyToken(["team"]), ChallengeController.create);
router.get("/challenge-details/:challengeID", verifyToken(["team"]), ChallengeController.getChallengeDetails);

export default router;
