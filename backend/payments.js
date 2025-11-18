import express from "express";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 💳 Create Payment with Pending Status
router.post("/create-payment", verifyToken(["team"]), async (req, res) => {
  try {
    const { amount, bookingID } = req.body;
    const teamID = req.user.uid; // logged-in team UID

    // 🔹 Validation
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: "Valid amount is required" });
    }

    if (!bookingID || bookingID.trim() === "") {
      return res.status(400).json({ error: "bookingID is required" });
    }

    // 🔹 Optional: Verify booking exists
    const bookingRef = db.collection("bookings").doc(bookingID);
    const bookingDoc = await bookingRef.get();
    
    if (!bookingDoc.exists) {
      return res.status(404).json({ error: "Booking not found" });
    }

    // 🔹 Create payment data
    const paymentData = {
      amount: Number(amount),
      bookingID: bookingID.trim(),
      status: false, // false = payment pending
      teamID: teamID,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // 🔹 Save to Firestore
    const paymentRef = await db.collection("payments").add(paymentData);

    res.status(201).json({
      message: "Payment created successfully ✅",
      paymentID: paymentRef.id,
      payment: paymentData,
    });
  } catch (error) {
    console.error("❌ Error creating payment:", error);
    res.status(500).json({
      error: error.message,
    });
  }
});

// 💳 Update Payment Status to Paid
router.put("/update-payment/:paymentID", verifyToken(["team", "courtowner"]), async (req, res) => {
  try {
    const { paymentID } = req.params;
    const userID = req.user.uid; // logged-in user UID (team or courtowner)

    // 🔹 Validation
    if (!paymentID || paymentID.trim() === "") {
      return res.status(400).json({ error: "paymentID is required" });
    }

    // 🔹 Verify payment exists
    const paymentRef = db.collection("payments").doc(paymentID);
    const paymentDoc = await paymentRef.get();
    
    if (!paymentDoc.exists) {
      return res.status(404).json({ error: "Payment not found" });
    }

    const paymentData = paymentDoc.data();

    // 🔹 Optional: Check if user is authorized to update this payment
    // Team can only update their own payments, courtowner can update any payment for their court
    if (req.user.role === "team" && paymentData.teamID !== userID) {
      return res.status(403).json({ 
        error: "Unauthorized - You can only update your own payments" 
      });
    }

    // 🔹 Check if payment is already paid
    if (paymentData.status === true) {
      return res.status(400).json({ 
        error: "Payment is already completed",
        payment: paymentData
      });
    }

    // 🔹 Update payment data - ONLY status and updatedAt
    const updateData = {
      status: true, // true = payment completed
      updatedAt: new Date(),
    };

    // 🔹 Update in Firestore
    await paymentRef.update(updateData);

    // 🔹 Get updated payment data
    const updatedPaymentDoc = await paymentRef.get();
    const updatedPayment = {
      id: updatedPaymentDoc.id,
      ...updatedPaymentDoc.data()
    };

    res.status(200).json({
      message: "Payment status updated to paid successfully ✅",
      payment: updatedPayment,
    });
  } catch (error) {
    console.error("❌ Error updating payment status:", error);
    res.status(500).json({
      error: error.message,
    });
  }
});

export default router;