import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError } from "./utils/response.js";
import { validateRequired, validateTeamPhone, validateEmail } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for teams

const TeamRepository = {
  async findById(teamID) {
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },

  async findByEmail(email, excludeTeamID = null) {
    const teamsSnapshot = await db.collection("teams")
      .where("email", "==", email)
      .get();
    
    const teams = teamsSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter(team => team.id !== excludeTeamID);
    
    return teams.length > 0 ? teams[0] : null;
  },

  async findByPhone(phone, excludeTeamID = null) {
    // Normalize phone: remove dashes for comparison
    const normalizedPhone = phone.replace(/-/g, '');
    
    const teamsSnapshot = await db.collection("teams").get();
    
    const teams = teamsSnapshot.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter(team => {
        if (team.id === excludeTeamID) return false;
        const teamPhone = (team.phone || '').replace(/-/g, '');
        return teamPhone === normalizedPhone;
      });
    
    return teams.length > 0 ? teams[0] : null;
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

  async findAllBySport(sport) {
    const teamsSnapshot = await db.collection("teams")
      .where("sports", "==", sport)
      .get();
    
    return teamsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findAllBySports(sports) {
    // Firestore 'in' query supports up to 10 values
    if (sports.length === 0) return [];
    if (sports.length === 1) {
      return await this.findAllBySport(sports[0]);
    }
    
    const teamsSnapshot = await db.collection("teams")
      .where("sports", "in", sports)
      .get();
    
    return teamsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findMatchesByTeamId(teamID) {
    // Get matches where team is host
    const hostMatchesSnapshot = await db.collection("matches")
      .where("Host_Team_ID", "==", teamID)
      .get();
    
    // Get matches where team is guest
    const guestMatchesSnapshot = await db.collection("matches")
      .where("Guest_Team_ID", "==", teamID)
      .get();
    
    // Combine and deduplicate
    const allMatches = [];
    const matchIds = new Set();
    
    hostMatchesSnapshot.docs.forEach(doc => {
      if (!matchIds.has(doc.id)) {
        matchIds.add(doc.id);
        allMatches.push({ id: doc.id, ...doc.data() });
      }
    });
    
    guestMatchesSnapshot.docs.forEach(doc => {
      if (!matchIds.has(doc.id)) {
        matchIds.add(doc.id);
        allMatches.push({ id: doc.id, ...doc.data() });
      }
    });
    
    return allMatches;
  },

  async findTeamById(teamID) {
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
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

    // Validate phone number if provided
    if (updates.phone !== undefined) {
      const phoneValidation = validateTeamPhone(updates.phone);
      if (!phoneValidation.isValid) {
        throw new Error(phoneValidation.error);
      }
      
      // Check for duplicate phone number
      const existingTeamWithPhone = await TeamRepository.findByPhone(updates.phone, teamID);
      if (existingTeamWithPhone) {
        throw new Error("Phone number is already in use by another team");
      }
      
      // Use cleaned phone (without dash) for storage, or keep original format
      // Store with optional dash format as user entered
      updates.phone = updates.phone;
    }

    // Validate email if provided
    if (updates.email !== undefined) {
      const emailValidation = validateEmail(updates.email);
      if (!emailValidation.isValid) {
        throw new Error(emailValidation.error);
      }
      
      // Check for duplicate email
      const existingTeamWithEmail = await TeamRepository.findByEmail(updates.email, teamID);
      if (existingTeamWithEmail) {
        throw new Error("Email is already in use by another team");
      }
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

  async getAllTeamsBySport(sport, excludeTeamID) {
    const validation = validateRequired({ sport }, ["sport"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Normalize sport: map "football" to "futsal"
    let normalizedSport = sport.toLowerCase();
    if (normalizedSport === "football") {
      normalizedSport = "futsal";
    }

    const validSports = ["futsal", "cricket", "padel"];
    if (!validSports.includes(normalizedSport)) {
      throw new Error("Invalid sport type. Must be futsal, cricket, or padel");
    }

    let teams;

    // If original sport was "football", query for both "futsal" and "football" to handle data inconsistencies
    if (sport.toLowerCase() === "football") {
      teams = await TeamRepository.findAllBySports(["futsal", "football"]);
      // Deduplicate teams by ID
      teams = teams.reduce((acc, team) => {
        if (!acc.find(t => t.id === team.id)) {
          acc.push(team);
        }
        return acc;
      }, []);
    } else {
      // For other sports, just query normally
      teams = await TeamRepository.findAllBySport(normalizedSport);
    }

    // Exclude the logged-in team from the results
    if (excludeTeamID) {
      teams = teams.filter(team => team.id !== excludeTeamID);
    }

    return teams;
  },

  async getTeamDetails(teamID) {
    const team = await TeamRepository.findById(teamID);
    if (!team) {
      throw new Error("Team not found");
    }

    // Get match history for the team (both as host and guest)
    const matches = await TeamRepository.findMatchesByTeamId(teamID);

    // Enrich matches with opponent team information for competitive matches
    const enrichedMatches = await Promise.all(
      matches.map(async (match) => {
        let opponentTeam = null;
        
        // For competitive matches, get opponent team name
        if (match.matchType === "competitive") {
          const opponentTeamID = match.Host_Team_ID === teamID 
            ? match.Guest_Team_ID 
            : match.Host_Team_ID;
          
          if (opponentTeamID) {
            opponentTeam = await TeamRepository.findTeamById(opponentTeamID);
          }
        }

        return {
          ...match,
          opponentTeamName: opponentTeam?.teamName || null,
          StartTime: match.StartTime?._seconds 
            ? new Date(match.StartTime._seconds * 1000).toISOString()
            : match.StartTime,
          EndTime: match.EndTime?._seconds 
            ? new Date(match.EndTime._seconds * 1000).toISOString()
            : match.EndTime,
          createdAt: match.createdAt?._seconds 
            ? new Date(match.createdAt._seconds * 1000).toISOString()
            : match.createdAt,
        };
      })
    );

    // Filter: Only show matches that are either:
    // 1. Friendly matches (no Challenge_ID)
    // 2. Competitive matches (have Challenge_ID, meaning challenge was accepted)
    const filteredMatches = enrichedMatches.filter(match => {
      // If it's a competitive match, it must have a Challenge_ID (meaning it was accepted)
      if (match.matchType === "competitive") {
        return match.Challenge_ID != null;
      }
      // Friendly matches are always shown
      return true;
    });

    return {
      team,
      matchHistory: filteredMatches.sort((a, b) => 
        new Date(b.StartTime || b.createdAt) - new Date(a.StartTime || a.createdAt)
      ),
    };
  },

  async getMyMatchHistory(teamID) {
    const team = await TeamRepository.findById(teamID);
    if (!team) {
      throw new Error("Team not found");
    }

    // Get match history for the logged-in team (both as host and guest)
    const matches = await TeamRepository.findMatchesByTeamId(teamID);

    // Enrich matches with opponent team information for competitive matches
    const enrichedMatches = await Promise.all(
      matches.map(async (match) => {
        let opponentTeam = null;
        
        // For competitive matches, get opponent team name
        if (match.matchType === "competitive") {
          const opponentTeamID = match.Host_Team_ID === teamID 
            ? match.Guest_Team_ID 
            : match.Host_Team_ID;
          
          if (opponentTeamID) {
            opponentTeam = await TeamRepository.findTeamById(opponentTeamID);
          }
        }

        return {
          ...match,
          opponentTeamName: opponentTeam?.teamName || null,
          StartTime: match.StartTime?._seconds 
            ? new Date(match.StartTime._seconds * 1000).toISOString()
            : match.StartTime,
          EndTime: match.EndTime?._seconds 
            ? new Date(match.EndTime._seconds * 1000).toISOString()
            : match.EndTime,
          createdAt: match.createdAt?._seconds 
            ? new Date(match.createdAt._seconds * 1000).toISOString()
            : match.createdAt,
        };
      })
    );

    // Filter: Only show matches that are either:
    // 1. Friendly matches (no Challenge_ID)
    // 2. Competitive matches (have Challenge_ID, meaning challenge was accepted)
    const filteredMatches = enrichedMatches.filter(match => {
      // If it's a competitive match, it must have a Challenge_ID (meaning it was accepted)
      if (match.matchType === "competitive") {
        return match.Challenge_ID != null;
      }
      // Friendly matches are always shown
      return true;
    });

    return {
      team,
      matchHistory: filteredMatches.sort((a, b) => 
        new Date(b.StartTime || b.createdAt) - new Date(a.StartTime || a.createdAt)
      ),
    };
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
      // Return validation errors with 400 status
      if (error.message.includes("Invalid") || 
          error.message.includes("required") ||
          error.message.includes("already in use")) {
        return sendValidationError(res, error.message);
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

  async getAllTeamsBySport(req, res) {
    try {
      const { sport } = req.query;
      const currentTeamID = req.user.uid; // Get logged-in team ID
      const teams = await TeamService.getAllTeamsBySport(sport, currentTeamID);
      return sendSuccess(res, 200, "Teams fetched successfully ✅", { teams });
    } catch (error) {
      if (error.message.includes("required") || error.message.includes("Invalid sport")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getTeamDetails(req, res) {
    try {
      const { teamID } = req.params;
      const data = await TeamService.getTeamDetails(teamID);
      return sendSuccess(res, 200, "Team details fetched successfully ✅", data);
    } catch (error) {
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getMyMatchHistory(req, res) {
    try {
      const teamID = req.user.uid; // Get logged-in team ID
      const data = await TeamService.getMyMatchHistory(teamID);
      return sendSuccess(res, 200, "Match history fetched successfully ✅", data);
    } catch (error) {
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
router.get("/all-teams", verifyToken(["team"]), TeamController.getAllTeamsBySport);
router.get("/team-details/:teamID", verifyToken(["team"]), TeamController.getTeamDetails);
router.get("/match-history", verifyToken(["team"]), TeamController.getMyMatchHistory);

export default router;
