import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError } from "./utils/response.js";
import { validateRequired } from "./utils/validators.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for admin

const AdminRepository = {
  async findUserById(userDocId) {
    const userRef = db.collection("users").doc(userDocId);
    const userDoc = await userRef.get();
    return userDoc.exists ? { id: userDoc.id, ...userDoc.data() } : null;
  },

  async updateUserVerification(userDocId) {
    const userRef = db.collection("users").doc(userDocId);
    await userRef.update({ verificationStatus: "verified" });
    return await this.findUserById(userDocId);
  },

  async logVerification(userDocId, userData) {
    await db.collection("verifications").add({
      User_ID: userDocId,
      Name: userData.name || "Unknown",
      Email: userData.email || "Unknown",
      Status: "Verified",
      Created_At: new Date().toISOString(),
    });
  },
};

// ==================== SERVICE LAYER (Business Logic) ====================
// Single Responsibility: Handle admin business rules

const AdminService = {
  async verifyUser(userDocId) {
    // Validation
    const validation = validateRequired({ userDocId }, ["userDocId"]);
    if (!validation.isValid) {
      throw new Error("Missing userDocId");
    }

    // Find user
    const user = await AdminRepository.findUserById(userDocId.trim());
    if (!user) {
      throw new Error("User not found in Firestore");
    }

    // Update verification status
    const updatedUser = await AdminRepository.updateUserVerification(userDocId.trim());

    // Log verification
    await AdminRepository.logVerification(userDocId.trim(), user);

    return updatedUser;
  },
};

// ==================== CONTROLLER LAYER (Request Handling) ====================
// Single Responsibility: Handle HTTP requests and responses

const AdminController = {
  async verifyUser(req, res) {
    try {
      const { userDocId } = req.body;
      const user = await AdminService.verifyUser(userDocId);
      
      return sendSuccess(res, 200, "✅ User verified successfully", {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
        },
      });
    } catch (error) {
      if (error.message === "User not found in Firestore") {
        return sendNotFoundError(res, "User");
      }
      if (error.message.includes("Missing")) {
        return sendValidationError(res, error.message);
      }
      return sendError(res, 500, error.message);
    }
  },
};

// ==================== ROUTES ====================
router.post("/verify-user", verifyToken(["admin"]), AdminController.verifyUser);

export default router;
