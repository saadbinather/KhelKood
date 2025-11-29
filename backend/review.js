import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
} from "./utils/response.js";
import { validateRequired } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for reviews

const ReviewRepository = {
  async create(reviewData) {
    const docRef = await db.collection("reviews").add(reviewData);
    return { id: docRef.id, ...reviewData };
  },

  async findByCourtOwnerId(courtOwnerId) {
    const reviewsQuery = db
      .collection("reviews")
      .where("courtOwnerId", "==", courtOwnerId);
    const reviewsSnapshot = await reviewsQuery.get();
    return reviewsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
  },

  async findPlayerById(playerId) {
    const playerRef = db.collection("players").doc(playerId);
    const playerDoc = await playerRef.get();
    return playerDoc.exists ? { id: playerDoc.id, ...playerDoc.data() } : null;
  },

  async findTeamById(teamId) {
    const teamRef = db.collection("teams").doc(teamId);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle review business rules

const ReviewService = {
  async createReview({ playerId, courtOwnerId, rating, statement }) {
    // Validation
    const validation = validateRequired({ playerId, courtOwnerId, rating }, [
      "playerId",
      "courtOwnerId",
      "rating",
    ]);
    if (!validation.isValid) {
      throw new Error(validation.error);
    }

    if (typeof rating !== "number" || rating < 0 || rating > 5) {
      throw new Error("Rating must be a number between 0 and 5");
    }

    const reviewData = {
      playerId,
      courtOwnerId,
      rating,
      statement: statement || null,
      createdAt: new Date(),
    };

    return await ReviewRepository.create(reviewData);
  },

  async getReviewsForCourtOwner(courtOwnerId) {
    const reviews = await ReviewRepository.findByCourtOwnerId(courtOwnerId);

    // Enrich reviews with player and team information
    const enrichedReviews = await Promise.all(
      reviews.map(async (review) => {
        let teamName = "Unknown Team";
        let publishedAt = review.createdAt;

        // Get player info
        if (review.playerId) {
          const player = await ReviewRepository.findPlayerById(review.playerId);
          if (player && player.teamID) {
            // Get team info
            const team = await ReviewRepository.findTeamById(player.teamID);
            if (team) {
              teamName = team.teamName || team.name || "Unknown Team";
            }
          }
        }

        // Format date
        if (publishedAt && publishedAt.toDate) {
          publishedAt = publishedAt.toDate();
        } else if (publishedAt && publishedAt._seconds) {
          publishedAt = new Date(publishedAt._seconds * 1000);
        }

        return {
          teamName,
          rating: review.rating,
          comment: review.statement || null,
          publishedAt:
            publishedAt instanceof Date
              ? publishedAt.toISOString()
              : publishedAt,
        };
      })
    );

    return enrichedReviews;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const ReviewController = {
  async createReview(req, res) {
    try {
      const { playerId, courtOwnerId, rating, statement } = req.body;
      const review = await ReviewService.createReview({
        playerId,
        courtOwnerId,
        rating: Number(rating),
        statement,
      });
      return sendSuccess(res, 201, "Review posted successfully ✅", {
        reviewId: review.id,
        review,
      });
    } catch (error) {
      if (error.message.includes("required")) {
        return sendValidationError(res, error.message);
      }
      if (error.message.includes("Rating must be")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },

  async getReviews(req, res) {
    try {
      const courtOwnerId = req.user.uid;
      const reviews = await ReviewService.getReviewsForCourtOwner(courtOwnerId);
      return sendSuccess(res, 200, "Reviews fetched successfully ✅", {
        reviews,
      });
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================

router.post("/", ReviewController.createReview);
router.get("/", verifyToken(["courtowner"]), ReviewController.getReviews);

export default router;
