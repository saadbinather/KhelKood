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

  async findByCourtId(courtID, courtNum = null) {
    let query = db.collection("bookings").where("courtID", "==", courtID);

    if (courtNum !== null) {
      query = query.where("courtNum", "==", courtNum);
    }

    const bookingsSnapshot = await query.get();

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

  async update(bookingID, updateData) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    await bookingRef.update({
      ...updateData,
      updatedAt: new Date(),
    });
    return await this.findById(bookingID);
  },

  async findById(bookingID) {
    const bookingRef = db.collection("bookings").doc(bookingID);
    const bookingDoc = await bookingRef.get();
    return bookingDoc.exists
      ? { id: bookingDoc.id, ...bookingDoc.data() }
      : null;
  },

  async findByTeamId(teamID) {
    try {
      const bookingsSnapshot = await db
        .collection("bookings")
        .where("teamID", "==", teamID)
        .orderBy("startTime", "desc")
        .get();

      return bookingsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (error) {
      // If orderBy fails (e.g., missing index), fetch without orderBy and sort in memory
      if (error.message && error.message.includes("index")) {
        const bookingsSnapshot = await db
          .collection("bookings")
          .where("teamID", "==", teamID)
          .get();

        const bookings = bookingsSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        // Sort by startTime descending
        bookings.sort((a, b) => {
          const aTime = a.startTime?.toDate
            ? a.startTime.toDate().getTime()
            : new Date(a.startTime).getTime();
          const bTime = b.startTime?.toDate
            ? b.startTime.toDate().getTime()
            : new Date(b.startTime).getTime();
          return bTime - aTime;
        });

        return bookings;
      }
      throw error;
    }
  },

  async findMatchById(matchID) {
    const matchRef = db.collection("matches").doc(matchID);
    const matchDoc = await matchRef.get();
    return matchDoc.exists ? { id: matchDoc.id, ...matchDoc.data() } : null;
  },

  async findTeamById(teamID) {
    const teamRef = db.collection("teams").doc(teamID);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },

  async findMatchesByTeamId(teamID) {
    // Find matches where team is either host or guest
    const matchesSnapshot = await db.collection("matches").get();

    const matches = matchesSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter(
        (match) =>
          match.Host_Team_ID === teamID || match.Guest_Team_ID === teamID
      );

    // Sort by StartTime descending
    matches.sort((a, b) => {
      const aTime = a.StartTime?.toDate
        ? a.StartTime.toDate().getTime()
        : new Date(a.StartTime).getTime();
      const bTime = b.StartTime?.toDate
        ? b.StartTime.toDate().getTime()
        : new Date(b.StartTime).getTime();
      return bTime - aTime;
    });

    return matches;
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

  async createBooking(
    teamID,
    { courtID, startTime, endTime, courtNum, skipPayment },
    token
  ) {
    // Validation
    const validation = validateRequired(
      { courtID, startTime, endTime, courtNum },
      ["courtID", "startTime", "endTime", "courtNum"]
    );
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
      courtNum: parseInt(courtNum),
      sportType,
      startTime: startTimeDate,
      endTime: endTimeDate,
      createdAt: new Date(),
    };

    // Save booking
    const booking = await BookingRepository.create(bookingData);

    // Create payment for friendly booking (skip if skipPayment is true - e.g., when called from match creation)
    let paymentID = null;
    if (!skipPayment && token && pricing.totalAmount > 0) {
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

  async markCourtUnavailable(
    courtOwnerID,
    { courtID, startTime, endTime, courtNum }
  ) {
    // Validation
    const validation = validateRequired(
      { courtID, startTime, endTime, courtNum },
      ["courtID", "startTime", "endTime", "courtNum"]
    );
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    const dateValidation = validateDateRange(startTime, endTime);
    if (!dateValidation.isValid) {
      throw new Error(dateValidation.error);
    }

    // Check if court exists and verify ownership
    const court = await BookingRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    if (court.courtownerID !== courtOwnerID) {
      throw new Error("Unauthorized: You do not own this court");
    }

    // Create unavailable booking data (no teamID, no payment)
    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);

    const bookingData = {
      courtID,
      courtNum: parseInt(courtNum),
      startTime: startTimeDate,
      endTime: endTimeDate,
      isUnavailable: true,
      createdAt: new Date(),
    };

    // Save booking (no payment created)
    const booking = await BookingRepository.create(bookingData);

    return {
      booking,
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
      const courtNum = req.query.courtNum ? parseInt(req.query.courtNum) : null;
      const bookings = await BookingRepository.findByCourtId(courtID, courtNum);

      return sendSuccess(res, 200, "Court bookings fetched successfully ✅", {
        bookings,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async markUnavailable(req, res) {
    try {
      const courtOwnerID = req.user.uid;
      const result = await BookingService.markCourtUnavailable(
        courtOwnerID,
        req.body
      );

      return sendSuccess(
        res,
        201,
        "Court marked as unavailable successfully ✅",
        {
          bookingID: result.booking.id,
          booking: result.booking,
        }
      );
    } catch (error) {
      if (
        error.message === "Court not found" ||
        error.message.includes("Unauthorized")
      ) {
        return sendError(res, 403, error.message);
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

  async getBookingHistory(req, res) {
    try {
      const teamID = req.user.uid;

      // Get all bookings for this team (friendly bookings and matches where this team made the booking)
      const bookings = await BookingRepository.findByTeamId(teamID);

      // Get all matches where this team participated (as host or guest)
      const matches = await BookingRepository.findMatchesByTeamId(teamID);

      // Create a map to track which matches we've already processed from bookings
      const processedMatchIds = new Set();

      // Enrich bookings with court, match, and opponent information
      const enrichedBookings = await Promise.all(
        bookings.map(async (booking) => {
          // Get court information
          const court = await BookingRepository.findCourtById(booking.courtID);
          const courtName = court ? court.name : "Unknown Court";

          // Parse dates
          const startTime = booking.startTime?.toDate
            ? booking.startTime.toDate()
            : new Date(booking.startTime);
          const endTime = booking.endTime?.toDate
            ? booking.endTime.toDate()
            : new Date(booking.endTime);

          // Format date and time
          const date = startTime.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
          });
          const time = `${startTime.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
          })} - ${endTime.toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            hour12: true,
          })}`;

          let opponent = null;
          let status = null;
          let pointsEarned = 0;

          // If booking has a matchID, it's a competitive match
          if (booking.matchID) {
            processedMatchIds.add(booking.matchID);
            const match = await BookingRepository.findMatchById(
              booking.matchID
            );
            if (match) {
              // Determine opponent
              if (match.Host_Team_ID === teamID) {
                // Current team is host, opponent is guest
                if (match.Guest_Team_ID) {
                  const guestTeam = await BookingRepository.findTeamById(
                    match.Guest_Team_ID
                  );
                  opponent = guestTeam ? guestTeam.teamName : "Unknown Team";
                }
              } else if (match.Guest_Team_ID === teamID) {
                // Current team is guest, opponent is host
                if (match.Host_Team_ID) {
                  const hostTeam = await BookingRepository.findTeamById(
                    match.Host_Team_ID
                  );
                  opponent = hostTeam ? hostTeam.teamName : "Unknown Team";
                }
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
            // Friendly booking - no opponent, no status
            status = "Friendly";
          }

          return {
            id: booking.id,
            date,
            time,
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

      // Process matches that don't have a booking record for this team
      // (e.g., when host team created challenge but guest team made the booking)
      const matchBookings = await Promise.all(
        matches
          .filter((match) => !processedMatchIds.has(match.id))
          .map(async (match) => {
            // Get booking from match (Booking_ID field)
            let booking = null;
            if (match.Booking_ID) {
              booking = await BookingRepository.findById(match.Booking_ID);
            }

            // Get court information
            const court = await BookingRepository.findCourtById(match.Court_ID);
            const courtName = court ? court.name : "Unknown Court";

            // Parse dates from match
            const startTime = match.StartTime?.toDate
              ? match.StartTime.toDate()
              : new Date(match.StartTime);
            const endTime = match.EndTime?.toDate
              ? match.EndTime.toDate()
              : new Date(match.EndTime);

            // Format date and time
            const date = startTime.toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            });
            const time = `${startTime.toLocaleTimeString("en-US", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            })} - ${endTime.toLocaleTimeString("en-US", {
              hour: "numeric",
              minute: "2-digit",
              hour12: true,
            })}`;

            // Determine opponent
            let opponent = null;
            if (match.Host_Team_ID === teamID) {
              // Current team is host, opponent is guest
              if (match.Guest_Team_ID) {
                const guestTeam = await BookingRepository.findTeamById(
                  match.Guest_Team_ID
                );
                opponent = guestTeam ? guestTeam.teamName : "Unknown Team";
              }
            } else if (match.Guest_Team_ID === teamID) {
              // Current team is guest, opponent is host
              if (match.Host_Team_ID) {
                const hostTeam = await BookingRepository.findTeamById(
                  match.Host_Team_ID
                );
                opponent = hostTeam ? hostTeam.teamName : "Unknown Team";
              }
            }

            // Determine status based on winner
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
              id: booking ? booking.id : match.id, // Use booking ID if available, else match ID
              date,
              time,
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

      // Combine bookings and match bookings, then sort by startTime descending
      const allBookings = [...enrichedBookings, ...matchBookings];
      allBookings.sort((a, b) => {
        const aTime = new Date(a.startTime).getTime();
        const bTime = new Date(b.startTime).getTime();
        return bTime - aTime;
      });

      return sendSuccess(res, 200, "Booking history fetched successfully ✅", {
        bookings: allBookings,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post("/book-court", verifyToken(["team"]), BookingController.bookCourt);
router.post(
  "/mark-unavailable",
  verifyToken(["courtowner"]),
  BookingController.markUnavailable
);
router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  BookingController.getCourtBookings
);
router.get(
  "/history",
  verifyToken(["team"]),
  BookingController.getBookingHistory
);

export default router;
