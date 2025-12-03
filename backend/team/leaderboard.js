
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