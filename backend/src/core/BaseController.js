/**
 * BaseController - Abstract Base Class for Request Handling Layer
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only HTTP request/response logic
 * 2. Dependency Inversion: Depends on service abstraction
 * 3. Open/Closed: Open for extension, closed for modification
 */

import {
  sendSuccess,
  sendError,
  sendValidationError,
  sendNotFoundError,
  sendUnauthorizedError,
} from "../../utils/response.js";

export class BaseController {
  constructor(service) {
    if (new.target === BaseController) {
      throw new Error("Cannot instantiate abstract class BaseController");
    }
    this.service = service;
  }

  /**
   * Handle successful response
   * @param {Object} res - Express response object
   * @param {number} statusCode - HTTP status code
   * @param {string} message - Success message
   * @param {Object} data - Response data
   */
  handleSuccess(res, statusCode, message, data) {
    return sendSuccess(res, statusCode, message, data);
  }

  /**
   * Handle error response
   * @param {Object} res - Express response object
   * @param {Error} error - Error object
   * @param {string} context - Context of the error
   */
  handleError(res, error, context = '') {
    console.error(`${context} Error:`, error);

    // Validation errors
    if (error.message.includes('required') || 
        error.message.includes('Invalid') ||
        error.message.includes('must be')) {
      return sendValidationError(res, error.message);
    }

    // Not found errors
    if (error.message.includes('not found') || 
        error.message.includes('does not exist')) {
      return sendNotFoundError(res, this.extractEntityName(error.message));
    }

    // Unauthorized errors
    if (error.message.includes('Unauthorized') || 
        error.message.includes('do not own') ||
        error.message.includes('permission')) {
      return sendUnauthorizedError(res, error.message);
    }

    // Generic server error
    return sendError(res, 500, error.message);
  }

  /**
   * Extract entity name from error message
   * @param {string} message - Error message
   * @returns {string} Entity name
   */
  extractEntityName(message) {
    const match = message.match(/(\w+)\s+not found/i);
    return match ? match[1] : 'Resource';
  }

  /**
   * Extract user ID from request
   * @param {Object} req - Express request object
   * @returns {string} User ID
   */
  getUserId(req) {
    return req.user?.uid;
  }

  /**
   * Extract token from request headers
   * @param {Object} req - Express request object
   * @returns {string} Token
   */
  getToken(req) {
    return req.headers.authorization?.replace("Bearer ", "");
  }

  /**
   * Async route handler wrapper
   * @param {Function} fn - Async function to wrap
   * @returns {Function} Express middleware
   */
  asyncHandler(fn) {
    return (req, res, next) => {
      Promise.resolve(fn(req, res, next)).catch(next);
    };
  }
}

