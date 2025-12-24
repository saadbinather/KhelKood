// import express from "express";
// import axios from "axios";
// import { verifyToken } from "./middleware/verifyToken.js";
// import { db } from "./config/firebase.js";

// const router = express.Router();

// // 🏆 Create Match by calling the Challenge API
// router.post("/create", verifyToken(["team"]), async (req, res) => {
//   try {
//     const { challengeID } = req.body;
//     const teamID = req.user.uid; // logged-in team UID

//     // 🔹 Call your own GET challenge API
//     const baseURL = "http://localhost:5000/api"; // adjust if needed
//     const response = await axios.get(
//       `${baseURL}/challenges/challenge-details/${challengeID}`,
//       {
//         headers: { Authorization: `Bearer ${req.headers.authorization.split(" ")[1]}` }
//       }
//     );

//     const challengeData = response.data.challenge;

//     // 🔹 Optional: check that logged-in team is host
//     if (challengeData.hostTeamID !== teamID) {
//       return res.status(403).json({ error: "Unauthorized to create match for this challenge" });
//     }

//     // 🔹 Build match data
//     const matchData = {
//       Court_ID: challengeData.courtFirebaseUID,
//       Host_Team_ID: challengeData.hostTeamID,
//       Sport: challengeData.sport || "futsal",
//       StartTime: challengeData.stime,
//       EndTime: challengeData.etime,
//       TeamName: challengeData.teamName,
//       Challenge_ID: challengeID,
//       createdAt: new Date(),
//     };

//     // 🔹 Save to Firestore
//     const docRef = await db.collection("matches").add(matchData);

//     res.status(201).json({
//       message: "Match created successfully ✅",
//       matchID: docRef.id,
//       match: matchData,
//     });
//   } catch (error) {
//     res.status(500).json({ error: error.response?.data || error.message });
//   }
// });

// export default router;

import express from "express";
import axios from "axios";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
  sendUnauthorizedError,
} from "../utils/response.js";
import { validateRequired } from "../utils/validators.js";
import EmailService from "../utils/emailService.js";

const router = express.Router();

const BASE_URL = "http://localhost:5000/api";

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for matches

