/**
 * BaseService - Abstract Base Class for Business Logic Layer
 * 
 * SOLID Principles Applied:
 * 1. Single Responsibility: Handles only business logic
 * 2. Dependency Inversion: Depends on repository abstraction, not concrete implementation
 * 3. Open/Closed: Open for extension, closed for modification
 */

export class BaseService {
  constructor(repository) {
    if (new.target === BaseService) {
      throw new Error("Cannot instantiate abstract class BaseService");
    }
    this.repository = repository;
  }

  /**
   * Validate required fields
   * @param {Object} data - Data to validate
   * @param {Array<string>} requiredFields - Required field names
   * @throws {Error} If validation fails
   */
  validateRequired(data, requiredFields) {
    const missingFields = requiredFields.filter(field => !data[field]);
    if (missingFields.length > 0) {
      throw new Error(`Missing required fields: ${missingFields.join(', ')}`);
    }
  }

  /**
   * Validate date range
   * @param {Date|string} startTime - Start time
   * @param {Date|string} endTime - End time
   * @throws {Error} If validation fails
   */
  validateDateRange(startTime, endTime) {
    const start = new Date(startTime);
    const end = new Date(endTime);

    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new Error("Invalid date format");
    }

    if (end <= start) {
      throw new Error("End time must be after start time");
    }

    if (start < new Date()) {
      throw new Error("Start time must be in the future");
    }
  }

  /**
   * Validate positive number
   * @param {number} value - Value to validate
   * @param {string} fieldName - Field name for error message
   * @throws {Error} If validation fails
   */
  validatePositiveNumber(value, fieldName) {
    if (typeof value !== 'number' || value <= 0) {
      throw new Error(`${fieldName} must be a positive number`);
    }
  }

  /**
   * Handle service errors with appropriate error messages
   * @param {Error} error - Error object
   * @param {string} context - Context of the error
   * @throws {Error} Formatted error
   */
  handleError(error, context) {
    throw new Error(`${context}: ${error.message}`);
  }
}

