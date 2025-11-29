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

const ReviewsRepository = {
  async findCourtById(courtID) {
    const courtRef = db.collection("courts").doc(courtID);
    const courtDoc = await courtRef.get();
    return courtDoc.exists ? { id: courtDoc.id, ...courtDoc.data() } : null;
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

  async create(reviewData) {
    const docRef = await db.collection("reviews").add(reviewData);
    return { id: docRef.id, ...reviewData };
  },

  async findByCourtId(courtID) {
    try {
      // Try with orderBy first
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("courtID", "==", courtID)
        .orderBy("createdAt", "desc")
        .get();

      const reviews = reviewsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      console.log(`Found ${reviews.length} reviews for court ${courtID}`);
      return reviews;
    } catch (error) {
      // If orderBy fails (likely due to missing index), try without it
      console.log(`OrderBy failed, trying without orderBy: ${error.message}`);
      const reviewsSnapshot = await db
        .collection("reviews")
        .where("courtID", "==", courtID)
        .get();

      const reviews = reviewsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Sort manually by createdAt
      reviews.sort((a, b) => {
        const dateA = a.createdAt?.toDate
          ? a.createdAt.toDate()
          : new Date(a.createdAt);
        const dateB = b.createdAt?.toDate
          ? b.createdAt.toDate()
          : new Date(b.createdAt);
        return dateB.getTime() - dateA.getTime();
      });

      console.log(
        `Found ${reviews.length} reviews for court ${courtID} (without orderBy)`
      );
      return reviews;
    }
  },

  async updateCourtRating(courtID, newRating) {
    const courtRef = db.collection("courts").doc(courtID);
    await courtRef.update({ rating: newRating });
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================

const ReviewsService = {
  async addReview(courtID, userId, rating, comment) {
    // Validate court exists
    const court = await ReviewsRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    // Get team info
    const team = await ReviewsRepository.findTeamByUserId(userId);
    if (!team) {
      throw new Error("Team not found");
    }

    // Create review
    const reviewData = {
      courtID,
      teamID: team.id,
      teamName: team.teamName || "Unknown Team",
      userId,
      rating: Number(rating),
      comment: comment || "",
      createdAt: new Date(),
    };

    const review = await ReviewsRepository.create(reviewData);
    console.log(`Review created: ${JSON.stringify(review)}`);

    // Update court rating
    const oldRating = court.rating || 0;
    let newCourtRating;
    if (oldRating === 0) {
      // If no previous rating, just use the new rating
      newCourtRating = Number(rating);
    } else {
      // Otherwise, average: (oldRating + newRating) / 2
      newCourtRating = (oldRating + Number(rating)) / 2;
    }
    await ReviewsRepository.updateCourtRating(courtID, newCourtRating);

    return {
      review,
      updatedCourtRating: newCourtRating,
    };
  },

  async getCourtReviews(courtID) {
    // Validate court exists
    const court = await ReviewsRepository.findCourtById(courtID);
    if (!court) {
      throw new Error("Court not found");
    }

    console.log(`Fetching reviews for court: ${courtID}`);
    const reviews = await ReviewsRepository.findByCourtId(courtID);
    console.log(`Retrieved ${reviews.length} reviews for court ${courtID}`);
    return reviews;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================

const ReviewsController = {
  async addReview(req, res) {
    try {
      const { courtID, rating, comment } = req.body;
      const userId = req.user.uid;

      // Validation
      const validation = validateRequired({ courtID, rating }, [
        "courtID",
        "rating",
      ]);
      if (!validation.isValid) {
        return sendValidationError(res, validation.error);
      }

      if (rating < 1 || rating > 10) {
        return sendValidationError(res, "Rating must be between 1 and 10");
      }

      const result = await ReviewsService.addReview(
        courtID,
        userId,
        rating,
        comment
      );

      return sendSuccess(res, 201, "Review added successfully ✅", result);
    } catch (error) {
      return sendError(res, 500, error.message);
    }
  },

  async getCourtReviews(req, res) {
    try {
      const { courtID } = req.params;

      if (!courtID) {
        return sendValidationError(res, "Court ID is required");
      }

      const reviews = await ReviewsService.getCourtReviews(courtID);

      return sendSuccess(res, 200, "Reviews fetched successfully ✅", {
        count: reviews.length,
        reviews,
      });
    } catch (error) {
      if (error.message === "Court not found") {
        return sendNotFoundError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================

router.post("/", verifyToken(["team"]), ReviewsController.addReview);

router.get(
  "/court/:courtID",
  verifyToken(["team", "courtowner", "admin"]),
  ReviewsController.getCourtReviews
);

export default router;
