// Google Maps API Service - Backend proxy for secure API key usage
import axios from "axios";

/**
 * Reverse geocoding - Get address from coordinates
 * @param {number} lat - Latitude
 * @param {number} lng - Longitude
 * @returns {Promise<Object|null>} Google Geocoding API response
 */
export const getAddressFromCoords = async (lat, lng) => {
  try {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    
    if (!apiKey) {
      console.error("❌ GOOGLE_MAPS_API_KEY not set in .env");
      return null;
    }

    const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}&language=en`;
    
    const response = await axios.get(url);
    
    return response.data;
  } catch (error) {
    console.error("Google Geocoding API error:", error.message);
    return null;
  }
};

/**
 * Places Autocomplete - Search for places
 * @param {string} query - Search query
 * @param {string} country - Country code (default: 'pk' for Pakistan)
 * @returns {Promise<Object|null>} Google Places Autocomplete response
 */
export const searchPlaces = async (query, country = "pk") => {
  try {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    
    if (!apiKey) {
      console.error("❌ GOOGLE_MAPS_API_KEY not set in .env");
      return null;
    }

    const encodedQuery = encodeURIComponent(query);
    const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodedQuery}&key=${apiKey}&language=en&components=country:${country}`;
    
    const response = await axios.get(url);
    
    return response.data;
  } catch (error) {
    console.error("Google Places Autocomplete API error:", error.message);
    return null;
  }
};

/**
 * Place Details - Get details for a specific place
 * @param {string} placeId - Google Place ID
 * @param {string} fields - Comma-separated fields to return (default: 'geometry')
 * @returns {Promise<Object|null>} Google Place Details response
 */
export const getPlaceDetails = async (placeId, fields = "geometry") => {
  try {
    const apiKey = process.env.GOOGLE_MAPS_API_KEY;
    
    if (!apiKey) {
      console.error("❌ GOOGLE_MAPS_API_KEY not set in .env");
      return null;
    }

    const url = `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&key=${apiKey}&fields=${fields}`;
    
    const response = await axios.get(url);
    
    return response.data;
  } catch (error) {
    console.error("Google Place Details API error:", error.message);
    return null;
  }
};

