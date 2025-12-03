/**
 * BookingService - Business Logic Layer for Bookings
 * Extends BaseService for common validation and error handling
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only booking business logic
 * 2. Dependency Inversion: Depends on repository and pricing strategy abstractions
 * 3. Open/Closed: Can be extended with new features without modification
 */

import { BaseService } from "../core/BaseService.js";
import { PricingStrategyFactory } from "../strategies/PricingStrategy.js";
import axios from "axios";

export class BookingService extends BaseService {
  constructor(bookingRepository) {
    super(bookingRepository);
    this.bookingRepository = bookingRepository;
  }

  /**
   * Calculate pricing using strategy pattern
   * @param {Object} courtData - Court data
   * @param {string} sportType - Sport type
   * @param {Date} startTime - Start time
   * @param {Date} endTime - End time
   * @returns {Object} Pricing details
   */
  calculatePrice(courtData, sportType, startTime, endTime) {
    const pricingStrategy = PricingStrategyFactory.getStrategy(sportType);
    return pricingStrategy.calculate(courtData, startTime, endTime);
  }

  /**
   * Create payment for booking
   * @param {number} amount - Payment amount
   * @param {string} bookingID - Booking ID
   * @param {string} token - Auth token
   * @returns {Promise<string>} Payment ID
   */
  async createPayment(amount, bookingID, token) {
    try {
      const response = await axios.post(
        "http://localhost:5000/api/payment/create",
        { amount, bookingID },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      return response.data.data?.paymentID || response.data.paymentID;
    } catch (error) {
      throw new Error(`Payment creation failed: ${error.message}`);
    }
  }

  /**
   * Create a booking
   * @param {string} teamID - Team ID
   * @param {Object} bookingData - Booking data
   * @param {string} token - Auth token
   * @returns {Promise<Object>} Created booking with pricing
   */
  async createBooking(teamID, bookingData, token) {
    const { courtID, startTime, endTime, courtNum, skipPayment } = bookingData;

    // Validate required fields
    this.validateRequired(
      { courtID, startTime, endTime, courtNum },
      ["courtID", "startTime", "endTime", "courtNum"]
    );

    // Validate date range
    this.validateDateRange(startTime, endTime);

    // Check if court exists
    const court = await this.bookingRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    // Get team to determine sport
    const team = await this.bookingRepository.findTeamByUserId(teamID);
    if (!team) {
      throw new Error("Team not found");
    }

    const sportType = team.sports || "futsal";

    // Calculate price using strategy pattern
    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);
    const pricing = this.calculatePrice(court, sportType, startTimeDate, endTimeDate);

    // Create booking data
    const bookingEntry = {
      courtID,
      teamID,
      courtNum: parseInt(courtNum),
      sportType,
      startTime: startTimeDate,
      endTime: endTimeDate,
      createdAt: new Date(),
    };

    // Save booking
    const booking = await this.bookingRepository.create(bookingEntry);

    // Create payment (skip if requested - e.g., when called from match creation)
    let paymentID = null;
    if (!skipPayment && token) {
      try {
        paymentID = await this.createPayment(pricing.totalAmount, booking.id, token);
      } catch (paymentError) {
        // Rollback: delete booking if payment fails
        await this.bookingRepository.delete(booking.id);
        throw new Error(`Payment failed: ${paymentError.message}`);
      }
    }

    return { booking, paymentID, pricing };
  }

  /**
   * Mark court as unavailable
   * @param {string} courtOwnerID - Court owner ID
   * @param {Object} unavailableData - Unavailable time data
   * @returns {Promise<Object>} Created unavailable booking
   */
  async markCourtUnavailable(courtOwnerID, unavailableData) {
    const { courtID, startTime, endTime, courtNum } = unavailableData;

    // Validate required fields
    this.validateRequired(
      { courtID, startTime, endTime, courtNum },
      ["courtID", "startTime", "endTime", "courtNum"]
    );

    // Validate date range
    this.validateDateRange(startTime, endTime);

    // Check if court exists and verify ownership
    const court = await this.bookingRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    if (court.courtownerID !== courtOwnerID) {
      throw new Error("Unauthorized: You do not own this court");
    }

    // Create unavailable booking data (no teamID, no payment)
    const bookingEntry = {
      courtID,
      courtNum: parseInt(courtNum),
      startTime: new Date(startTime),
      endTime: new Date(endTime),
      isUnavailable: true,
    };

    // Save booking (no payment created)
    const booking = await this.bookingRepository.create(bookingEntry);

    return { booking };
  }

