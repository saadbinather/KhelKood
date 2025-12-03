/**
 * ChallengeController - Request Handling Layer for Challenges
 * Extends BaseController for common request/response handling
 */

import { BaseController } from "../core/BaseController.js";

export class ChallengeController extends BaseController {
  constructor(challengeService) {
    super(challengeService);
    this.challengeService = challengeService;
  }

  /**
   * Create a challenge
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async createChallenge(req, res) {
    try {
      const teamID = this.getUserId(req);
      const result = await this.challengeService.createChallenge(teamID, req.body);

      return this.handleSuccess(res, 201, "Challenge created successfully ✅", {
        challengeID: result.challenge.id,
        challenge: result.challenge,
        pricing: result.pricing,
      });
    } catch (error) {
      return this.handleError(res, error, 'Create Challenge');
    }
  }

  /**
   * Get challenge details
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getChallengeDetails(req, res) {
    try {
      const { challengeID } = req.params;
      const challenge = await this.challengeService.getChallengeById(challengeID);

      return this.handleSuccess(res, 200, "Challenge retrieved successfully", {
        challenge,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get Challenge Details');
    }
  }

  /**
   * Get challenges by sport
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getChallengesBySport(req, res) {
    try {
      const { sport } = req.params;
      const challenges = await this.challengeService.getChallengesBySport(sport);

      return this.handleSuccess(res, 200, "Challenges retrieved successfully", {
        challenges,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get Challenges By Sport');
    }
  }

  /**
   * Get team's own challenges
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getMyOpenChallenges(req, res) {
    try {
      const teamID = this.getUserId(req);
      const challenges = await this.challengeService.getTeamChallenges(teamID);

      return this.handleSuccess(res, 200, "Your challenges retrieved successfully", {
        challenges,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get My Challenges');
    }
  }

  /**
   * Get court challenges
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getCourtChallenges(req, res) {
    try {
      const { courtID } = req.params;
      const courtNum = req.query.courtNum ? parseInt(req.query.courtNum) : null;
      
      const challenges = await this.challengeService.getCourtChallenges(courtID, courtNum);

      return this.handleSuccess(res, 200, "Court challenges retrieved successfully", {
        challenges,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get Court Challenges');
    }
  }

  /**
   * Delete a challenge
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async deleteChallenge(req, res) {
    try {
      const teamID = this.getUserId(req);
      const { challengeID } = req.params;

      await this.challengeService.deleteChallenge(challengeID, teamID);

      return this.handleSuccess(res, 200, "Challenge deleted successfully", {});
    } catch (error) {
      return this.handleError(res, error, 'Delete Challenge');
    }
  }
}

