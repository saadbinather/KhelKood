import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError } from "./utils/response.js";
import { validateRequired } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for teams

const TeamRepository = {
  async findById(teamID) {
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },

  async update(teamID, updates) {
    const teamRef = db.collection("teams").doc(teamID);
    await teamRef.update({
      ...updates,
      updatedAt: new Date(),
    });
    return await this.findById(teamID);
  },

  async addPlayer(teamID, playerName) {
    const team = await this.findById(teamID);
    if (!team) throw new Error("Team not found");

    const updatedPlayers = [...(team.players || []), playerName];
    await db.collection("teams").doc(teamID).update({
      players: updatedPlayers,
      updatedAt: new Date(),
    });

    // Add to players collection
    await db.collection("players").add({
      name: playerName,
      teamID,
      createdAt: new Date(),
    });

    return { ...team, players: updatedPlayers };
  },

  async removePlayer(teamID, playerName) {
    const team = await this.findById(teamID);
    if (!team) throw new Error("Team not found");

    const updatedPlayers = (team.players || []).filter(p => p !== playerName);
    await db.collection("teams").doc(teamID).update({
      players: updatedPlayers,
      updatedAt: new Date(),
    });

    // Remove from players collection
    const snapshot = await db.collection("players")
      .where("teamID", "==", teamID)
      .where("name", "==", playerName)
      .get();
    
    const batch = db.batch();
    snapshot.forEach(doc => batch.delete(doc.ref));
    await batch.commit();

    return { ...team, players: updatedPlayers };
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle team business rules

const TeamService = {
  async updateProfile(teamID, updates) {
    const team = await TeamRepository.findById(teamID);
    if (!team) {
      throw new Error("Team not found");
    }
    return await TeamRepository.update(teamID, updates);
  },

  async getProfile(teamID) {
    const team = await TeamRepository.findById(teamID);
    if (!team) {
      throw new Error("Team not found");
    }
    return team;
  },

  async addPlayer(teamID, playerName) {
    const validation = validateRequired({ playerName }, ["playerName"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }
    return await TeamRepository.addPlayer(teamID, playerName);
  },

  async removePlayer(teamID, playerName) {
    const validation = validateRequired({ playerName }, ["playerName"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }
    return await TeamRepository.removePlayer(teamID, playerName);
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const TeamController = {
  async updateProfile(req, res) {
    try {
      const teamID = req.user.uid;
      const updatedTeam = await TeamService.updateProfile(teamID, req.body);
      return sendSuccess(res, 200, "Team profile updated successfully ✅", {
        updatedFields: req.body,
        team: updatedTeam,
      });
    } catch (error) {
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getProfile(req, res) {
    try {
      const teamID = req.user.uid;
      const team = await TeamService.getProfile(teamID);
      return sendSuccess(res, 200, "Team profile fetched successfully ✅", { team });
    } catch (error) {
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },

  async addPlayer(req, res) {
    try {
      const teamID = req.user.uid;
      const { playerName } = req.body;
      await TeamService.addPlayer(teamID, playerName);
      return sendSuccess(res, 200, `Player "${playerName}" added successfully ✅`);
    } catch (error) {
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },

  async removePlayer(req, res) {
    try {
      const teamID = req.user.uid;
      const { playerName } = req.body;
      await TeamService.removePlayer(teamID, playerName);
      return sendSuccess(res, 200, `Player "${playerName}" removed successfully ✅`);
    } catch (error) {
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.put("/edit-profile", verifyToken(["team"]), TeamController.updateProfile);
router.get("/profile", verifyToken(["team"]), TeamController.getProfile);
router.post("/add-player", verifyToken(["team"]), TeamController.addPlayer);
router.post("/remove-player", verifyToken(["team"]), TeamController.removePlayer);

export default router;
