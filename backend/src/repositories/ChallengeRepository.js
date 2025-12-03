/**
 * ChallengeRepository - Data Access Layer for Challenges
 * Extends BaseRepository for common CRUD operations
 */

import { BaseRepository } from "../core/BaseRepository.js";

export class ChallengeRepository extends BaseRepository {
  constructor(db) {
    super(db, "challenges");
  }

  /**
   * Find challenges by sport type
   * @param {string} sport - Sport type
   * @returns {Promise<Array>}
   */
  async findAllBySport(sport) {
    try {
      const allChallenges = await this.findAll();
      const normalizedSport = sport.toLowerCase();
      
      return allChallenges.filter(challenge => {
        const challengeSport = (challenge.sport || "").toLowerCase();
        return challengeSport === normalizedSport;
      });
    } catch (error) {
      throw new Error(`Error finding challenges by sport: ${error.message}`);
    }
  }

  /**
   * Find challenges by host team ID
   * @param {string} hostTeamID - Host team ID
   * @returns {Promise<Array>}
   */
  async findAllByHostTeamID(hostTeamID) {
    return this.findByField("hostTeamID", hostTeamID);
  }

  /**
   * Find challenges by court ID
   * @param {string} courtID - Court ID
   * @param {number|null} courtNum - Optional court number
   * @returns {Promise<Array>}
   */
  async findByCourtId(courtID, courtNum = null) {
    try {
      const allChallenges = await this.findByField("courtFirebaseUID", courtID);
      
      if (courtNum !== null) {
        return allChallenges.filter(challenge => 
          parseInt(challenge.courtNum) === parseInt(courtNum)
        );
      }
      
      return allChallenges;
    } catch (error) {
      throw new Error(`Error finding challenges by court: ${error.message}`);
    }
  }

  /**
   * Find team by user ID
   * @param {string} userId - User ID
   * @returns {Promise<Object|null>}
   */
  async findTeamByUserId(userId) {
    try {
      const teams = await this.db
        .collection("teams")
        .where("userId", "==", userId)
        .limit(1)
        .get();

      if (teams.empty) return null;
      const teamDoc = teams.docs[0];
      return { id: teamDoc.id, ...teamDoc.data() };
    } catch (error) {
      throw new Error(`Error finding team by user ID: ${error.message}`);
    }
  }

  /**
   * Find court by ID
   * @param {string} courtID - Court ID
   * @returns {Promise<Object|null>}
   */
  async findCourtById(courtID) {
    try {
      const courtDoc = await this.db.collection("courts").doc(courtID).get();
      return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
    } catch (error) {
      throw new Error(`Error finding court: ${error.message}`);
    }
  }

  /**
   * Find all matches
   * @returns {Promise<Array>}
   */
  async findAllMatches() {
    try {
      const matchesSnapshot = await this.db.collection("matches").get();
      return matchesSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      throw new Error(`Error finding matches: ${error.message}`);
    }
  }

  /**
   * Find team by ID
   * @param {string} teamID - Team ID
   * @returns {Promise<Object|null>}
   */
  async findTeamById(teamID) {
    try {
      const teamDoc = await this.db.collection("teams").doc(teamID).get();
      return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
    } catch (error) {
      throw new Error(`Error finding team: ${error.message}`);
    }
  }
}

