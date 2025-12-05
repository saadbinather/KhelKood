import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import { ChallengeRepository } from "../src/repositories/ChallengeRepository.js";
import { ChallengeService } from "../src/services/ChallengeService.js";
import { ChallengeController } from "../src/controllers/ChallengeController.js";

const router = express.Router();

// Initialize challenge components
const challengeRepository = new ChallengeRepository(db);
const challengeService = new ChallengeService(challengeRepository);
const challengeController = new ChallengeController(challengeService);

// Routes
router.post("/create", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user?.userId || req.user?.uid;
    if (!teamID) {
      return res.status(401).json({
        success: false,
        error: "Unauthorized: Team ID not found",
      });
    }

    // Get team info
    const team = await challengeRepository.findTeamByUserId(teamID);
    if (!team) {
      return res.status(404).json({
        success: false,
        error: "Team not found",
      });
    }

    // Map frontend fields to backend fields
    const { courtFirebaseUID, stime, etime, courtNum } = req.body;

    const challengeData = {
      courtID: courtFirebaseUID,
      sport: team.sports || "football", // Use team's sport
      startTime: stime,
      endTime: etime,
      courtNum: courtNum,
      teamName: team.teamName,
    };

    const result = await challengeService.createChallenge(
      team.id,
      challengeData
    );

    return res.status(201).json({
      success: true,
      message: "Challenge created successfully ✅",
      data: {
        challengeID: result.challenge.id,
        challenge: result.challenge,
        pricing: result.pricing,
      },
    });
  } catch (error) {
    console.error("Error creating challenge:", error);
    return res.status(500).json({
      success: false,
      error: error.message || "Failed to create challenge",
    });
  }
});

router.get(
  "/challenge-details/:challengeID",
  verifyToken(["team"]),
  (req, res) => challengeController.getChallengeDetails(req, res)
);

router.get("/open", verifyToken(["team"]), async (req, res) => {
  try {
    const teamID = req.user?.userId || req.user?.uid;
    if (!teamID) {
      return res.status(401).json({
        success: false,
        error: "Unauthorized: Team ID not found",
      });
    }

    // Get team's own challenges (outgoing)
    const outgoingChallenges = await challengeService.getTeamChallenges(teamID);

    // Get all open challenges from other teams (incoming)
    // Get team info first
    const team = await challengeRepository.findTeamByUserId(teamID);
    if (!team) {
      return res.status(404).json({
        success: false,
        error: "Team not found",
      });
    }

    // Get all challenges and filter
    const allChallenges = await challengeRepository.findAll();
    const allMatches = await challengeRepository.findAllMatches();

    // Filter for incoming challenges (not from this team, not matched, same sport)
    const incomingChallenges = await Promise.all(
      allChallenges
        .filter((challenge) => {
          const isNotMyChallenge = challenge.hostTeamID !== team.id;
          const isNotMatched = !allMatches.find(
            (match) => match.Challenge_ID === challenge.id
          );
          const isSameSport =
            challenge.sport?.toLowerCase() === team.sports?.toLowerCase();
          return isNotMyChallenge && isNotMatched && isSameSport;
        })
        .map(async (challenge) => {
          const court = await challengeRepository.findCourtById(
            challenge.courtFirebaseUID
          );
          const hostTeam = await challengeRepository.findTeamById(
            challenge.hostTeamID
          );

          return {
            challengeID: challenge.id,
            id: challenge.id,
            Court_Name: court?.name || "Unknown Court",
            Court_Address: court?.address || "",
            Court_Rating: court?.rating || 0,
            Host_Team_Name:
              hostTeam?.teamName || challenge.teamName || "Unknown Team",
            Host_Team_Points: hostTeam?.points || 0,
            Sport: challenge.sport || "",
            Start_Time: challenge.stime,
            End_Time: challenge.etime,
            Date: challenge.stime
              ? new Date(challenge.stime).toLocaleDateString()
              : "",
            Price: challenge.Price || 0,
            Total_Price: challenge.Price || 0,
          };
        })
    );

    // Format outgoing challenges
    const formattedOutgoing = await Promise.all(
      outgoingChallenges.map(async (challenge) => {
        const court = await challengeRepository.findCourtById(
          challenge.courtFirebaseUID
        );
        return {
          challengeID: challenge.id,
          id: challenge.id,
          Court_Name: court?.name || "Unknown Court",
          Court_Address: court?.address || "",
          Court_Rating: court?.rating || 0,
          Host_Team_Name: team.teamName,
          Host_Team_Points: team.points || 0,
          Sport: challenge.sport || "",
          Start_Time: challenge.stime,
          End_Time: challenge.etime,
          Date: challenge.stime
            ? new Date(challenge.stime).toLocaleDateString()
            : "",
          Price: challenge.Price || 0,
          Total_Price: challenge.Price || 0,
        };
      })
    );

    return res.status(200).json({
      success: true,
      message: "Open challenges retrieved successfully",
      data: {
        incoming: incomingChallenges,
        outgoing: formattedOutgoing,
      },
    });
  } catch (error) {
    console.error("Error fetching open challenges:", error);
    return res.status(500).json({
      success: false,
      error: error.message || "Failed to fetch open challenges",
    });
  }
});

router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  (req, res) => challengeController.getCourtChallenges(req, res)
);

router.delete("/:challengeID", verifyToken(["team"]), (req, res) =>
  challengeController.deleteChallenge(req, res)
);

export default router;