const MatchRepository = {
  async findCourtById(courtID) {
    const courtDoc = await db.collection("courts").doc(courtID).get();
    return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
  },

  async create(matchData) {
    const matchRef = await db.collection("matches").add(matchData);
    return { id: matchRef.id, ...matchData };
  },

  async getChallengeById(challengeID, token) {
    const response = await axios.get(
      `${BASE_URL}/challenges/challenge-details/${challengeID}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.data.data?.challenge || response.data.challenge;
  },

  async createBooking(courtID, startTime, endTime, courtNum, token) {
    const response = await axios.post(
      `${BASE_URL}/booking/book-court`,
      { courtID, startTime, endTime, courtNum, skipPayment: true }, // Skip payment creation - match service will create it
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.data.data?.bookingID || response.data.bookingID;
  },

  async createPayment(amount, bookingID, token) {
    const response = await axios.post(
      `${BASE_URL}/payments/create-payment`,
      { amount, bookingID },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.data.data?.paymentID || response.data.paymentID;
  },

  async updateBooking(bookingID, updateData) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    await bookingRef.update({
      ...updateData,
      updatedAt: new Date(),
    });
    const bookingDoc = await bookingRef.get();
    return bookingDoc.exists
      ? { id: bookingDoc.id, ...bookingDoc.data() }
      : null;
  },

  async findTeamById(teamID) {
    const teamDoc = await db.collection("teams").doc(teamID).get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },

  async findUserByUid(uid) {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.exists ? { id: userDoc.id, ...userDoc.data() } : null;
  },

  async findCourtownerByUserId(courtownerID) {
    const courtownerDoc = await db.collection("courtowners").doc(courtownerID).get();
    return courtownerDoc.exists ? { id: courtownerDoc.id, ...courtownerDoc.data() } : null;
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle match business rules

const MatchService = {
  calculatePrice(courtData, sportType, startTime, endTime) {
    const durationHours =
      (new Date(endTime) - new Date(startTime)) / (1000 * 60 * 60);

    let hourlyRate;
    switch (sportType.toLowerCase()) {
      case "cricket":
        hourlyRate = courtData.cricketRate || 1800;
        break;
      case "futsal":
        hourlyRate = courtData.futsalRate || 2000;
        break;
      case "padel":
        hourlyRate = courtData.padelRate || 3500;
        break;
      default:
        hourlyRate = courtData.futsalRate || 2000;
    }

    return {
      hourlyRate,
      durationHours: parseFloat(durationHours.toFixed(2)),
      totalAmount: Math.round(durationHours * hourlyRate),
    };
  },

  async createCompetitiveMatch(teamID, challengeID, token) {
    // Validation
    const validation = validateRequired({ challengeID }, ["challengeID"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Get challenge
    const challenge = await MatchRepository.getChallengeById(
      challengeID,
      token
    );
    if (!challenge) {
      throw new Error("Challenge not found");
    }

    // Validate host team
    if (challenge.hostTeamID === teamID) {
      throw new Error("Unauthorized to create match for this challenge");
    }

    // Prepare data
    const startTime = new Date(challenge.stime);
    const endTime = new Date(challenge.etime);
    const courtID = challenge.courtFirebaseUID;
    const sportType = challenge.sport || "futsal";

    // Get court and calculate price
    const court = await MatchRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    const pricing = this.calculatePrice(court, sportType, startTime, endTime);

    // Create booking
    const bookingID = await MatchRepository.createBooking(
      courtID,
      startTime.toISOString(),
      endTime.toISOString(),
      challenge.courtNum,
      token
    );

    // Create payment
    const paymentID = await MatchRepository.createPayment(
      pricing.totalAmount,
      bookingID,
      token
    );

    // Create match
    const matchData = {
      Court_ID: courtID,
      Host_Team_ID: challenge.hostTeamID,
      Guest_Team_ID: teamID,
      Sport: sportType,
      courtNum: challenge.courtNum ? parseInt(challenge.courtNum) : null,
      StartTime: startTime,
      EndTime: endTime,
      matchType: "competitive",
      TeamName: challenge.teamName,
      Challenge_ID: challengeID,
      Booking_ID: bookingID,
      Payment_ID: paymentID,
      Winner: null,
      createdAt: new Date(),
    };

    const match = await MatchRepository.create(matchData);

    // Update booking with matchID (only for competitive matches from challenges)
    await MatchRepository.updateBooking(bookingID, {
      matchID: match.id,
    });

    // Send email notifications
    try {
      // Get host team (challenge creator) info
      const hostTeam = await MatchRepository.findTeamById(challenge.hostTeamID);
      const hostUser = hostTeam?.userId ? await MatchRepository.findUserByUid(hostTeam.userId) : null;
      
      // Get accepting team (guest team) info
      const acceptingTeam = await MatchRepository.findTeamById(teamID);
      const guestUser = acceptingTeam?.userId ? await MatchRepository.findUserByUid(acceptingTeam.userId) : null;
      
      // Get court name
      const courtName = court?.name || "Unknown Court";
      const hostTeamName = challenge.teamName || hostTeam?.teamName || "Unknown Team";
      const guestTeamName = acceptingTeam?.teamName || "Unknown Team";
      
      // Send challenge acceptance notification to creator
      await EmailService.notifyChallengeCreatorOnAcceptance({
        creatorEmail: hostUser?.email || hostTeam?.email || null,
        creatorTeamName: hostTeamName,
        acceptingTeamName: guestTeamName,
        sport: sportType,
        courtName: courtName,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      });

      // Get court owner email
      let courtOwnerEmail = null;
      if (court?.courtownerID) {
        const courtowner = await MatchRepository.findCourtownerByUserId(court.courtownerID);
        if (courtowner?.userId) {
          const courtownerUser = await MatchRepository.findUserByUid(courtowner.userId);
          courtOwnerEmail = courtownerUser?.email || courtowner?.email || null;
        }
      }

      // Send match creation notification to both teams and court owner
      await EmailService.notifyMatchCreated({
        hostTeamEmail: hostUser?.email || hostTeam?.email || null,
        hostTeamName: hostTeamName,
        guestTeamEmail: guestUser?.email || acceptingTeam?.email || null,
        guestTeamName: guestTeamName,
        sport: sportType,
        courtName: courtName,
        courtNum: challenge.courtNum,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
        courtOwnerEmail: courtOwnerEmail,
      });
    } catch (error) {
      console.error("Error sending email notifications:", error);
      // Don't throw - email failure shouldn't break match creation
    }

    return {
      match,
      bookingID,
      paymentID,
      pricing: {
        sportType,
        ...pricing,
      },
    };
  },

  async createFriendlyMatch(
    teamID,
    { courtID, sport, startTime, endTime, teamName, courtNum },
    token
  ) {
    // Validation
    const validation = validateRequired(
      { courtID, sport, startTime, endTime, teamName, courtNum },
      ["courtID", "sport", "startTime", "endTime", "teamName", "courtNum"]
    );
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Get court and calculate price
    const court = await MatchRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);
    const pricing = this.calculatePrice(
      court,
      sport,
      startTimeDate,
      endTimeDate
    );

    // Create booking
    const bookingID = await MatchRepository.createBooking(
      courtID,
      startTimeDate.toISOString(),
      endTimeDate.toISOString(),
      parseInt(courtNum),
      token
    );

    // Create payment
    const paymentID = await MatchRepository.createPayment(
      pricing.totalAmount,
      bookingID,
      token
    );

    // Create match
    const matchData = {
      Court_ID: courtID,
      Host_Team_ID: teamID,
      Sport: sport,
      courtNum: parseInt(courtNum),
      StartTime: startTimeDate,
      EndTime: endTimeDate,
      TeamName: teamName,
      matchType: "friendly",
      Booking_ID: bookingID,
      Payment_ID: paymentID,
      Winner: null,
      createdAt: new Date(),
    };

    const match = await MatchRepository.create(matchData);

    return {
      match,
      bookingID,
      paymentID,
      pricing: {
        sportType: sport,
        ...pricing,
      },
    };
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const MatchController = {
  async createCompetitiveMatch(req, res) {
    try {
      const teamID = req.user.uid;
      const { challengeID } = req.body;
      const token = req.headers.authorization.split(" ")[1];

      const result = await MatchService.createCompetitiveMatch(
        teamID,
        challengeID,
        token
      );

      return sendSuccess(
        res,
        201,
        "Match, booking and payment created successfully ✅",
        {
          matchID: result.match.id,
          bookingID: result.bookingID,
          paymentID: result.paymentID,
          match: result.match,
          pricingDetails: result.pricing,
        }
      );
    } catch (error) {
      if (
        error.message === "Challenge not found" ||
        error.message === "Court not found"
      ) {
        return sendNotFoundError(res, error.message.split(" ")[0]);
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      const errorMessage = error.response?.data?.error || error.message;
      return sendError(res, 500, errorMessage);
    }
  },

  async createFriendlyMatch(req, res) {
    try {
      const teamID = req.user.uid;
      const token = req.headers.authorization.split(" ")[1];

      const result = await MatchService.createFriendlyMatch(
        teamID,
        req.body,
        token
      );

      return sendSuccess(
        res,
        201,
        "Friendly match, booking and payment created successfully ✅",
        {
          matchID: result.match.id,
          bookingID: result.bookingID,
          paymentID: result.paymentID,
          match: result.match,
          pricingDetails: result.pricing,
        }
      );
    } catch (error) {
      if (error.message === "Court not found") {
        return sendNotFoundError(res, "Court");
      }
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      const errorMessage = error.response?.data?.error || error.message;
      return sendError(res, 500, errorMessage);
    }
  },
};

// ==================== ROUTES ====================

router.post(
  "/create",
  verifyToken(["team"]),
  MatchController.createCompetitiveMatch
);

router.post(
  "/create-friendly",
  verifyToken(["team"]),
  MatchController.createFriendlyMatch
);

export default router;
