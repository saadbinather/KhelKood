/**
 * BookingRepository - Data Access Layer for Bookings
 * Extends BaseRepository for common CRUD operations
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only booking data access
 * 2. Dependency Inversion: Depends on database abstraction
 */

import { BaseRepository } from "../core/BaseRepository.js";

export class BookingRepository extends BaseRepository {
  constructor(db) {
    super(db, "bookings");
  }

  /**
   * Find bookings by court ID
   * @param {string} courtID - Court ID
   * @param {number|null} courtNum - Optional court number
   * @returns {Promise<Array>}
   */
  async findByCourtId(courtID, courtNum = null) {
    try {
      let query = this.db.collection(this.collectionName).where("courtID", "==", courtID);

      if (courtNum !== null) {
        query = query.where("courtNum", "==", courtNum);
      }

      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      throw new Error(`Error finding bookings by court: ${error.message}`);
    }
  }

  /**
   * Find bookings by team ID
   * @param {string} teamID - Team ID
   * @returns {Promise<Array>}
   */
  async findByTeamId(teamID) {
    try {
      // Try with orderBy first
      try {
        const snapshot = await this.db
          .collection(this.collectionName)
          .where("teamID", "==", teamID)
          .orderBy("startTime", "desc")
          .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      } catch (orderError) {
        // Fallback: fetch without orderBy and sort in memory
        const snapshot = await this.db
          .collection(this.collectionName)
          .where("teamID", "==", teamID)
          .get();

        const bookings = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        
        // Sort by startTime descending in memory
        return bookings.sort((a, b) => {
          const aTime = a.startTime?.toDate ? a.startTime.toDate().getTime() : new Date(a.startTime).getTime();
          const bTime = b.startTime?.toDate ? b.startTime.toDate().getTime() : new Date(b.startTime).getTime();
          return bTime - aTime;
        });
      }
    } catch (error) {
      throw new Error(`Error finding bookings by team: ${error.message}`);
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
   * Find team by user ID
   * @param {string} userId - User ID
   * @returns {Promise<Object|null>}
   */
  async findTeamByUserId(userId) {
    try {
      const teamQuery = await this.db
        .collection("teams")
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
   * Find match by ID
   * @param {string} matchID - Match ID
   * @returns {Promise<Object|null>}
   */
  async findMatchById(matchID) {
    try {
      const matchDoc = await this.db.collection("matches").doc(matchID).get();
      return matchDoc.exists ? { id: matchDoc.id, ...matchDoc.data() } : null;
    } catch (error) {
      throw new Error(`Error finding match: ${error.message}`);
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

  /**
   * Find matches by team ID
   * @param {string} teamID - Team ID
   * @returns {Promise<Array>}
   */
  async findMatchesByTeamId(teamID) {
    try {
      const matchesSnapshot = await this.db.collection("matches").get();

      const matches = matchesSnapshot.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(match => 
          match.Host_Team_ID === teamID || match.Guest_Team_ID === teamID
        );

      // Sort by StartTime descending
      return matches.sort((a, b) => {
        const aTime = a.StartTime?.toDate ? a.StartTime.toDate().getTime() : new Date(a.StartTime).getTime();
        const bTime = b.StartTime?.toDate ? b.StartTime.toDate().getTime() : new Date(b.StartTime).getTime();
        return bTime - aTime;
      });
    } catch (error) {
      throw new Error(`Error finding matches by team: ${error.message}`);
    }
  }
}

