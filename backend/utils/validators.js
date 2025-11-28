/**
 * Validation Utility
 * Single Responsibility: Validate input data
 */

export const validateRequired = (data, fields) => {
  const missing = fields.filter(field => !data[field]);
  if (missing.length > 0) {
    return { isValid: false, error: `${missing.join(", ")} ${missing.length === 1 ? 'is' : 'are'} required` };
  }
  return { isValid: true };
};

export const validatePositiveNumber = (value, fieldName) => {
  if (!value || value <= 0) {
    return { isValid: false, error: `Valid ${fieldName} is required` };
  }
  return { isValid: true };
};

export const validateDateRange = (startTime, endTime) => {
  const start = new Date(startTime);
  const end = new Date(endTime);
  
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return { isValid: false, error: "Invalid date format" };
  }
  
  if (start >= end) {
    return { isValid: false, error: "End time must be after start time" };
  }
  
  return { isValid: true };
};

