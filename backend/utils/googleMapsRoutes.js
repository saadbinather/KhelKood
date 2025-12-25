// Google Maps API Routes - Secure backend proxy
import express from "express";
import {
  getAddressFromCoords,
  searchPlaces,
  getPlaceDetails,
} from "./googleMapsService.js";
import { verifyToken } from "../middleware/verifyToken.js";

const router = express.Router();

/**
 * GET /api/google-maps/reverse-geocode
 * Get address from coordinates
 * Query params: lat, lng
 */
router.get("/reverse-geocode", verifyToken(["team", "courtowner", "admin"]), async (req, res) => {
  try {
    const { lat, lng } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: "Latitude and longitude are required",
      });
    }

    const latNum = parseFloat(lat);
    const lngNum = parseFloat(lng);

    if (isNaN(latNum) || isNaN(lngNum)) {
      return res.status(400).json({
        success: false,
        message: "Invalid latitude or longitude",
      });
    }

    const result = await getAddressFromCoords(latNum, lngNum);

    if (!result) {
      return res.status(500).json({
        success: false,
        message: "Failed to fetch address from Google API",
      });
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Reverse geocode error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

/**
 * GET /api/google-maps/places/autocomplete
 * Search for places
 * Query params: query, country (optional, default: 'pk')
 */
router.get("/places/autocomplete", verifyToken(["team", "courtowner", "admin"]), async (req, res) => {
  try {
    const { query, country = "pk" } = req.query;

    if (!query || query.trim() === "") {
      return res.status(400).json({
        success: false,
        message: "Search query is required",
      });
    }

    const result = await searchPlaces(query.trim(), country);

    if (!result) {
      return res.status(500).json({
        success: false,
        message: "Failed to search places from Google API",
      });
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Places autocomplete error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

/**
 * GET /api/google-maps/places/details
 * Get place details by place ID
 * Query params: placeId, fields (optional, default: 'geometry')
 */
router.get("/places/details", verifyToken(["team", "courtowner", "admin"]), async (req, res) => {
  try {
    const { placeId, fields = "geometry" } = req.query;

    if (!placeId || placeId.trim() === "") {
      return res.status(400).json({
        success: false,
        message: "Place ID is required",
      });
    }

    const result = await getPlaceDetails(placeId.trim(), fields);

    if (!result) {
      return res.status(500).json({
        success: false,
        message: "Failed to fetch place details from Google API",
      });
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Place details error:", error);
    res.status(500).json({
      success: false,
      message: "Internal server error",
    });
  }
});

export default router;

