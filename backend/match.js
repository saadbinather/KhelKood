// import express from "express";
// import axios from "axios";
// import { verifyToken } from "./middleware/verifyToken.js";
// import { db } from "./config/firebase.js";

// const router = express.Router();

// // 🏆 Create Match by calling the Challenge API
// router.post("/create", verifyToken(["team"]), async (req, res) => {
//   try {
//     const { challengeID } = req.body;
//     const teamID = req.user.uid; // logged-in team UID

//     // 🔹 Call your own GET challenge API
//     const baseURL = "http://localhost:5000/api"; // adjust if needed
//     const response = await axios.get(
//       `${baseURL}/challenges/challenge-details/${challengeID}`,
//       {
//         headers: { Authorization: `Bearer ${req.headers.authorization.split(" ")[1]}` }
//       }
//     );

//     const challengeData = response.data.challenge;

//     // 🔹 Optional: check that logged-in team is host
//     if (challengeData.hostTeamID !== teamID) {
//       return res.status(403).json({ error: "Unauthorized to create match for this challenge" });
//     }

//     // 🔹 Build match data
//     const matchData = {
//       Court_ID: challengeData.courtFirebaseUID,
//       Host_Team_ID: challengeData.hostTeamID,
//       Sport: challengeData.sport || "futsal",
//       StartTime: challengeData.stime,
//       EndTime: challengeData.etime,
//       TeamName: challengeData.teamName,
//       Challenge_ID: challengeID,
//       createdAt: new Date(),
//     };

//     // 🔹 Save to Firestore
//     const docRef = await db.collection("matches").add(matchData);

//     res.status(201).json({
//       message: "Match created successfully ✅",
//       matchID: docRef.id,
//       match: matchData,
//     });
//   } catch (error) {
//     res.status(500).json({ error: error.response?.data || error.message });
//   }
// });

// export default router;

import express from "express";
import axios from "axios";
import { db } from "./config/firebase.js";
import { verifyToken } from "./middleware/verifyToken.js";

const router = express.Router();

