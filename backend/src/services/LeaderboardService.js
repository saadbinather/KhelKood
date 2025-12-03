/**
 * LeaderboardService - Business Logic Layer for Leaderboard
 * Extends BaseService for common validation methods
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only leaderboard business logic
 * 2. Dependency Inversion: Depends on repository abstraction
 * 3. Open/Closed: Open for extension, closed for modification
 */

import { BaseService } from "../core/BaseService.js";

export class LeaderboardService extends BaseService {
  constructor(repository) {
    super(repository);
  }

  /**
   * Get leaderboard for the logged-in team's sport
   * @param {string} userId - User ID of the logged-in team
   * @returns {Promise<Object>} Leaderboard data with sport and teams
   */
  async getLeaderboard(userId) {
    try {
      // Get logged-in team's sport
      const loggedInTeam = await this.repository.findTeamByUserId(userId);
      if (!loggedInTeam) {
        throw new Error("Team not found");
      }

      const teamSport = loggedInTeam.sports || "";
      if (!teamSport) {
        throw new Error("Team sport not found");
      }

      // Get all teams with the same sport
      const teams = await this.repository.findAllTeamsBySport(teamSport);

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
    } catch (error) {
      this.handleError(error, "LeaderboardService.getLeaderboard");
      throw error;
    }
  }
}

