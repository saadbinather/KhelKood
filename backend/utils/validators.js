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

export const validatePhone = (phone) => {
  if (!phone) {
    return { isValid: false, error: "Phone number is required" };
  }
  
  // Remove spaces, dashes, and other formatting
  const cleanedPhone = phone.replace(/[\s\-\(\)]/g, '');
  
  // Pakistani phone number validation: 11 digits starting with 03
  // Format: 03XX-XXXXXXX or 03XXXXXXXXX
  const phoneRegex = /^03\d{9}$/;
  
  if (!phoneRegex.test(cleanedPhone)) {
    return { 
      isValid: false, 
      error: "Invalid phone number. Must be 11 digits starting with 03 (e.g., 03001234567)" 
    };
  }
  
  return { isValid: true };
};

export const validateCNIC = (cnic) => {
  if (!cnic) {
    return { isValid: false, error: "CNIC is required" };
  }
  
  // Remove spaces and dashes
  const cleanedCNIC = cnic.replace(/[\s\-]/g, '');
  
  // Pakistani CNIC validation: 13 digits
  // Format: XXXXX-XXXXXXX-X or XXXXXXXXXXXXX
  const cnicRegex = /^\d{13}$/;
  
  if (!cnicRegex.test(cleanedCNIC)) {
    return { 
      isValid: false, 
      error: "Invalid CNIC. Must be 13 digits (e.g., 12345-1234567-1)" 
    };
  }
  
  return { isValid: true };
};