// 🏆 Create Match + Booking + Payment
router.post("/create", verifyToken(["team"]), async (req, res) => {
  try {
    const { challengeID } = req.body;
    const teamID = req.user.uid; // logged-in team UID

    if (!challengeID) {
      return res.status(400).json({ error: "challengeID is required" });
    }

    // Get the authorization token
    const token = req.headers.authorization.split(" ")[1];
    const baseURL = "http://localhost:5000/api";

    // 🔹 1. Call your GET Challenge API
    const challengeResponse = await axios.get(
      `${baseURL}/challenges/challenge-details/${challengeID}`,
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    const challengeData = challengeResponse.data.challenge;
    if (!challengeData) {
      return res.status(404).json({ error: "Challenge not found" });
    }

    // 🔹 2. Ensure the logged-in team is the host
    if (challengeData.hostTeamID !== teamID) {
      return res
        .status(403)
        .json({ error: "Unauthorized to create match for this challenge" });
    }

    // 🔹 3. Common data
    const startTime = new Date(challengeData.stime);
    const endTime = new Date(challengeData.etime);
    const courtID = challengeData.courtFirebaseUID;
    const sportType = challengeData.sport || "futsal"; // Get sport type from challenge

    // 🔹 4. Get court details to fetch the price rates
    const courtDoc = await db.collection("courts").doc(courtID).get();
    if (!courtDoc.exists) {
      return res.status(404).json({ error: "Court not found" });
    }

    const courtData = courtDoc.data();

    // 🔹 5. Calculate amount based on sport type and duration
    const durationHours = (endTime - startTime) / (1000 * 60 * 60); // Convert ms to hours

    let hourlyRate;
    switch (sportType.toLowerCase()) {
      case "cricket":
        hourlyRate = courtData.cricketRate || 1800;
        break;
      case "futsal":
        hourlyRate = courtData.futsalRate || 2000;
        break;
      case "padel":
        hourlyRate = courtData.padelRate || 3500;
        break;
      default:
        hourlyRate = courtData.futsalRate || 2000; // Default to futsal rate
    }

    const totalAmount = Math.round(durationHours * hourlyRate);

    // 🔹 6. Create Booking by calling the book-court API
    const bookingResponse = await axios.post(
      `${baseURL}/booking/book-court`,
      {
        courtID,
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      },
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    const bookingData = bookingResponse.data;
    const bookingID = bookingData.bookingID;

    // 🔹 7. Create Payment by calling the create-payment API
    const paymentResponse = await axios.post(
      `${baseURL}/payments/create-payment`,
      {
        amount: totalAmount,
        bookingID: bookingID,
      },
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    const paymentData = paymentResponse.data;
    const paymentID = paymentData.paymentID;

    // 🔹 8. Create Match (with Winner = null)
    const matchData = {
      Court_ID: courtID,
      Host_Team_ID: teamID,
      Sport: sportType,
      StartTime: startTime,
      EndTime: endTime,
       matchType: "competitive", 
      TeamName: challengeData.teamName,
      Challenge_ID: challengeID,
      Booking_ID: bookingID,
      Payment_ID: paymentID, // Add payment reference to match
      Winner: null, // initially empty
      createdAt: new Date(),
    };

    const matchRef = await db.collection("matches").add(matchData);

    // 🔹 9. Return success response
    res.status(201).json({
      message: "Match, booking and payment created successfully ✅",
      matchID: matchRef.id,
      bookingID: bookingID,
      paymentID: paymentID,
      match: matchData,
      booking: bookingData.booking,
      payment: paymentData.payment,
      pricingDetails: {
        sportType: sportType,
        hourlyRate: hourlyRate,
        durationHours: parseFloat(durationHours.toFixed(2)),
        totalAmount: totalAmount,
      },
    });
  } catch (error) {
    console.error("❌ Error creating match, booking and payment:", error);
    res.status(500).json({
      error: error.response?.data || error.message,
    });
  }
});


// 🏆 Create Friendly Match + Booking + Payment
router.post("/create-friendly", verifyToken(["team"]), async (req, res) => {
  try {
    const { 
      courtID, 
      sport, 
      startTime, 
      endTime, 
      teamName 
    } = req.body;
    
    const teamID = req.user.uid; // logged-in team UID

    // 🔹 Validation
    if (!courtID || !sport || !startTime || !endTime || !teamName) {
      return res.status(400).json({ 
        error: "courtID, sport, startTime, endTime and teamName are required" 
      });
    }

    // Get the authorization token
    const token = req.headers.authorization.split(" ")[1];
    const baseURL = "http://localhost:5000/api";

    // 🔹 1. Get court details to fetch the price rates
    const courtDoc = await db.collection("courts").doc(courtID).get();
    if (!courtDoc.exists) {
      return res.status(404).json({ error: "Court not found" });
    }

    const courtData = courtDoc.data();

    // 🔹 2. Parse times
    const startTimeDate = new Date(startTime);
    const endTimeDate = new Date(endTime);

    // 🔹 3. Calculate amount based on sport type and duration
    const durationHours = (endTimeDate - startTimeDate) / (1000 * 60 * 60); // Convert ms to hours

    let hourlyRate;
    switch (sport.toLowerCase()) {
      case "cricket":
        hourlyRate = courtData.cricketRate || 1800;
        break;
      case "futsal":
        hourlyRate = courtData.futsalRate || 2000;
        break;
      case "padel":
        hourlyRate = courtData.padelRate || 3500;
        break;
      default:
        hourlyRate = courtData.futsalRate || 2000; // Default to futsal rate
    }

    const totalAmount = Math.round(durationHours * hourlyRate);

    // 🔹 4. Create Booking by calling the book-court API
    const bookingResponse = await axios.post(
      `${baseURL}/booking/book-court`,
      {
        courtID,
        startTime: startTimeDate.toISOString(),
        endTime: endTimeDate.toISOString(),
      },
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    const bookingData = bookingResponse.data;
    const bookingID = bookingData.bookingID;

    // 🔹 5. Create Payment by calling the create-payment API
    const paymentResponse = await axios.post(
      `${baseURL}/payments/create-payment`,
      {
        amount: totalAmount,
        bookingID: bookingID,
      },
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );

    const paymentData = paymentResponse.data;
    const paymentID = paymentData.paymentID;

    // 🔹 6. Create Friendly Match (with Winner = null)
    const matchData = {
      Court_ID: courtID,
      Host_Team_ID: teamID,
      Sport: sport,
      StartTime: startTimeDate,
      EndTime: endTimeDate,
      TeamName: teamName,
      matchType: "friendly", // Mark as friendly match
      Booking_ID: bookingID,
      Payment_ID: paymentID,
      Winner: null, // initially empty
      createdAt: new Date(),
    };

    const matchRef = await db.collection("matches").add(matchData);

    // 🔹 7. Return success response
    res.status(201).json({
      message: "Friendly match, booking and payment created successfully ✅",
      matchID: matchRef.id,
      bookingID: bookingID,
      paymentID: paymentID,
      match: matchData,
      booking: bookingData.booking,
      payment: paymentData.payment,
      pricingDetails: {
        sportType: sport,
        hourlyRate: hourlyRate,
        durationHours: parseFloat(durationHours.toFixed(2)),
        totalAmount: totalAmount,
      },
    });
  } catch (error) {
    console.error("❌ Error creating friendly match, booking and payment:", error);
    res.status(500).json({
      error: error.response?.data || error.message,
    });
  }
});


export default router;
