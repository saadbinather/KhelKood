/**
 * LeaderboardController - Request Handling Layer for Leaderboard
 * Extends BaseController for common HTTP handling methods
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only HTTP request/response logic
 * 2. Dependency Inversion: Depends on service abstraction
 * 3. Open/Closed: Open for extension, closed for modification
 */

import { BaseController } from "../core/BaseController.js";

export class LeaderboardController extends BaseController {
  constructor(service) {
    super(service);
  }

  /**
   * Get leaderboard for the logged-in team
   * @param {Object} req - Express request object
   * @param {Object} res - Express response object
   */
  async getLeaderboard(req, res) {
    try {
      const userId = this.getUserId(req);
      if (!userId) {
        return this.handleError(res, new Error("User ID not found"), "LeaderboardController.getLeaderboard");
      }

      const result = await this.service.getLeaderboard(userId);
      return this.handleSuccess(
        res,
        200,
        "Leaderboard fetched successfully ✅",
        result
      );
    } catch (error) {
      return this.handleError(res, error, "LeaderboardController.getLeaderboard");
    }
  }
}

