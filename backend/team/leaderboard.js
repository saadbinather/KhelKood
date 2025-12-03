/**
 * Leaderboard Module - Refactored with OOP and SOLID Principles
 *
 * SOLID Principles Implemented:
 * 1. Single Responsibility Principle (SRP):
 *    - Repository: Handles only data access
 *    - Service: Handles only business logic
 *    - Controller: Handles only HTTP requests/responses
 *
 * 2. Open/Closed Principle (OCP):
 *    - Base classes are open for extension but closed for modification
 *    - New leaderboard features can be added without modifying existing code
 *
 * 3. Liskov Substitution Principle (LSP):
 *    - All repositories can be substituted for the base repository
 *    - All services can be substituted for the base service
 *    - All controllers can be substituted for the base controller
 *
 * 4. Interface Segregation Principle (ISP):
 *    - Small, focused interfaces (controller, service, repository)
 *    - Clients don't depend on methods they don't use
 *
 * 5. Dependency Inversion Principle (DIP):
 *    - High-level modules (Controller) depend on abstractions (Service interface)
 *    - Low-level modules (Repository) depend on abstractions (Database interface)
 */

import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import { LeaderboardRepository } from "../src/repositories/LeaderboardRepository.js";
import { LeaderboardService } from "../src/services/LeaderboardService.js";
import { LeaderboardController } from "../src/controllers/LeaderboardController.js";

const router = express.Router();

// Dependency Injection: Create instances with their dependencies
const leaderboardRepository = new LeaderboardRepository(db);
const leaderboardService = new LeaderboardService(leaderboardRepository);
const leaderboardController = new LeaderboardController(leaderboardService);

// Routes
router.get("/", verifyToken(["team"]), (req, res) =>
  leaderboardController.getLeaderboard(req, res)
);

export default router;
