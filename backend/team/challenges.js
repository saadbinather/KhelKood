import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
  sendUnauthorizedError,
} from "../utils/response.js";
import { validateRequired, validateDateRange } from "../utils/validators.js";
import { ChallengeRepository } from "../src/repositories/ChallengeRepository.js";
import { ChallengeService } from "../src/services/ChallengeService.js";
import { ChallengeController } from "../src/controllers/ChallengeController.js";

const router = express.Router();

// Routes
router.post("/create", verifyToken(["team"]), (req, res) =>
  ChallengeController.create(req, res)
);
router.get("/challenge-details/:challengeID",
  verifyToken(["team"]),
  (req, res) => ChallengeController.getChallengeDetails(req, res)
);

router.get("/open", verifyToken(["team"]), (req, res) =>
  ChallengeController.getOpenChallenges(req, res)
);
router.get("/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  (req, res) => ChallengeController.getCourtChallenges(req, res)
);

router.delete("/:challengeID", verifyToken(["team"]), (req, res) =>
  ChallengeController.deleteChallenge(req, res)
);

export default router;
