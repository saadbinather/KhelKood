import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError, sendUnauthorizedError } from "./utils/response.js";
import { validateRequired, validatePositiveNumber } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for payments

const PaymentRepository = {
  async findBookingById(bookingID) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    const bookingDoc = await bookingRef.get();
    return bookingDoc.exists ? { id: bookingDoc.id, ...bookingDoc.data() } : null;
  },

  async create(paymentData) {
    const paymentRef = await db.collection("payments").add(paymentData);
    return { id: paymentRef.id, ...paymentData };
  },

  async findById(paymentID) {
    const paymentRef = db.collection("payments").doc(paymentID);
    const paymentDoc = await paymentRef.get();
    return paymentDoc.exists ? { id: paymentDoc.id, ...paymentDoc.data() } : null;
  },

  async update(paymentID, updateData) {
    const paymentRef = db.collection("payments").doc(paymentID);
    await paymentRef.update(updateData);
    return await this.findById(paymentID);
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle payment business rules

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

  async updatePaymentStatus(paymentID, userID, userRole) {
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
      if (error.message.includes("required") || error.message.includes("Valid")) {
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
      
      const payment = await PaymentService.updatePaymentStatus(paymentID, userID, userRole);
      
      return sendSuccess(res, 200, "Payment status updated to paid successfully ✅", { payment });
    } catch (error) {
      if (error.message === "Payment not found") {
        return sendNotFoundError(res, "Payment");
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
};

// ==================== ROUTES ====================
router.post("/create-payment", verifyToken(["team"]), PaymentController.createPayment);

router.put("/update-payment/:paymentID", verifyToken(["courtowner"]), PaymentController.updatePaymentStatus);

export default router;