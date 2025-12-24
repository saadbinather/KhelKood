import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendNotFoundError,
} from "../utils/response.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for courts

const CourtsRepository = {
  async findAllCourts() {
    const courtsSnapshot = await db.collection("courts").get();
    return courtsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findUserByUid(uid) {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.exists ? { id: userDoc.id, ...userDoc.data() } : null;
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
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle court business rules

const CourtsService = {
  async getVerifiedCourts(userId, userRole) {
    // Get all courts
    const allCourts = await CourtsRepository.findAllCourts();

    // Get team's sport if user is a team
    let teamSport = null;
    if (userRole === "team") {
      const team = await CourtsRepository.findTeamByUserId(userId);
      if (team && team.sports) {
        teamSport = team.sports.toLowerCase();
      }
    }

    // Filter courts where owner is verified and has facilities for team's sport
    const verifiedCourts = [];
    for (const court of allCourts) {
      if (court.courtownerID) {
        const owner = await CourtsRepository.findUserByUid(court.courtownerID);
        if (
          owner &&
          owner.verificationStatus &&
          owner.verificationStatus.toLowerCase() === "verified"
        ) {
          // Filter by sport if team is requesting
          if (teamSport) {
            if (
              teamSport === "cricket" &&
              (!court.numOfCricketFields || court.numOfCricketFields === 0)
            ) {
              continue; // Skip if no cricket fields
            } else if (
              (teamSport === "football" || teamSport === "futsal") &&
              (!court.numOfFutsalFields || court.numOfFutsalFields === 0)
            ) {
              continue; // Skip if no futsal fields
            } else if (
              teamSport === "padel" &&
              (!court.numOfPadelCourts || court.numOfPadelCourts === 0)
            ) {
              continue; // Skip if no padel courts
            }
          }

          verifiedCourts.push({
            id: court.id,
            name: court.name || "",
            address: court.address || "",
            location: court.location || "",
            coordinates: court.coordinates || null,
            courtownerID: court.courtownerID,
            rating: court.rating || 0,
            cricketRate: court.cricketRate || 0,
            futsalRate: court.futsalRate || 0,
            padelRate: court.padelRate || 0,
            openingTime: court.openingTime || 8,
            closingTime: court.closingTime || 23,
            numOfCricketFields: court.numOfCricketFields || 0,
            numOfFutsalFields: court.numOfFutsalFields || 0,
            numOfPadelCourts: court.numOfPadelCourts || 0,
          });
        }
      }
    }

    return verifiedCourts;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const CourtsController = {
  async getVerifiedCourts(req, res) {
    try {
      const userId = req.user.uid;
      const userRole = req.user.role || "team";
      const courts = await CourtsService.getVerifiedCourts(userId, userRole);
      return sendSuccess(res, 200, "Verified courts fetched successfully ✅", {
        count: courts.length,
        courts,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.get(
  "/verified",
  verifyToken(["team", "courtowner", "admin"]),
  CourtsController.getVerifiedCourts
);

export default router;
