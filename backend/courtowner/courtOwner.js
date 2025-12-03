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
import { validateRequired } from "../utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for court owners

const CourtOwnerRepository = {
  async findById(ownerID) {
    const ownerRef = db.collection("courtowners").doc(ownerID);
    const ownerDoc = await ownerRef.get();
    return ownerDoc.exists ? { id: ownerDoc.id, ...ownerDoc.data() } : null;
  },

  async update(ownerID, updates) {
    const ownerRef = db.collection("courtowners").doc(ownerID);
    await ownerRef.update({
      ...updates,
      updatedAt: new Date(),
    });
    return await this.findById(ownerID);
  },

  async findCourtsByOwnerId(ownerID) {
    const courtsQuery = db
      .collection("courts")
      .where("courtownerID", "==", ownerID);
    const courtsSnapshot = await courtsQuery.get();
    return courtsSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  },

  async updateCourts(ownerID, updates) {
    const courts = await this.findCourtsByOwnerId(ownerID);
    if (courts.length === 0) return [];

    const batch = db.batch();
    courts.forEach((court) => {
      const courtRef = db.collection("courts").doc(court.id);
      batch.update(courtRef, {
        ...updates,
        updatedAt: new Date(),
      });
    });
    await batch.commit();
    return courts;
  },

  async incrementFieldCount(ownerID, sportType) {
    const courts = await this.findCourtsByOwnerId(ownerID);
    if (courts.length === 0) {
      throw new Error("No court found for this courtowner");
    }

    const court = courts[0];
    const courtRef = db.collection("courts").doc(court.id);
    const currentData = court;

    let fieldToUpdate = "";
    const sport = sportType.toLowerCase();
    if (sport === "cricket") {
      fieldToUpdate = "numOfCricketFields";
    } else if (sport === "futsal" || sport === "football") {
      fieldToUpdate = "numOfFutsalFields";
    } else if (sport === "padel") {
      fieldToUpdate = "numOfPadelCourts";
    } else {
      throw new Error("Invalid sport type");
    }

    const currentCount = Number(currentData[fieldToUpdate]) || 0;
    await courtRef.update({
      [fieldToUpdate]: currentCount + 1,
      updatedAt: new Date(),
    });

    return await this.findCourtById(court.id);
  },

  async findCourtById(courtID) {
    const courtRef = db.collection("courts").doc(courtID);
    const courtDoc = await courtRef.get();
    return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
  },

  async findMatchById(matchID) {
    const matchRef = db.collection("matches").doc(matchID);
    const matchDoc = await matchRef.get();
    return matchDoc.exists ? { id: matchDoc.id, ...matchDoc.data() } : null;
  },

  async updateMatchWinner(matchID, winnerID) {
    const matchRef = db.collection("matches").doc(matchID);
    await matchRef.update({
      Winner: winnerID,
      updatedAt: new Date(),
    });
    return await this.findMatchById(matchID);
  },

  async findBookingsByCourtOwner(ownerID) {
    // Get all courts owned by this owner
    const courts = await this.findCourtsByOwnerId(ownerID);
    const courtIDs = courts.map((court) => court.id);

    if (courtIDs.length === 0) return [];

    // Firestore "in" query has a limit of 10 items, so we need to batch if needed
    const bookings = [];
    const batchSize = 10;

    for (let i = 0; i < courtIDs.length; i += batchSize) {
      const batch = courtIDs.slice(i, i + batchSize);
      const bookingsSnapshot = await db
        .collection("bookings")
        .where("courtID", "in", batch)
        .get();

      for (const bookingDoc of bookingsSnapshot.docs) {
        const booking = { id: bookingDoc.id, ...bookingDoc.data() };

        // Get court details
        const court = courts.find((c) => c.id === booking.courtID);
        if (court) {
          booking.court = court;
        }

        // Get team details
        if (booking.teamID) {
          const teamDoc = await db
            .collection("teams")
            .doc(booking.teamID)
            .get();
          if (teamDoc.exists) {
            booking.team = { id: teamDoc.id, ...teamDoc.data() };
          }
        }

        bookings.push(booking);
      }
    }

    return bookings;
  },

  async findBookingById(bookingID) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    const bookingDoc = await bookingRef.get();
    return bookingDoc.exists
      ? { id: bookingDoc.id, ...bookingDoc.data() }
      : null;
  },

  async updateBookingStatus(bookingID, status) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    await bookingRef.update({
      status,
      updatedAt: new Date(),
    });
    return await this.findBookingById(bookingID);
  },

  async create(courtData) {
    const docRef = await db.collection("courts").add(courtData);
    return { id: docRef.id, ...courtData };
  },

  async updateSingle(courtID, updates) {
    const courtRef = db.collection("courts").doc(courtID);
    await courtRef.update({
      ...updates,
      updatedAt: new Date(),
    });
    return await this.findCourtById(courtID);
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle court owner business rules

// Helper function to parse Firestore dates
const _parseFirestoreDate = (dateValue) => {
  if (!dateValue) return null;
  // Handle Firestore Timestamp
  if (dateValue.toDate && typeof dateValue.toDate === "function") {
    return dateValue.toDate();
  }
  // Handle Firestore Timestamp object with _seconds
  if (dateValue._seconds) {
    return new Date(dateValue._seconds * 1000);
  }
  // Handle regular Date object
  if (dateValue instanceof Date) {
    return dateValue;
  }
  // Handle ISO string
  if (typeof dateValue === "string") {
    return new Date(dateValue);
  }
  return null;
};

const CourtOwnerService = {
  async updateProfile(ownerID, updates) {
    const owner = await CourtOwnerRepository.findById(ownerID);
    if (!owner) {
      throw new Error("Courtowner not found");
    }
    return await CourtOwnerRepository.update(ownerID, updates);
  },

  async getProfile(ownerID) {
    const owner = await CourtOwnerRepository.findById(ownerID);
    if (!owner) {
      throw new Error("Courtowner not found");
    }

    // Get court information
    const courts = await CourtOwnerRepository.findCourtsByOwnerId(ownerID);
    const court = courts.length > 0 ? courts[0] : null;

    return {
      ...owner,
      court: court || null,
    };
  },

  async updateCourt(ownerID, updates) {
    const courts = await CourtOwnerRepository.updateCourts(ownerID, updates);
    if (courts.length === 0) {
      throw new Error("No court found for this courtowner");
    }
    return courts;
  },

  async addField(ownerID, sportType) {
    // Validation
    const validation = validateRequired({ sportType }, ["sportType"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const validSports = ["cricket", "futsal", "football", "padel"];
    if (!validSports.includes(sportType.toLowerCase())) {
      throw new Error(
        "Invalid sport type. Must be: cricket, futsal, football, or padel"
      );
    }

    return await CourtOwnerRepository.incrementFieldCount(ownerID, sportType);
  },

  async getCourtById(courtID) {
    const court = await CourtOwnerRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }
    return court;
  },

  async getMyCourt(ownerID) {
    const courts = await CourtOwnerRepository.findCourtsByOwnerId(ownerID);
    if (courts.length === 0) {
      throw new Error("No court found for this courtowner");
    }
    return courts[0];
  },

  async getAllCourts(ownerID) {
    const courts = await CourtOwnerRepository.findCourtsByOwnerId(ownerID);
    return courts;
  },

  async createCourt(ownerID, courtData) {
    const validation = validateRequired(courtData, ["sport"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const newCourt = {
      name: null,
      address: "",
      courtownerID: ownerID,
      sport: courtData.sport,
      cricketRate: courtData.cricketRate || 0,
      futsalRate: courtData.futsalRate || 0,
      padelRate: courtData.padelRate || 0,
      rating: 0,
      openingTime: 8,
      closingTime: 23,
      createdAt: new Date(),
    };

    return await CourtOwnerRepository.create(newCourt);
  },

  async updateSingleCourt(ownerID, courtID, updates) {
    const court = await CourtOwnerRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    if (court.courtownerID !== ownerID) {
      throw new Error("Unauthorized: You do not own this court");
    }

    return await CourtOwnerRepository.updateSingle(courtID, updates);
  },

  async setMatchWinner(courtownerID, matchID, winnerID) {
    // Validation
    const validation = validateRequired({ winnerID }, ["winnerID"]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    // Get match
    const match = await CourtOwnerRepository.findMatchById(matchID);
    if (!match) {
      throw new Error("Match not found");
    }

    // Validate winner ID
    const { Court_ID, Host_Team_ID, Guest_Team_ID } = match;
    if (winnerID !== Host_Team_ID && winnerID !== Guest_Team_ID) {
      throw new Error("winnerID must be either Host_Team_ID or Guest_Team_ID");
    }

    // Check court ownership
    const court = await CourtOwnerRepository.findCourtById(Court_ID);
    if (!court) {
      throw new Error("Court not found for this match");
    }

    if (court.courtownerID !== courtownerID) {
      throw new Error("Unauthorized: You do not own the court for this match");
    }

    // Update winner
    return await CourtOwnerRepository.updateMatchWinner(matchID, winnerID);
  },

  async getBookings(courtownerID) {
    const bookings = await CourtOwnerRepository.findBookingsByCourtOwner(
      courtownerID
    );
    const now = new Date();

    // Categorize bookings
    const incoming = [];
    const upcoming = [];
    const past = [];

    bookings.forEach((booking) => {
      const startTime = _parseFirestoreDate(booking.startTime);
      const endTime = _parseFirestoreDate(booking.endTime);

      if (!startTime) return; // Skip invalid dates

      if (booking.status === "Pending") {
        incoming.push(booking);
      } else if (
        booking.status === "Confirmed" ||
        booking.status === "Accepted"
      ) {
        if (startTime > now) {
          upcoming.push(booking);
        } else {
          past.push(booking);
        }
      } else if (
        booking.status === "Completed" ||
        booking.status === "Cancelled" ||
        booking.status === "Rejected"
      ) {
        past.push(booking);
      } else if (endTime && endTime < now) {
        past.push(booking);
      } else if (startTime > now) {
        upcoming.push(booking);
      } else {
        past.push(booking);
      }
    });

    // Sort by date
    const sortByDate = (a, b) => {
      const aTime = _parseFirestoreDate(a.startTime) || new Date(0);
      const bTime = _parseFirestoreDate(b.startTime) || new Date(0);
      return aTime - bTime;
    };

    const sortByDateDesc = (a, b) => {
      const aTime = _parseFirestoreDate(a.startTime) || new Date(0);
      const bTime = _parseFirestoreDate(b.startTime) || new Date(0);
      return bTime - aTime; // Most recent first
    };

    incoming.sort(sortByDate);
    upcoming.sort(sortByDate);
    past.sort(sortByDateDesc);

    return { incoming, upcoming, past };
  },

  async acceptBooking(courtownerID, bookingID) {
    const booking = await CourtOwnerRepository.findBookingById(bookingID);
    if (!booking) {
      throw new Error("Booking not found");
    }

    // Verify court ownership
    const court = await CourtOwnerRepository.findCourtById(booking.courtID);
    if (!court || court.courtownerID !== courtownerID) {
      throw new Error("Unauthorized: You do not own this court");
    }

    return await CourtOwnerRepository.updateBookingStatus(
      bookingID,
      "Confirmed"
    );
  },

  async rejectBooking(courtownerID, bookingID) {
    const booking = await CourtOwnerRepository.findBookingById(bookingID);
    if (!booking) {
      throw new Error("Booking not found");
    }

    // Verify court ownership
    const court = await CourtOwnerRepository.findCourtById(booking.courtID);
    if (!court || court.courtownerID !== courtownerID) {
      throw new Error("Unauthorized: You do not own this court");
    }

    return await CourtOwnerRepository.updateBookingStatus(
      bookingID,
      "Rejected"
    );
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const CourtOwnerController = {
  async updateProfile(req, res) {
    try {
      const ownerID = req.user.uid;
      const updatedOwner = await CourtOwnerService.updateProfile(
        ownerID,
        req.body
      );
      return sendSuccess(
        res,
        200,
        "Courtowner profile updated successfully ✅",
        {
          updatedFields: req.body,
          courtowner: updatedOwner,
        }
      );
    } catch (error) {
      if (error.message === "Courtowner not found") {
        return sendNotFoundError(res, "Courtowner");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getProfile(req, res) {
    try {
      const ownerID = req.user.uid;
      const profileData = await CourtOwnerService.getProfile(ownerID);

      // Separate courtowner and court data for cleaner response
      const { court, ...courtowner } = profileData;

      return sendSuccess(
        res,
        200,
        "Courtowner profile fetched successfully ✅",
        {
          courtowner: courtowner,
          court: court,
        }
      );
    } catch (error) {
      if (error.message === "Courtowner not found") {
        return sendNotFoundError(res, "Courtowner");
      }
      return sendError(res, 500, error.message);
    }
  },

  async updateCourt(req, res) {
    try {
      const ownerID = req.user.uid;
      const courts = await CourtOwnerService.updateCourt(ownerID, req.body);
      return sendSuccess(
        res,
        200,
        "Court(s) updated successfully for this courtowner ✅",
        {
          updatedFields: req.body,
          updatedCourtsCount: courts.length,
        }
      );
    } catch (error) {
      if (error.message.includes("No court found")) {
        return sendNotFoundError(res, "Court");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getCourtById(req, res) {
    try {
      const { courtID } = req.params;
      const court = await CourtOwnerService.getCourtById(courtID);
      return sendSuccess(res, 200, "Court details fetched successfully ✅", {
        court,
      });
    } catch (error) {
      if (error.message === "Court not found") {
        return sendNotFoundError(res, "Court");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getMyCourt(req, res) {
    try {
      const ownerID = req.user.uid;
      const court = await CourtOwnerService.getMyCourt(ownerID);
      return sendSuccess(res, 200, "Court fetched successfully ✅", { court });
    } catch (error) {
      if (error.message.includes("No court found")) {
        return sendNotFoundError(res, "Court");
      }
      return sendError(res, 500, error.message);
    }
  },

  async getAllCourts(req, res) {
    try {
      const ownerID = req.user.uid;
      const courts = await CourtOwnerService.getAllCourts(ownerID);
      return sendSuccess(res, 200, "Courts fetched successfully ✅", {
        courts,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async createCourt(req, res) {
    try {
      const ownerID = req.user.uid;
      const court = await CourtOwnerService.createCourt(ownerID, req.body);
      return sendSuccess(res, 201, "Court created successfully ✅", { court });
    } catch (error) {
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async updateSingleCourt(req, res) {
    try {
      const ownerID = req.user.uid;
      const { courtID } = req.params;
      const court = await CourtOwnerService.updateSingleCourt(
        ownerID,
        courtID,
        req.body
      );
      return sendSuccess(res, 200, "Court updated successfully ✅", { court });
    } catch (error) {
      if (error.message === "Court not found") {
        return sendNotFoundError(res, "Court");
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async setMatchWinner(req, res) {
    try {
      const courtownerID = req.user.uid;
      const { matchID } = req.params;
      const { winnerID } = req.body;
      const match = await CourtOwnerService.setMatchWinner(
        courtownerID,
        matchID,
        winnerID
      );
      return sendSuccess(res, 200, "Winner updated successfully ✅", {
        matchID,
        winnerID,
        match,
      });
    } catch (error) {
      if (
        error.message === "Match not found" ||
        error.message === "Court not found"
      ) {
        return sendNotFoundError(res, error.message.split(" ")[0]);
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      if (
        error.message.includes("required") ||
        error.message.includes("must be")
      ) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getBookings(req, res) {
    try {
      const courtownerID = req.user.uid;
      const bookings = await CourtOwnerService.getBookings(courtownerID);
      return sendSuccess(
        res,
        200,
        "Bookings fetched successfully ✅",
        bookings
      );
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async acceptBooking(req, res) {
    try {
      const courtownerID = req.user.uid;
      const { bookingID } = req.params;
      const booking = await CourtOwnerService.acceptBooking(
        courtownerID,
        bookingID
      );
      return sendSuccess(res, 200, "Booking accepted successfully ✅", {
        booking,
      });
    } catch (error) {
      if (error.message === "Booking not found") {
        return sendNotFoundError(res, "Booking");
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async rejectBooking(req, res) {
    try {
      const courtownerID = req.user.uid;
      const { bookingID } = req.params;
      const booking = await CourtOwnerService.rejectBooking(
        courtownerID,
        bookingID
      );
      return sendSuccess(res, 200, "Booking rejected successfully ✅", {
        booking,
      });
    } catch (error) {
      if (error.message === "Booking not found") {
        return sendNotFoundError(res, "Booking");
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async addField(req, res) {
    try {
      const ownerID = req.user.uid;
      const { sportType } = req.body;
      const court = await CourtOwnerService.addField(ownerID, sportType);
      return sendSuccess(res, 200, "Field added successfully ✅", { court });
    } catch (error) {
      if (
        error.message.includes("required") ||
        error.message.includes("Invalid")
      ) {
        return sendValidationError(res, error.message);
      }
      if (error.message.includes("No court found")) {
        return sendNotFoundError(res, "Court");
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================

router.put(
  "/edit-courtowner",
  verifyToken(["courtowner"]),
  CourtOwnerController.updateProfile
);
router.put(
  "/edit-court",
  verifyToken(["courtowner"]),
  CourtOwnerController.updateCourt
);
router.get(
  "/courtowner-profile",
  verifyToken(["courtowner"]),
  CourtOwnerController.getProfile
);
router.get(
  "/court/:courtID",
  verifyToken(["courtowner", "team", "admin"]),
  CourtOwnerController.getCourtById
);
router.get(
  "/my-court",
  verifyToken(["courtowner"]),
  CourtOwnerController.getMyCourt
);
router.get(
  "/courts",
  verifyToken(["courtowner"]),
  CourtOwnerController.getAllCourts
);
router.post(
  "/courts",
  verifyToken(["courtowner"]),
  CourtOwnerController.createCourt
);
router.put(
  "/courts/:courtID",
  verifyToken(["courtowner"]),
  CourtOwnerController.updateSingleCourt
);
router.put(
  "/makewinner/:matchID",
  verifyToken(["courtowner"]),
  CourtOwnerController.setMatchWinner
);
router.get(
  "/bookings",
  verifyToken(["courtowner"]),
  CourtOwnerController.getBookings
);
router.put(
  "/bookings/:bookingID/accept",
  verifyToken(["courtowner"]),
  CourtOwnerController.acceptBooking
);
router.put(
  "/bookings/:bookingID/reject",
  verifyToken(["courtowner"]),
  CourtOwnerController.rejectBooking
);
router.put(
  "/add-field",
  verifyToken(["courtowner"]),
  CourtOwnerController.addField
);

export default router;
