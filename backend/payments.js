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
import {
  validateRequired,
  validatePositiveNumber,
} from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for payments

const PaymentRepository = {
  async findBookingById(bookingID) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    const bookingDoc = await bookingRef.get();
    return bookingDoc.exists
      ? { id: bookingDoc.id, ...bookingDoc.data() }
      : null;
  },

  async create(paymentData) {
    const paymentRef = await db.collection("payments").add(paymentData);
    return { id: paymentRef.id, ...paymentData };
  },

  async findById(paymentID) {
    const paymentRef = db.collection("payments").doc(paymentID);
    const paymentDoc = await paymentRef.get();
    return paymentDoc.exists
      ? { id: paymentDoc.id, ...paymentDoc.data() }
      : null;
  },

  async update(paymentID, updateData) {
    const paymentRef = db.collection("payments").doc(paymentID);
    await paymentRef.update(updateData);
    return await this.findById(paymentID);
  },

  async findCourtsByOwnerId(ownerID) {
    const courtsQuery = db
      .collection("courts")
      .where("courtownerID", "==", ownerID);
    const courtsSnapshot = await courtsQuery.get();
    return courtsSnapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  },

  async findBookingsByCourtIds(courtIDs) {
    if (courtIDs.length === 0) return [];

    const bookings = [];
    const batchSize = 10;

    for (let i = 0; i < courtIDs.length; i += batchSize) {
      const batch = courtIDs.slice(i, i + batchSize);
      const bookingsSnapshot = await db
        .collection("bookings")
        .where("courtID", "in", batch)
        .get();

      bookingsSnapshot.docs.forEach((doc) => {
        bookings.push({ id: doc.id, ...doc.data() });
      });
    }

    return bookings;
  },

  async findPaymentsByBookingIds(bookingIDs) {
    if (bookingIDs.length === 0) return [];

    const payments = [];
    const batchSize = 10;

    for (let i = 0; i < bookingIDs.length; i += batchSize) {
      const batch = bookingIDs.slice(i, i + batchSize);
      const paymentsSnapshot = await db
        .collection("payments")
        .where("bookingID", "in", batch)
        .get();

      paymentsSnapshot.docs.forEach((doc) => {
        payments.push({ id: doc.id, ...doc.data() });
      });
    }

    return payments;
  },

  async findTeamById(teamID) {
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle payment business rules

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

const PaymentService = {
  async createPayment(teamID, { amount, bookingID }) {
    // Validation
    const amountValidation = validatePositiveNumber(amount, "amount");
    if (!amountValidation.isValid) {
      throw new Error(amountValidation.error);
    }

    const bookingValidation = validateRequired({ bookingID }, ["bookingID"]);
    if (!bookingValidation.isValid) {
      throw new Error(bookingValidation.error);
    }

    // Verify booking exists
    const booking = await PaymentRepository.findBookingById(bookingID.trim());
    if (!booking) {
      throw new Error("Booking not found");
    }

    // Create payment data
    const paymentData = {
      amount: Number(amount),
      bookingID: bookingID.trim(),
      status: false, // false = payment pending
      teamID: teamID,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    return await PaymentRepository.create(paymentData);
  },

  async updatePaymentStatus(paymentID, userID, userRole, courtOwnerID) {
    // Validation
    if (!paymentID || paymentID.trim() === "") {
      throw new Error("paymentID is required");
    }

    // Get payment
    const payment = await PaymentRepository.findById(paymentID);
    if (!payment) {
      throw new Error("Payment not found");
    }

    // Authorization check
    if (userRole === "team" && payment.teamID !== userID) {
      throw new Error("Unauthorized - You can only update your own payments");
    }

    // For courtOwner: verify they own the court for this payment's booking
    if (userRole === "courtowner" && courtOwnerID) {
      const booking = await PaymentRepository.findBookingById(
        payment.bookingID
      );
      if (!booking) {
        throw new Error("Booking not found for this payment");
      }

      const courts = await PaymentRepository.findCourtsByOwnerId(courtOwnerID);
      const courtIds = courts.map((c) => c.id);
      if (!courtIds.includes(booking.courtID)) {
        throw new Error(
          "Unauthorized - You do not own the court for this payment"
        );
      }
    }

    // Check if already paid
    if (payment.status === true) {
      throw new Error("Payment is already completed");
    }

    // Update payment
    const updateData = {
      status: true, // true = payment completed
      updatedAt: new Date(),
    };

    return await PaymentRepository.update(paymentID, updateData);
  },

  async getPendingPaymentsForCourtOwner(courtOwnerID) {
    // Database structure:
    // - Payments: { bookingID, teamID, amount, status, createdAt, updatedAt }
    // - Bookings: { courtID, teamID, startTime, endTime, status, createdAt }
    // - Courts: { courtownerID, name, address, ... }
    // Flow: Courts → Bookings (via courtID) → Payments (via bookingID)

    // Step 1: Get all courts owned by this courtOwner
    const courts = await PaymentRepository.findCourtsByOwnerId(courtOwnerID);
    const courtIDs = courts.map((court) => court.id);

    if (courtIDs.length === 0) return [];

    // Step 2: Get all bookings for these courts (bookings have courtID)
    const bookings = await PaymentRepository.findBookingsByCourtIds(courtIDs);
    const bookingIDs = bookings.map((booking) => booking.id);

    if (bookingIDs.length === 0) return [];

    // Step 3: Get all payments for these bookings (payments have bookingID)
    const allPayments = await PaymentRepository.findPaymentsByBookingIds(
      bookingIDs
    );

    // Step 4: Filter pending payments (status === false)
    const pendingPayments = allPayments.filter(
      (payment) => payment.status === false
    );

    // Step 5: Filter payments where booking time has passed (match has been conducted)
    const now = new Date();
    const pastPendingPayments = pendingPayments.filter((payment) => {
      // Get booking using payment.bookingID (payments don't have courtID directly)
      const booking = bookings.find((b) => b.id === payment.bookingID);
      if (!booking || !booking.endTime) return false;

      const endTime = _parseFirestoreDate(booking.endTime);
      if (!endTime) return false;

      // Only include payments where booking endTime has passed
      return endTime < now;
    });

    // Step 6: Enrich payments with booking, court, and team information
    const enrichedPayments = await Promise.all(
      pastPendingPayments.map(async (payment) => {
        // Get booking using payment.bookingID
        const booking = bookings.find((b) => b.id === payment.bookingID);
        // Get court using booking.courtID (bookings have courtID, payments don't)
        const court = booking
          ? courts.find((c) => c.id === booking.courtID)
          : null;
        // Get team using payment.teamID (payments have teamID)
        const team = payment.teamID
          ? await PaymentRepository.findTeamById(payment.teamID)
          : null;

        return {
          id: payment.id,
          amount: payment.amount,
          status: payment.status,
          createdAt: payment.createdAt,
          updatedAt: payment.updatedAt,
          booking: booking
            ? {
                id: booking.id,
                courtID: booking.courtID,
                startTime: booking.startTime,
                endTime: booking.endTime,
                status: booking.status,
              }
            : null,
          court: court
            ? {
                id: court.id,
                name: court.name,
                address: court.address,
              }
            : null,
          team: team
            ? {
                id: team.id,
                teamName: team.teamName || team.name,
              }
            : null,
        };
      })
    );

    return enrichedPayments;
  },

  async getPaidBookingsForCourtOwner(courtOwnerID) {
    // Database structure:
    // - Payments: { bookingID, teamID, amount, status, createdAt, updatedAt }
    // - Bookings: { courtID, teamID, startTime, endTime, status, createdAt }
    // - Courts: { courtownerID, name, address, ... }
    // Flow: Courts → Bookings (via courtID) → Payments (via bookingID)

    // Step 1: Get all courts owned by this courtOwner
    const courts = await PaymentRepository.findCourtsByOwnerId(courtOwnerID);
    const courtIDs = courts.map((court) => court.id);

    if (courtIDs.length === 0) return [];

    // Step 2: Get all bookings for these courts (bookings have courtID)
    const bookings = await PaymentRepository.findBookingsByCourtIds(courtIDs);
    const bookingIDs = bookings.map((booking) => booking.id);

    if (bookingIDs.length === 0) return [];

    // Step 3: Get all payments for these bookings (payments have bookingID)
    const allPayments = await PaymentRepository.findPaymentsByBookingIds(
      bookingIDs
    );

    // Step 4: Filter paid payments (status === true)
    const paidPayments = allPayments.filter(
      (payment) => payment.status === true
    );

    // Step 5: Get unique booking IDs from paid payments
    const paidBookingIDs = [...new Set(paidPayments.map((p) => p.bookingID))];

    // Step 6: Get paid bookings with payment information
    const paidBookings = await Promise.all(
      paidBookingIDs.map(async (bookingID) => {
        // Get booking using bookingID
        const booking = bookings.find((b) => b.id === bookingID);
        // Get payment using payment.bookingID
        const payment = paidPayments.find((p) => p.bookingID === bookingID);
        // Get court using booking.courtID (bookings have courtID, payments don't)
        const court = booking
          ? courts.find((c) => c.id === booking.courtID)
          : null;
        // Get team using payment.teamID (payments have teamID)
        // Note: Both booking.teamID and payment.teamID should match, but using payment.teamID for accuracy
        const team =
          payment && payment.teamID
            ? await PaymentRepository.findTeamById(payment.teamID)
            : null;

        return {
          booking: booking
            ? {
                id: booking.id,
                courtID: booking.courtID,
                startTime: booking.startTime,
                endTime: booking.endTime,
                status: booking.status,
                createdAt: booking.createdAt,
              }
            : null,
          payment: payment
            ? {
                id: payment.id,
                amount: payment.amount,
                status: payment.status,
                createdAt: payment.createdAt,
                updatedAt: payment.updatedAt,
              }
            : null,
          court: court
            ? {
                id: court.id,
                name: court.name,
                address: court.address,
              }
            : null,
          team: team
            ? {
                id: team.id,
                teamName: team.teamName || team.name,
              }
            : null,
        };
      })
    );

    return paidBookings;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const PaymentController = {
  async createPayment(req, res) {
    try {
      const teamID = req.user.uid;
      const payment = await PaymentService.createPayment(teamID, req.body);

      return sendSuccess(res, 201, "Payment created successfully ✅", {
        paymentID: payment.id,
        payment,
      });
    } catch (error) {
      if (error.message === "Booking not found") {
        return sendNotFoundError(res, "Booking");
      }
      if (
        error.message.includes("required") ||
        error.message.includes("Valid")
      ) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async updatePaymentStatus(req, res) {
    try {
      const { paymentID } = req.params;
      const userID = req.user.uid;
      const userRole = req.user.role;
      const courtOwnerID = userRole === "courtowner" ? userID : null;

      const payment = await PaymentService.updatePaymentStatus(
        paymentID,
        userID,
        userRole,
        courtOwnerID
      );

      return sendSuccess(
        res,
        200,
        "Payment status updated to paid successfully ✅",
        { payment }
      );
    } catch (error) {
      if (
        error.message === "Payment not found" ||
        error.message === "Booking not found"
      ) {
        return sendNotFoundError(res, error.message.split(" ")[0]);
      }
      if (error.message.includes("Unauthorized")) {
        return sendUnauthorizedError(res, error.message);
      }
      if (error.message.includes("already completed")) {
        return sendValidationError(res, error.message);
      }
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getPendingPayments(req, res) {
    try {
      const courtOwnerID = req.user.uid;
      const pendingPayments =
        await PaymentService.getPendingPaymentsForCourtOwner(courtOwnerID);

      return sendSuccess(res, 200, "Pending payments fetched successfully ✅", {
        payments: pendingPayments,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async getPaidBookings(req, res) {
    try {
      const courtOwnerID = req.user.uid;
      const paidBookings = await PaymentService.getPaidBookingsForCourtOwner(
        courtOwnerID
      );

      return sendSuccess(res, 200, "Paid bookings fetched successfully ✅", {
        bookings: paidBookings,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post(
  "/create-payment",
  verifyToken(["team"]),
  PaymentController.createPayment
);

router.put(
  "/update-payment/:paymentID",
  verifyToken(["courtowner"]),
  PaymentController.updatePaymentStatus
);

router.get(
  "/pending-payments",
  verifyToken(["courtowner"]),
  PaymentController.getPendingPayments
);

router.get(
  "/paid-bookings",
  verifyToken(["courtowner"]),
  PaymentController.getPaidBookings
);

export default router;