  /**
   * Get booking history for a team
   * @param {string} teamID - Team ID
   * @returns {Promise<Array>} Booking history with match information
   */
  async getBookingHistory(teamID) {
    // Get all bookings for this team
    const bookings = await this.bookingRepository.findByTeamId(teamID);

    // Get all matches where this team participated
    const matches = await this.bookingRepository.findMatchesByTeamId(teamID);

    // Track processed matches
    const processedMatchIds = new Set();

    // Enrich bookings with court, match, and opponent information
    const enrichedBookings = await Promise.all(
      bookings.map(async (booking) => {
        const court = await this.bookingRepository.findCourtById(booking.courtID);
        const courtName = court ? court.name : "Unknown Court";

        const startTime = booking.startTime?.toDate
          ? booking.startTime.toDate()
          : new Date(booking.startTime);
        const endTime = booking.endTime?.toDate
          ? booking.endTime.toDate()
          : new Date(booking.endTime);

        let opponent = null;
        let status = null;
        let pointsEarned = 0;

        // If booking has a matchID, it's a competitive match
        if (booking.matchID) {
          processedMatchIds.add(booking.matchID);
          const match = await this.bookingRepository.findMatchById(booking.matchID);
          
          if (match) {
            // Determine opponent
            if (match.Host_Team_ID === teamID && match.Guest_Team_ID) {
              const guestTeam = await this.bookingRepository.findTeamById(match.Guest_Team_ID);
              opponent = guestTeam ? guestTeam.teamName : "Unknown Team";
            } else if (match.Guest_Team_ID === teamID && match.Host_Team_ID) {
              const hostTeam = await this.bookingRepository.findTeamById(match.Host_Team_ID);
              opponent = hostTeam ? hostTeam.teamName : "Unknown Team";
            }

            // Determine status based on winner
            if (match.Winner === null) {
              status = "Pending";
            } else if (match.Winner === "tie") {
              status = "Tie";
              pointsEarned = 1;
            } else if (match.Winner === teamID) {
              status = "Won";
              pointsEarned = 3;
            } else {
              status = "Lost";
              pointsEarned = 0;
            }
          }
        } else {
          status = "Friendly";
        }

        return {
          id: booking.id,
          date: startTime.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
          }),
          time: `${startTime.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
          })} - ${endTime.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
          })}`,
          court: courtName,
          opponent,
          status,
          pointsEarned,
          startTime: startTime.toISOString(),
          endTime: endTime.toISOString(),
          isMatch: !!booking.matchID,
        };
      })
    );

    // Add matches without bookings
    const matchBookings = await Promise.all(
      matches
        .filter(match => !processedMatchIds.has(match.id))
        .map(async (match) => {
          const court = await this.bookingRepository.findCourtById(match.Court_ID);
          const courtName = court ? court.name : "Unknown Court";

          const startTime = match.StartTime?.toDate
            ? match.StartTime.toDate()
            : new Date(match.StartTime);
          const endTime = match.EndTime?.toDate
            ? match.EndTime.toDate()
            : new Date(match.EndTime);

          let opponent = null;
          if (match.Host_Team_ID === teamID && match.Guest_Team_ID) {
            const guestTeam = await this.bookingRepository.findTeamById(match.Guest_Team_ID);
            opponent = guestTeam ? guestTeam.teamName : "Unknown Team";
          } else if (match.Guest_Team_ID === teamID && match.Host_Team_ID) {
            const hostTeam = await this.bookingRepository.findTeamById(match.Host_Team_ID);
            opponent = hostTeam ? hostTeam.teamName : "Unknown Team";
          }

          let status = null;
          let pointsEarned = 0;
          if (match.Winner === null) {
            status = "Pending";
          } else if (match.Winner === "tie") {
            status = "Tie";
            pointsEarned = 1;
          } else if (match.Winner === teamID) {
            status = "Won";
            pointsEarned = 3;
          } else {
            status = "Lost";
            pointsEarned = 0;
          }

          return {
            id: match.id,
            date: startTime.toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            }),
            time: `${startTime.toLocaleTimeString("en-US", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            })} - ${endTime.toLocaleTimeString("en-US", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            })}`,
            court: courtName,
            opponent,
            status,
            pointsEarned,
            startTime: startTime.toISOString(),
            endTime: endTime.toISOString(),
            isMatch: true,
          };
        })
    );

    // Combine and sort all bookings
    const allBookings = [...enrichedBookings, ...matchBookings];
    return allBookings.sort((a, b) => {
      const aTime = new Date(a.startTime).getTime();
      const bTime = new Date(b.startTime).getTime();
      return bTime - aTime;
    });
  }

  /**
   * Get court bookings
   * @param {string} courtID - Court ID
   * @param {number|null} courtNum - Optional court number
   * @returns {Promise<Array>} Court bookings with team names
   */
  async getCourtBookings(courtID, courtNum = null) {
    const bookings = await this.bookingRepository.findByCourtId(courtID, courtNum);

    // Enrich bookings with team information
    const enrichedBookings = await Promise.all(
      bookings.map(async (booking) => {
        if (!booking.teamID) {
          return { ...booking, teamName: null };
        }

        const team = await this.bookingRepository.findTeamById(booking.teamID);
        return {
          ...booking,
          teamName: team ? team.teamName : null,
        };
      })
    );

    return enrichedBookings;
  }
}

