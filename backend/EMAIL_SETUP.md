# Email Service Setup Guide

This guide explains how to configure the NodeMailer email service for KhelKood.

## Overview

The email service sends automated notifications for:
1. **Court Owner Registration**: Sends email to admin when a new court owner registers
2. **Court Owner Verification**: Sends email to court owner when admin verifies their account

## Configuration

### Step 1: Set Environment Variables

Create a `.env` file in the `backend` directory with the following variables:

```env
# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false

# Email credentials
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Primary Admin Email (will receive all court owner registration notifications)
ADMIN_EMAIL=alleeyyy9191@gmail.com
```

### Step 2: Gmail Setup (Recommended)

If using Gmail, you need to:

1. **Enable 2-Factor Authentication** on your Google account
2. **Generate an App Password**:
   - Go to [Google Account Settings](https://myaccount.google.com/)
   - Navigate to Security → 2-Step Verification → App passwords
   - Generate a new app password for "Mail"
   - Use this app password (not your regular password) as `SMTP_PASS`

### Step 3: Other Email Providers

You can use other email providers by changing the SMTP settings:

**Outlook/Hotmail:**
```env
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_SECURE=false
```

**Yahoo:**
```env
SMTP_HOST=smtp.mail.yahoo.com
SMTP_PORT=587
SMTP_SECURE=false
```

**Custom SMTP:**
```env
SMTP_HOST=your-smtp-server.com
SMTP_PORT=587
SMTP_SECURE=false
```

### Step 4: Load Environment Variables

Make sure your application loads the `.env` file. If using `dotenv`, add this at the top of `server.js`:

```javascript
import dotenv from "dotenv";
dotenv.config();
```

## How It Works

### Admin Notification (Registration)

When a court owner registers:
- Email is sent to all admin emails found in the `admins` collection
- Email includes: Owner name, email, court name, registration date

### Court Owner Notification (Verification)

When admin verifies a court owner:
- Email is sent to the court owner's email address
- Email includes: Verification confirmation, court details, next steps

## Testing

To test the email service:

1. Ensure environment variables are set correctly
2. Register a new court owner (should trigger admin email)
3. Verify the court owner as admin (should trigger owner email)

## Troubleshooting

### Emails Not Sending

1. **Check console logs**: The service logs warnings if email is not configured
2. **Verify credentials**: Ensure `SMTP_USER` and `SMTP_PASS` are correct
3. **Check firewall**: Ensure port 587 (or your SMTP port) is not blocked
4. **Test SMTP connection**: Use a tool like `telnet` to test SMTP connectivity

### Common Errors

- **"Invalid login"**: Wrong email or password (for Gmail, use App Password)
- **"Connection timeout"**: Firewall or network issue
- **"Authentication failed"**: 2FA not enabled or wrong App Password

## Security Notes

⚠️ **Important:**
- Never commit `.env` file to version control
- Use App Passwords for Gmail (not regular passwords)
- For production, use a secure secrets manager (AWS Secrets Manager, Azure Key Vault, etc.)
- Consider using a dedicated email service (SendGrid, Mailgun, AWS SES) for production

## Email Service Location

The email service is located at: `backend/utils/emailService.js`

You can customize email templates by editing the HTML/text content in this file.

