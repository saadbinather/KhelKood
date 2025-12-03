/**
 * LeaderboardRepository - Data Access Layer for Leaderboard
 * Extends BaseRepository for common CRUD operations
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only leaderboard data access
 * 2. Dependency Inversion: Depends on database abstraction
 */

import { BaseRepository } from "../core/BaseRepository.js";

export class LeaderboardRepository extends BaseRepository {
  constructor(db) {
    super(db, "teams");
  }

  /**
   * Find team by user ID
   * @param {string} userId - User ID
   * @returns {Promise<Object|null>}
   */
  async findTeamByUserId(userId) {
    try {
      const teamQuery = await this.db
        .collection(this.collectionName)
        .where("userId", "==", userId)
        .limit(1)
        .get();

      if (teamQuery.empty) return null;
      const teamDoc = teamQuery.docs[0];
      return { id: teamDoc.id, ...teamDoc.data() };
    } catch (error) {
      throw new Error(`Error finding team by user ID: ${error.message}`);
    }
  }

  /**
   * Find all teams by sport
   * @param {string} sport - Sport type
   * @returns {Promise<Array>}
   */
  async findAllTeamsBySport(sport) {
    try {
      // Get all teams and filter by sport (case-insensitive)
      const teamsSnapshot = await this.db.collection(this.collectionName).get();
      
      const teams = teamsSnapshot.docs
        .map((doc) => ({ id: doc.id, ...doc.data() }))
        .filter((team) => {
          const teamSport = (team.sports || "").toLowerCase();
          const targetSport = (sport || "").toLowerCase();
          return teamSport === targetSport;
        });

      return teams;
    } catch (error) {
      throw new Error(`Error finding teams by sport: ${error.message}`);
    }
  }
}

