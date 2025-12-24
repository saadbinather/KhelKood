import express from "express";
import { admin, db } from "../config/firebase.js";
import { verifyToken } from "../middleware/verifyToken.js";
import { sendSuccess, sendError, sendValidationError, sendNotFoundError } from "../utils/response.js";
import { validateRequired } from "../utils/validators.js";
import EmailService from "../utils/emailService.js";

const router = express.Router();

// ==================== REPOSITORY LAYER (Data Access) ====================
// Single Responsibility: Handle all database operations for admin

const AdminRepository = {
  async findUserById(userDocId) {
    const userRef = db.collection("users").doc(userDocId);
    const userDoc = await userRef.get();
    return userDoc.exists ? { id: userDoc.id, ...userDoc.data() } : null;
  },

  async findTeamByUserId(userDocId) {
    const teamRef = db.collection("teams").doc(userDocId);
    const teamDoc = await teamRef.get();
    return teamDoc.exists ? { id: teamDoc.id, ...teamDoc.data() } : null;
  },

  async findCourtownerByUserId(userDocId) {
    const courtownerRef = db.collection("courtowners").doc(userDocId);
    const courtownerDoc = await courtownerRef.get();
    return courtownerDoc.exists ? { id: courtownerDoc.id, ...courtownerDoc.data() } : null;
  },

  async createTeamIfMissing(userDocId, userData) {
    const existingTeam = await this.findTeamByUserId(userDocId);
    if (!existingTeam && userData.role === "team") {
      // Team doesn't exist, create it with basic data
      // Note: This is a fallback - ideally team should be created during signup
      const teamData = {
        userId: userDocId,
        email: userData.email || "",
        phone: "",
        teamName: userData.name || "Unknown Team",
        sports: "",
        players: [],
        createdAt: new Date(),
        points: 0,
      };
      await db.collection("teams").doc(userDocId).set(teamData);
      return teamData;
    }
    return existingTeam;
  },

  async createCourtownerIfMissing(userDocId, userData) {
    const existingCourtowner = await this.findCourtownerByUserId(userDocId);
    if (!existingCourtowner && userData.role === "courtowner") {
      // Courtowner doesn't exist, create it with data from signup or defaults
      const signupData = userData.signupData || {};
      // Note: Location is NOT stored in courtowner - it's only in court table
      const courtownerData = {
        userId: userDocId,
        name: userData.name || "",
        email: userData.email || "",
        phone: signupData.phone || "",
        cnic: signupData.cnic || "",
        courtName: signupData.courtName || "",
        createdAt: new Date(),
      };
      await db.collection("courtowners").doc(userDocId).set(courtownerData);
      return courtownerData;
    }
    return existingCourtowner;
  },

  async findCourtByOwnerId(ownerId) {
    const courtsRef = db.collection("courts");
    const snapshot = await courtsRef.where("courtownerID", "==", ownerId).limit(1).get();
    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      return { id: doc.id, ...doc.data() };
    }
    return null;
  },

  async createCourtIfMissing(ownerId, userData) {
    const existingCourt = await this.findCourtByOwnerId(ownerId);
    if (!existingCourt && userData.role === "courtowner") {
      // Court doesn't exist, create it with data from signup or defaults
      const signupData = userData.signupData || {};
      const courtData = {
        name: signupData.courtTitle || "Default Sports Arena",
        address: signupData.courtAddress || "Unknown Location",
        location: signupData.location || "",
        coordinates: (signupData.latitude != null && signupData.longitude != null)
          ? {
              latitude: Number(signupData.latitude),
              longitude: Number(signupData.longitude),
            }
          : null,
        courtownerID: ownerId,
        numOfCricketFields: signupData.numOfCricketFields || 0,
        numOfPadelCourts: signupData.numOfPadelCourts || 0,
        numOfFutsalFields: signupData.numOfFutsalFields || 0,
        cricketRate: signupData.cricketRate || 0,
        futsalRate: signupData.futsalRate || 0,
        padelRate: signupData.padelRate || 0,
        rating: signupData.rating || 0,
        openingTime: signupData.openingTime || 8,
        closingTime: signupData.closingTime || 23,
        createdAt: new Date(),
      };
      const docRef = await db.collection("courts").add(courtData);
      return { id: docRef.id, ...courtData };
    }
    return existingCourt;
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

    // Ensure role-specific documents exist (fallback if not created during signup)
    if (user.role === "team") {
      await AdminRepository.createTeamIfMissing(userDocId.trim(), user);
    } else if (user.role === "courtowner") {
      await AdminRepository.createCourtownerIfMissing(userDocId.trim(), user);
      await AdminRepository.createCourtIfMissing(userDocId.trim(), user);
    }

    // Update verification status
    const updatedUser = await AdminRepository.updateUserStatus(
      userDocId.trim(),
      "verified"
    );

    // Log verification
    await AdminRepository.logVerificationAction(userDocId.trim(), user, "Verified");

    // Send email notification to user when verified
    try {
      // For court owners, use the existing detailed notification
      if (user.role === "courtowner") {
        const courtowner = await AdminRepository.findCourtownerByUserId(userDocId.trim());
        const court = await AdminRepository.findCourtByOwnerId(userDocId.trim());
        
        await EmailService.notifyCourtOwnerOnVerification({
          name: user.name || courtowner?.name || "",
          email: user.email || courtowner?.email || "",
          courtName: courtowner?.courtName || "",
          courtTitle: court?.name || user.signupData?.courtTitle || "",
        });
      } else {
        // For teams and other roles, use generic acceptance notification
        await EmailService.notifyUserOnAcceptance({
          email: user.email || "",
          name: user.name || "",
          role: user.role || "",
        });
      }
    } catch (error) {
      console.error("Error sending verification notification email:", error);
      // Don't throw - email failure shouldn't break verification
    }

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

    // Send rejection email to user before deleting
    try {
      await EmailService.notifyUserOnRejection({
        email: user.email || "",
        name: user.name || "",
        role: user.role || "",
        reason: reason,
      });
    } catch (error) {
      console.error("Error sending rejection notification email:", error);
      // Continue with deletion even if email fails
    }

    // Delete user from database (and related documents)
    try {
      // Delete user document
      await db.collection("users").doc(userDocId.trim()).delete();

      // Delete role-specific documents
      if (user.role === "team") {
        await db.collection("teams").doc(userDocId.trim()).delete();
        // Delete associated players
        const playersSnapshot = await db.collection("players")
          .where("teamID", "==", userDocId.trim())
          .get();
        const batch = db.batch();
        playersSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      } else if (user.role === "courtowner") {
        await db.collection("courtowners").doc(userDocId.trim()).delete();
        // Delete associated courts
        const courtsSnapshot = await db.collection("courts")
          .where("courtownerID", "==", userDocId.trim())
          .get();
        const batch = db.batch();
        courtsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }

      // Also delete from Firebase Auth
      try {
        await admin.auth().deleteUser(userDocId.trim());
      } catch (authError) {
        console.error("Error deleting user from Firebase Auth:", authError);
        // Continue even if Auth deletion fails
      }
    } catch (deleteError) {
      console.error("Error deleting user from database:", deleteError);
      throw new Error("Failed to delete user from database");
    }

    // Log rejection action
    await AdminRepository.logVerificationAction(
      userDocId.trim(),
      user,
      "Rejected",
      { reason }
    );

    return { ...user, status: "rejected", deleted: true };
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

