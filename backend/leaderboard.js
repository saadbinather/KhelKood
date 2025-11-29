import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError } from "./utils/response.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================

const LeaderboardRepository = {
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

  async findAllTeamsBySport(sport) {
    // Get all teams and filter by sport (case-insensitive)
    const teamsSnapshot = await db.collection("teams").get();
    
    const teams = teamsSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((team) => {
        const teamSport = (team.sports || "").toLowerCase();
        const targetSport = (sport || "").toLowerCase();
        return teamSport === targetSport;
      });

    return teams;
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================

const LeaderboardService = {
  async getLeaderboard(userId) {
    // Get logged-in team's sport
    const loggedInTeam = await LeaderboardRepository.findTeamByUserId(userId);
    if (!loggedInTeam) {
      throw new Error("Team not found");
    }

    const teamSport = loggedInTeam.sports || "";
    if (!teamSport) {
      throw new Error("Team sport not found");
    }

    // Get all teams with the same sport
    const teams = await LeaderboardRepository.findAllTeamsBySport(teamSport);

    // Sort by points descending
    teams.sort((a, b) => {
      const pointsA = a.points || 0;
      const pointsB = b.points || 0;
      return pointsB - pointsA;
    });

    // Format response
    const leaderboard = teams.map((team) => ({
      id: team.id,
      teamName: team.teamName || "Unknown Team",
      sports: team.sports || "",
      points: team.points || 0,
      players: team.players || [],
      playerCount: (team.players || []).length,
    }));

    return {
      sport: teamSport,
      teams: leaderboard,
    };
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================

const LeaderboardController = {
  async getLeaderboard(req, res) {
    try {
      const userId = req.user.uid;
      const result = await LeaderboardService.getLeaderboard(userId);
      return sendSuccess(
        res,
        200,
        "Leaderboard fetched successfully ✅",
        result
      );
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================

router.get(
  "/",
  verifyToken(["team"]),
  LeaderboardController.getLeaderboard
);

export default router;

