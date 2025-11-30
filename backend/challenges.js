import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
  sendUnauthorizedError,
} from "./utils/response.js";
import { validateRequired, validateDateRange } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for challenges

const ChallengeRepository = {
  async findTeamByUserId(userId) {
    const teamQuery = await db
      .collection("teams")
      .where("userId", "==", userId)
      .limit(1)
      .get();

    if (teamQuery.empty) return null;
    const teamDoc = teamQuery.docs[0];
    return { id: teamDoc.id, ...teamDoc.data() };
  },

  async create(challengeData) {
    const docRef = await db.collection("challenges").add(challengeData);
    return { id: docRef.id, ...challengeData };
  },

  async findById(challengeID) {
    const challengeDoc = await db
      .collection("challenges")
      .doc(challengeID)
      .get();
    return challengeDoc.exists
      ? { id: challengeDoc.id, ...challengeDoc.data() }
      : null;
  },

  async delete(challengeID) {
    await db.collection("challenges").doc(challengeID).delete();
    return true;
  },

  async findAllBySport(sport) {
    // Get all challenges and filter by sport (case-insensitive)
    const challengesSnapshot = await db.collection("challenges").get();

    const normalizedSport = sport.toLowerCase();
    return challengesSnapshot.docs
      .map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }))
      .filter((challenge) => {
        const challengeSport = (challenge.sport || "").toLowerCase();
        return challengeSport === normalizedSport;
      });
  },

  async findAllMatches() {
    const matchesSnapshot = await db.collection("matches").get();
    return matchesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findAllByHostTeamID(hostTeamID) {
    // Get all challenges where hostTeamID matches
    const challengesSnapshot = await db
      .collection("challenges")
      .where("hostTeamID", "==", hostTeamID)
      .get();

    return challengesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findCourtById(courtID) {
    const courtDoc = await db.collection("courts").doc(courtID).get();
    return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
  },

  async findTeamByUserId(userId) {
    const teamQuery = await db
      .collection("teams")
      .where("userId", "==", userId)
      .limit(1)
      .get();

    if (teamQuery.empty) return null;
    const teamDoc = teamQuery.docs[0];
    return { id: teamDoc.id, ...teamDoc.data() };
  },

  async findByCourtId(courtID) {
    const challengesSnapshot = await db
      .collection("challenges")
      .where("courtFirebaseUID", "==", courtID)
      .get();

    return challengesSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle challenge business rules

const ChallengeService = {
  async createChallenge(hostTeamUID, { courtFirebaseUID, stime, etime }) {
    // Validation
    const validation = validateRequired({ courtFirebaseUID, stime, etime }, [
      "courtFirebaseUID",
      "stime",
      "etime",
    ]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const dateValidation = validateDateRange(stime, etime);
    if (!dateValidation.isValid) {
      throw new Error(dateValidation.error);
    }

    // Get team info
    const team = await ChallengeRepository.findTeamByUserId(hostTeamUID);
    if (!team) {
      throw new Error("Team not found");
    }

    // Build challenge data
    const challengeData = {
      hostTeamID: hostTeamUID,
      teamName: team.teamName,
      sport: team.sports,
      courtFirebaseUID,
      stime,
      etime,
      status: "pending",
      createdAt: new Date(),
    };

    return await ChallengeRepository.create(challengeData);
  },

  async getChallengeById(challengeID) {
    const challenge = await ChallengeRepository.findById(challengeID);
    if (!challenge) {
      throw new Error("Challenge not found");
    }
    return challenge;
  },

  async deleteChallenge(challengeID, teamUID) {
    // Get challenge to verify ownership
    const challenge = await ChallengeRepository.findById(challengeID);
    if (!challenge) {
      throw new Error("Challenge not found");
    }

    // Verify that the team owns this challenge
    if (challenge.hostTeamID !== teamUID) {
      throw new Error("Unauthorized to delete this challenge");
    }

    // Delete the challenge
    await ChallengeRepository.delete(challengeID);
    return true;
  },

  async getOpenChallenges(teamUID) {
    // Get team info to get sport
    const team = await ChallengeRepository.findTeamByUserId(teamUID);
    if (!team) {
      throw new Error("Team not found");
    }

    const teamSport = team.sports;
    if (!teamSport) {
      return { incoming: [], outgoing: [] };
    }

    // Get all challenges for this sport
    const allChallenges = await ChallengeRepository.findAllBySport(teamSport);

    // Get all matches to find which challenges are already accepted
    const allMatches = await ChallengeRepository.findAllMatches();
    const acceptedChallengeIDs = new Set(
      allMatches.map((match) => match.Challenge_ID).filter((id) => id != null)
    );

    // Filter open challenges (not in matches)
    const openChallenges = allChallenges.filter(
      (challenge) => !acceptedChallengeIDs.has(challenge.id)
    );

    // Get all outgoing challenges (where hostTeamID === teamUID) - regardless of sport
    const allOutgoingChallenges = await ChallengeRepository.findAllByHostTeamID(
      teamUID
    );
    const outgoingChallengeIDs = new Set(
      allOutgoingChallenges.map((challenge) => challenge.id)
    );

    // Filter outgoing challenges that are open (not in matches)
    const openOutgoingChallenges = allOutgoingChallenges.filter(
      (challenge) => !acceptedChallengeIDs.has(challenge.id)
    );

    // Separate into incoming and outgoing
    const incoming = [];
    const outgoing = [];

    for (const challenge of openChallenges) {
      // Get court details
      let court = null;
      if (challenge.courtFirebaseUID) {
        court = await ChallengeRepository.findCourtById(
          challenge.courtFirebaseUID
        );
      }

      // Get host team details (including points)
      let hostTeam = null;
      let hostTeamPoints = 0;
      if (challenge.hostTeamID) {
        hostTeam = await ChallengeRepository.findTeamByUserId(
          challenge.hostTeamID
        );
        if (hostTeam) {
          hostTeamPoints = hostTeam.points || 0;
        }
      }

      // Calculate price
      let price = 0;
      let hourlyRate = 0;
      let durationHours = 0;

      if (court && challenge.stime && challenge.etime) {
        const startTime = new Date(challenge.stime);
        const endTime = new Date(challenge.etime);
        durationHours = (endTime - startTime) / (1000 * 60 * 60);

        const sport = (challenge.sport || teamSport || "").toLowerCase();
        switch (sport) {
          case "cricket":
            hourlyRate = court.cricketRate || 1800;
            break;
          case "futsal":
          case "football":
            hourlyRate = court.futsalRate || 2000;
            break;
          case "padel":
            hourlyRate = court.padelRate || 3500;
            break;
          default:
            hourlyRate = court.futsalRate || 2000;
        }

        price = Math.round(durationHours * hourlyRate);
      }

      const challengeData = {
        id: challenge.id,
        challengeID: challenge.id,
        Court_Name: court?.name || "Unknown Court",
        Court_Address: court?.address || "Unknown Address",
        Court_Rating: court?.rating || 0,
        Host_Team_Name: challenge.teamName || "Unknown Team",
        Host_Team_Points: hostTeamPoints,
        Sport: challenge.sport || teamSport,
        Status: challenge.status || "pending",
        Start_Time: challenge.stime,
        End_Time: challenge.etime,
        Date: challenge.stime
          ? new Date(challenge.stime).toISOString().split("T")[0]
          : null,
        courtFirebaseUID: challenge.courtFirebaseUID,
        hostTeamID: challenge.hostTeamID,
        Price: price,
        HourlyRate: hourlyRate,
        DurationHours: parseFloat(durationHours.toFixed(2)),
        court: court,
        hostTeam: hostTeam,
      };

      if (challenge.hostTeamID === teamUID) {
        // Challenge created by this team
        outgoing.push(challengeData);
      } else {
        // Challenge created by other teams (incoming)
        incoming.push(challengeData);
      }
    }

    // Also add any outgoing challenges that might not be in openChallenges (e.g., different sport)
    for (const challenge of openOutgoingChallenges) {
      // Skip if already added from openChallenges
      if (!openChallenges.some((c) => c.id === challenge.id)) {
        // Get court details
        let court = null;
        if (challenge.courtFirebaseUID) {
          court = await ChallengeRepository.findCourtById(
            challenge.courtFirebaseUID
          );
        }

        // Get host team details (including points)
        let hostTeam = null;
        let hostTeamPoints = 0;
        if (challenge.hostTeamID) {
          hostTeam = await ChallengeRepository.findTeamByUserId(
            challenge.hostTeamID
          );
          if (hostTeam) {
            hostTeamPoints = hostTeam.points || 0;
          }
        }

        // Calculate price
        let price = 0;
        let hourlyRate = 0;
        let durationHours = 0;

        if (court && challenge.stime && challenge.etime) {
          const startTime = new Date(challenge.stime);
          const endTime = new Date(challenge.etime);
          durationHours = (endTime - startTime) / (1000 * 60 * 60);

          const sport = (challenge.sport || teamSport || "").toLowerCase();
          switch (sport) {
            case "cricket":
              hourlyRate = court.cricketRate || 1800;
              break;
            case "futsal":
            case "football":
              hourlyRate = court.futsalRate || 2000;
              break;
            case "padel":
              hourlyRate = court.padelRate || 3500;
              break;
            default:
              hourlyRate = court.futsalRate || 2000;
          }

          price = Math.round(durationHours * hourlyRate);
        }

        const challengeData = {
          id: challenge.id,
          challengeID: challenge.id,
          Court_Name: court?.name || "Unknown Court",
          Court_Address: court?.address || "Unknown Address",
          Court_Rating: court?.rating || 0,
          Host_Team_Name: challenge.teamName || "Unknown Team",
          Host_Team_Points: hostTeamPoints,
          Sport: challenge.sport || teamSport,
          Status: challenge.status || "pending",
          Start_Time: challenge.stime,
          End_Time: challenge.etime,
          Date: challenge.stime
            ? new Date(challenge.stime).toISOString().split("T")[0]
            : null,
          courtFirebaseUID: challenge.courtFirebaseUID,
          hostTeamID: challenge.hostTeamID,
          Price: price,
          HourlyRate: hourlyRate,
          DurationHours: parseFloat(durationHours.toFixed(2)),
          court: court,
          hostTeam: hostTeam,
        };

        outgoing.push(challengeData);
      }
    }

    return { incoming, outgoing };
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const ChallengeController = {
  async create(req, res) {
    try {
      const hostTeamUID = req.user.uid;
      const challenge = await ChallengeService.createChallenge(
        hostTeamUID,
        req.body
      );

      return sendSuccess(res, 201, "Challenge created successfully ✅", {
        challengeID: challenge.id,
        challenge,
    });
  } catch (error) {
      if (
        error.message === "Team not found" ||
        error.message === "Challenge not found"
      ) {
        return sendNotFoundError(res, error.message.split(" ")[0]);
      }
      if (
        error.message.includes("required") ||
        error.message.includes("Invalid date")
      ) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getChallengeDetails(req, res) {
  try {
    const { challengeID } = req.params;
      const challenge = await ChallengeService.getChallengeById(challengeID);

      return sendSuccess(res, 200, "Challenge fetched successfully ✅", {
        challenge,
      });
    } catch (error) {
      if (error.message === "Challenge not found") {
        return sendNotFoundError(res, "Challenge");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getOpenChallenges(req, res) {
    try {
      const teamUID = req.user.uid;
      const challenges = await ChallengeService.getOpenChallenges(teamUID);

      return sendSuccess(
        res,
        200,
        "Open challenges fetched successfully ✅",
        challenges
      );
    } catch (error) {
      if (error.message === "Team not found") {
        return sendNotFoundError(res, "Team");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getCourtChallenges(req, res) {
    try {
      const { courtID } = req.params;
      const challenges = await ChallengeRepository.findByCourtId(courtID);

      // Get all matches to check which challenges are accepted
      const allMatches = await ChallengeRepository.findAllMatches();
      const acceptedChallengeIDs = new Set(
        allMatches.map((match) => match.Challenge_ID).filter((id) => id != null)
      );

      // Add isOpen flag to each challenge
      const challengesWithStatus = challenges.map((challenge) => ({
        ...challenge,
        isOpen: !acceptedChallengeIDs.has(challenge.id),
      }));

      return sendSuccess(res, 200, "Court challenges fetched successfully ✅", {
        challenges: challengesWithStatus,
    });
  } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async deleteChallenge(req, res) {
    try {
      const { challengeID } = req.params;
      const teamUID = req.user.uid;

      await ChallengeService.deleteChallenge(challengeID, teamUID);

      return sendSuccess(res, 200, "Challenge deleted successfully ✅");
    } catch (error) {
      if (error.message === "Challenge not found") {
        return sendNotFoundError(res, "Challenge");
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post("/create", verifyToken(["team"]), ChallengeController.create);
router.get(
  "/challenge-details/:challengeID",
  verifyToken(["team"]),
  ChallengeController.getChallengeDetails
);
router.get(
  "/open",
  verifyToken(["team"]),
  ChallengeController.getOpenChallenges
);
router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  ChallengeController.getCourtChallenges
);
router.delete(
  "/:challengeID",
  verifyToken(["team"]),
  ChallengeController.deleteChallenge
);

export default router;
