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

  async updateUserStatus(userDocId, status) {
    const userRef = db.collection("users").doc(userDocId);
    await userRef.update({ verificationStatus: status, updatedAt: new Date() });
    return await this.findUserById(userDocId);
  },

  async logVerificationAction(userDocId, userData, status, details = {}) {
    await db.collection("verifications").add({
      User_ID: userDocId,
      Name: userData.name || "Unknown",
      Email: userData.email || "Unknown",
      Status: status,
      Details: details.reason || null,
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
    const updatedUser = await AdminRepository.updateUserStatus(
      userDocId.trim(),
      "verified"
    );

    // Log verification
    await AdminRepository.logVerificationAction(userDocId.trim(), user, "Verified");

    return updatedUser;
  },

  async rejectUser(userDocId, reason = "Rejected by admin") {
    const validation = validateRequired({ userDocId }, ["userDocId"]);
    if (!validation.isValid) {
      throw new Error("Missing userDocId");
    }

    const user = await AdminRepository.findUserById(userDocId.trim());
    if (!user) {
      throw new Error("User not found in Firestore");
    }

    const updatedUser = await AdminRepository.updateUserStatus(
      userDocId.trim(),
      "rejected"
    );

    await AdminRepository.logVerificationAction(
      userDocId.trim(),
      user,
      "Rejected",
      { reason }
    );

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

  async rejectUser(req, res) {
    try {
      const { userDocId, reason } = req.body;
      const user = await AdminService.rejectUser(userDocId, reason);

      return sendSuccess(res, 200, "❌ User rejected successfully", {
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          status: "rejected",
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
router.post("/reject-user", verifyToken(["admin"]), AdminController.rejectUser);

export default router;
