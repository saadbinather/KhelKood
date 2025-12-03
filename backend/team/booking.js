/**
 * Booking Module - Refactored with OOP and SOLID Principles
 * 
 * SOLID Principles Implemented:
 * 1. Single Responsibility Principle (SRP):
 *    - Repository: Handles only data access
 *    - Service: Handles only business logic
 *    - Controller: Handles only HTTP requests/responses
 * 
 * 2. Open/Closed Principle (OCP):
 *    - Base classes are open for extension but closed for modification
 *    - Pricing strategies can be added without modifying existing code
 * 
 * 3. Liskov Substitution Principle (LSP):
 *    - All strategies can be substituted for the base strategy
 *    - All repositories can be substituted for the base repository
 * 
 * 4. Interface Segregation Principle (ISP):
 *    - Small, focused interfaces (controller, service, repository)
 *    - Clients don't depend on methods they don't use
 * 
 * 5. Dependency Inversion Principle (DIP):
 *    - High-level modules (Controller) depend on abstractions (Service interface)
 *    - Low-level modules (Repository) depend on abstractions (Database interface)
 */

import express from "express";
import { db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import { BookingRepository } from "../src/repositories/BookingRepository.js";
import { BookingService } from "../src/services/BookingService.js";
import { BookingController } from "../src/controllers/BookingController.js";

const router = express.Router();

// Dependency Injection: Create instances with their dependencies
const bookingRepository = new BookingRepository(db);
const bookingService = new BookingService(bookingRepository);
const bookingController = new BookingController(bookingService);

// Routes
router.post(
  "/book-court",
  verifyToken(["team"]),
  (req, res) => bookingController.bookCourt(req, res)
);

router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner"]),
  (req, res) => bookingController.getCourtBookings(req, res)
);

router.post(
  "/mark-unavailable",
  verifyToken(["courtowner"]),
  (req, res) => bookingController.markUnavailable(req, res)
);

router.get(
  "/booking-history",
  verifyToken(["team"]),
  (req, res) => bookingController.getBookingHistory(req, res)
);

export default router;

