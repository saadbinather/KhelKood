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
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle booking business rules

const BookingService = {
  async createBooking(teamID, { courtID, startTime, endTime }) {
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

    // Create booking data
    const bookingData = {
      courtID,
      teamID,
      startTime: new Date(startTime),
      endTime: new Date(endTime),
      status: "Pending",
      createdAt: new Date(),
    };

    // Save booking
    const booking = await BookingRepository.create(bookingData);
    return booking;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const BookingController = {
  async bookCourt(req, res) {
    try {
      const teamID = req.user.uid;
      const booking = await BookingService.createBooking(teamID, req.body);

      return sendSuccess(res, 201, "Booking created successfully ✅", {
        bookingID: booking.id,
        booking,
      });
    } catch (error) {
      if (error.message === "Court not found") {
        return sendNotFoundError(res, "Court");
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
};

// ==================== ROUTES ====================
router.post("/book-court", verifyToken(["team"]), BookingController.bookCourt);

export default router;
