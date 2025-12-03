/**
 * ChallengeService - Business Logic Layer for Challenges
 * Extends BaseService for common validation and error handling
 */

import { BaseService } from "../core/BaseService.js";
import { PricingStrategyFactory } from "../strategies/PricingStrategy.js";

export class ChallengeService extends BaseService {
  constructor(challengeRepository) {
    super(challengeRepository);
    this.challengeRepository = challengeRepository;
  }

  /**
   * Create a challenge
   * @param {string} teamID - Team ID
   * @param {Object} challengeData - Challenge data
   * @returns {Promise<Object>} Created challenge with pricing
   */
  async createChallenge(teamID, challengeData) {
    const { courtID, sport, startTime, endTime, courtNum, teamName } = challengeData;

    // Validate required fields
    this.validateRequired(
      { courtID, sport, startTime, endTime, courtNum, teamName },
      ["courtID", "sport", "startTime", "endTime", "courtNum", "teamName"]
    );

    // Validate date range
    this.validateDateRange(startTime, endTime);

    // Check if court exists
    const court = await this.challengeRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    // Calculate pricing
    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);
    const pricingStrategy = PricingStrategyFactory.getStrategy(sport);
    const pricing = pricingStrategy.calculate(court, startTimeDate, endTimeDate);

    // Create challenge
    const challengeEntry = {
      courtFirebaseUID: courtID,
      hostTeamID: teamID,
      teamName,
      sport: sport.toLowerCase(),
      courtNum: parseInt(courtNum),
      stime: startTimeDate,
      etime: endTimeDate,
      Price: pricing.totalAmount,
      createdAt: new Date(),
    };

    const challenge = await this.challengeRepository.create(challengeEntry);

    return { challenge, pricing };
  }

  /**
   * Get challenge by ID with enriched data
   * @param {string} challengeID - Challenge ID
   * @returns {Promise<Object>} Challenge with court and match info
   */
  async getChallengeById(challengeID) {
    const challenge = await this.challengeRepository.findById(challengeID);
    if (!challenge) {
      throw new Error("Challenge not found");
    }

    // Get court details
    const court = await this.challengeRepository.findCourtById(challenge.courtFirebaseUID);

    // Check if challenge is open (not in a match)
    const allMatches = await this.challengeRepository.findAllMatches();
    const matchedChallenge = allMatches.find(match => match.Challenge_ID === challengeID);

    return {
      ...challenge,
      courtName: court ? court.name : "Unknown Court",
      isOpen: !matchedChallenge,
    };
  }

  /**
   * Get challenges by sport with team and court info
   * @param {string} sport - Sport type
   * @returns {Promise<Array>} Enriched challenges
   */
  async getChallengesBySport(sport) {
    const challenges = await this.challengeRepository.findAllBySport(sport);
    const allMatches = await this.challengeRepository.findAllMatches();

    // Enrich challenges with additional info
    const enrichedChallenges = await Promise.all(
      challenges.map(async (challenge) => {
        const court = await this.challengeRepository.findCourtById(challenge.courtFirebaseUID);
        const team = await this.challengeRepository.findTeamById(challenge.hostTeamID);
        const matchedChallenge = allMatches.find(match => match.Challenge_ID === challenge.id);

        return {
          ...challenge,
          courtName: court ? court.name : "Unknown Court",
          hostTeamName: team ? team.teamName : challenge.teamName || "Unknown Team",
          isOpen: !matchedChallenge,
        };
      })
    );

    return enrichedChallenges;
  }

  /**
   * Get team's own challenges
   * @param {string} teamID - Team ID
   * @returns {Promise<Array>} Team's challenges
   */
  async getTeamChallenges(teamID) {
    const challenges = await this.challengeRepository.findAllByHostTeamID(teamID);
    const allMatches = await this.challengeRepository.findAllMatches();

    // Enrich with court info and match status
    const enrichedChallenges = await Promise.all(
      challenges.map(async (challenge) => {
        const court = await this.challengeRepository.findCourtById(challenge.courtFirebaseUID);
        const matchedChallenge = allMatches.find(match => match.Challenge_ID === challenge.id);

        return {
          ...challenge,
          courtName: court ? court.name : "Unknown Court",
          isOpen: !matchedChallenge,
        };
      })
    );

    return enrichedChallenges;
  }

  /**
   * Get court challenges
   * @param {string} courtID - Court ID
   * @param {number|null} courtNum - Optional court number
   * @returns {Promise<Array>} Court challenges
   */
  async getCourtChallenges(courtID, courtNum = null) {
    const challenges = await this.challengeRepository.findByCourtId(courtID, courtNum);
    const allMatches = await this.challengeRepository.findAllMatches();

    // Enrich with team info and match status
    const enrichedChallenges = await Promise.all(
      challenges.map(async (challenge) => {
        const team = await this.challengeRepository.findTeamById(challenge.hostTeamID);
        const matchedChallenge = allMatches.find(match => match.Challenge_ID === challenge.id);

        return {
          ...challenge,
          teamName: team ? team.teamName : challenge.teamName || "Unknown Team",
          isOpen: !matchedChallenge,
        };
      })
    );

    return enrichedChallenges;
  }

  /**
   * Delete a challenge
   * @param {string} challengeID - Challenge ID
   * @param {string} teamID - Team ID (for authorization)
   * @returns {Promise<boolean>}
   */
  async deleteChallenge(challengeID, teamID) {
    const challenge = await this.challengeRepository.findById(challengeID);
    if (!challenge) {
      throw new Error("Challenge not found");
    }

    // Verify ownership
    if (challenge.hostTeamID !== teamID) {
      throw new Error("Unauthorized: You do not own this challenge");
    }

    // Check if challenge is already in a match
    const allMatches = await this.challengeRepository.findAllMatches();
    const matchedChallenge = allMatches.find(match => match.Challenge_ID === challengeID);

    if (matchedChallenge) {
      throw new Error("Cannot delete challenge that is already part of a match");
    }

    return await this.challengeRepository.delete(challengeID);
  }
}

