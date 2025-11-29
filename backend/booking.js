import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
} from "./utils/response.js";
import { validateRequired, validateDateRange } from "./utils/validators.js";
import axios from "axios";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for bookings

const BookingRepository = {
  async findCourtById(courtID) {
    const courtRef = db.collection("courts").doc(courtID);
    const courtDoc = await courtRef.get();
    return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
  },

  async create(bookingData) {
    const docRef = await db.collection("bookings").add(bookingData);
    return { id: docRef.id, ...bookingData };
  },

  async findByCourtId(courtID) {
    const bookingsSnapshot = await db
      .collection("bookings")
      .where("courtID", "==", courtID)
      .get();

    return bookingsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
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
// Single Responsibility: Handle booking business rules

const BookingService = {
  calculatePrice(courtData, sportType, startTime, endTime) {
    const durationHours =
      (new Date(endTime) - new Date(startTime)) / (1000 * 60 * 60);

    let hourlyRate;
    switch (sportType.toLowerCase()) {
      case "cricket":
        hourlyRate = courtData.cricketRate || 1800;
        break;
      case "futsal":
      case "football":
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

  async createPayment(amount, bookingID, token) {
    const BASE_URL = process.env.BASE_URL || "http://localhost:5000";
    const response = await axios.post(
      `${BASE_URL}/api/payments/create-payment`,
      { amount, bookingID },
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.data.data?.paymentID || response.data.paymentID;
  },

  async createBooking(teamID, { courtID, startTime, endTime }, token) {
    // Validation
    const validation = validateRequired({ courtID, startTime, endTime }, [
      "courtID",
      "startTime",
      "endTime",
    ]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const dateValidation = validateDateRange(startTime, endTime);
    if (!dateValidation.isValid) {
      throw new Error(dateValidation.error);
    }

    // Check if court exists
    const court = await BookingRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    // Get team to determine sport
    const team = await BookingRepository.findTeamByUserId(teamID);
    if (!team) {
      throw new Error("Team not found");
    }

    const sportType = team.sports || "futsal";

    // Calculate price
    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);
    const pricing = this.calculatePrice(
      court,
      sportType,
      startTimeDate,
      endTimeDate
    );

    // Create booking data
    const bookingData = {
      courtID,
      teamID,
      startTime: startTimeDate,
      endTime: endTimeDate,
      createdAt: new Date(),
    };

    // Save booking
    const booking = await BookingRepository.create(bookingData);

    // Create payment for friendly booking
    let paymentID = null;
    if (token && pricing.totalAmount > 0) {
      try {
        paymentID = await this.createPayment(
          pricing.totalAmount,
          booking.id,
          token
        );
      } catch (error) {
        console.error("Error creating payment:", error.message);
        // Continue even if payment creation fails (booking is still created)
      }
    }

    return {
      booking,
      paymentID,
      pricing,
    };
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const BookingController = {
  async bookCourt(req, res) {
    try {
      const teamID = req.user.uid;
      const token = req.headers.authorization?.replace("Bearer ", "");
      const result = await BookingService.createBooking(
        teamID,
        req.body,
        token
      );

      return sendSuccess(res, 201, "Booking created successfully ✅", {
        bookingID: result.booking.id,
        paymentID: result.paymentID,
        booking: result.booking,
        pricing: result.pricing,
      });
    } catch (error) {
      if (
        error.message === "Court not found" ||
        error.message === "Team not found"
      ) {
        return sendNotFoundError(
          res,
          error.message.includes("Court") ? "Court" : "Team"
        );
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

  async getCourtBookings(req, res) {
    try {
      const { courtID } = req.params;
      const bookings = await BookingRepository.findByCourtId(courtID);

      return sendSuccess(res, 200, "Court bookings fetched successfully ✅", {
        bookings,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post("/book-court", verifyToken(["team"]), BookingController.bookCourt);
router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  BookingController.getCourtBookings
);

export default router;
