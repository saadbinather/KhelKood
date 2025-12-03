/**
 * Challenges Module - Refactored with OOP and SOLID Principles
 * 
 * SOLID Principles Implemented:
 * 1. Single Responsibility: Repository/Service/Controller separation
 * 2. Open/Closed: Extensible through base classes
 * 3. Liskov Substitution: All implementations can substitute their base classes
 * 4. Interface Segregation: Focused interfaces per layer
 * 5. Dependency Inversion: Depends on abstractions, not concretions
 */

import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import { ChallengeRepository } from "../src/repositories/ChallengeRepository.js";
import { ChallengeService } from "../src/services/ChallengeService.js";
import { ChallengeController } from "../src/controllers/ChallengeController.js";

const router = express.Router();

// Dependency Injection: Create instances with their dependencies
const challengeRepository = new ChallengeRepository(db);
const challengeService = new ChallengeService(challengeRepository);
const challengeController = new ChallengeController(challengeService);

// Routes
router.post(
  "/create-challenge",
  verifyToken(["team"]),
  (req, res) => challengeController.createChallenge(req, res)
);

router.get(
  "/challenge-details/:challengeID",
  verifyToken(["team", "courtowner"]),
  (req, res) => challengeController.getChallengeDetails(req, res)
);

router.get(
  "/by-sport/:sport",
  verifyToken(["team"]),
  (req, res) => challengeController.getChallengesBySport(req, res)
);

router.get(
  "/my-challenges",
  verifyToken(["team"]),
  (req, res) => challengeController.getMyOpenChallenges(req, res)
);

router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner"]),
  (req, res) => challengeController.getCourtChallenges(req, res)
);

router.delete(
  "/delete-challenge/:challengeID",
  verifyToken(["team"]),
  (req, res) => challengeController.deleteChallenge(req, res)
);

export default router;

