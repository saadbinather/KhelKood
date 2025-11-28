/**
 * Standardized Response Utility
 * Single Responsibility: Handle all API responses consistently
 */

export const sendSuccess = (res, statusCode = 200, message, data = null) => {
  const response = { message };
  if (data !== null) {
    response.data = data;
  }
  return res.status(statusCode).json(response);
};

export const sendError = (res, statusCode = 500, error) => {
  return res.status(statusCode).json({ error });
};

export const sendValidationError = (res, message) => {
  return sendError(res, 400, message);
};

export const sendNotFoundError = (res, resource) => {
  return sendError(res, 404, `${resource} not found`);
};

export const sendUnauthorizedError = (res, message = "Unauthorized") => {
  return sendError(res, 403, message);
};
