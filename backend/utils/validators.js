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

// Validate team phone number: 10 digits, optional dash after 4th digit
// Format: XXXX-XXXXXX or XXXXXXXXXX
export const validateTeamPhone = (phone) => {
  if (!phone) {
    return { isValid: false, error: "Phone number is required" };
  }
  
  // Check for invalid characters (only digits and one optional dash allowed)
  if (!/^[\d\-]+$/.test(phone)) {
    return { isValid: false, error: "Phone number can only contain digits and one optional dash" };
  }
  
  // Check format: XXXX-XXXXXX or XXXXXXXXXX (10 digits total)
  // Remove dash for validation
  const cleanedPhone = phone.replace(/-/g, '');
  
  // Must be exactly 10 digits
  if (!/^\d{10}$/.test(cleanedPhone)) {
    return { isValid: false, error: "Phone number must contain exactly 10 digits" };
  }
  
  // If dash is present, it must be after exactly 4 digits
  if (phone.includes('-')) {
    const parts = phone.split('-');
    if (parts.length !== 2 || parts[0].length !== 4 || parts[1].length !== 6) {
      return { isValid: false, error: "If using a dash, it must be after 4 digits (e.g., 1234-567890)" };
    }
  }
  
  return { isValid: true, cleanedPhone };
};

// Validate email format
export const validateEmail = (email) => {
  if (!email) {
    return { isValid: false, error: "Email is required" };
  }
  
  // Basic email regex
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  
  if (!emailRegex.test(email)) {
    return { isValid: false, error: "Invalid email format" };
  }
  
  return { isValid: true };
};

