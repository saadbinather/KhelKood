/**
 * BookingController - Request Handling Layer for Bookings
 * Extends BaseController for common request/response handling
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only HTTP request/response logic
 * 2. Dependency Inversion: Depends on service abstraction
 */

import { BaseController } from "../core/BaseController.js";

export class BookingController extends BaseController {
  constructor(bookingService) {
    super(bookingService);
    this.bookingService = bookingService;
  }

  /**
   * Book a court
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async bookCourt(req, res) {
    try {
      const teamID = this.getUserId(req);
      const token = this.getToken(req);
      
      const result = await this.bookingService.createBooking(teamID, req.body, token);

      return this.handleSuccess(res, 201, "Booking created successfully ✅", {
        bookingID: result.booking.id,
        paymentID: result.paymentID,
        booking: result.booking,
        pricing: result.pricing,
      });
    } catch (error) {
      return this.handleError(res, error, 'Book Court');
    }
  }

  /**
   * Get court bookings
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getCourtBookings(req, res) {
    try {
      const { courtID } = req.params;
      const courtNum = req.query.courtNum ? parseInt(req.query.courtNum) : null;
      
      const bookings = await this.bookingService.getCourtBookings(courtID, courtNum);

      return this.handleSuccess(res, 200, "Bookings retrieved successfully", {
        bookings,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get Court Bookings');
    }
  }

  /**
   * Mark court as unavailable
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async markUnavailable(req, res) {
    try {
      const courtOwnerID = this.getUserId(req);
      
      const result = await this.bookingService.markCourtUnavailable(courtOwnerID, req.body);

      return this.handleSuccess(res, 201, "Court marked as unavailable successfully", {
        bookingID: result.booking.id,
        booking: result.booking,
      });
    } catch (error) {
      return this.handleError(res, error, 'Mark Unavailable');
    }
  }

  /**
   * Get booking history
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   */
  async getBookingHistory(req, res) {
    try {
      const teamID = this.getUserId(req);
      
      const bookings = await this.bookingService.getBookingHistory(teamID);

      return this.handleSuccess(res, 200, "Booking history retrieved successfully", {
        bookings,
      });
    } catch (error) {
      return this.handleError(res, error, 'Get Booking History');
    }
  }
}

