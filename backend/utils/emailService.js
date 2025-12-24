// Load environment variables (dotenv should be loaded in server.js, but load here as fallback)
import dotenv from "dotenv";
dotenv.config(); // Load from current directory (backend/.env)

import nodemailer from "nodemailer";
import { db } from "../config/firebase.js";

// Email configuration
const EMAIL_CONFIG = {
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: process.env.SMTP_PORT || 587,
  secure: process.env.SMTP_SECURE === "true" || false,
  auth: {
    user: process.env.SMTP_USER || "",
    pass: process.env.SMTP_PASS || "",
  },
};

// Create reusable transporter
const createTransporter = () => {
  // If no credentials provided, return null (emails won't be sent)
  if (!EMAIL_CONFIG.auth.user || !EMAIL_CONFIG.auth.pass || 
      EMAIL_CONFIG.auth.pass === "your-app-password-here" || 
      EMAIL_CONFIG.auth.pass.trim() === "") {
    console.warn("⚠️ Email service not configured. Set SMTP_USER and SMTP_PASS environment variables in .env file.");
    console.warn("   Current SMTP_USER:", EMAIL_CONFIG.auth.user || "not set");
    console.warn("   Current SMTP_PASS:", EMAIL_CONFIG.auth.pass ? "***set***" : "not set");
    return null;
  }

  return nodemailer.createTransport({
    host: EMAIL_CONFIG.host,
    port: EMAIL_CONFIG.port,
    secure: EMAIL_CONFIG.secure,
    auth: EMAIL_CONFIG.auth,
  });
};

// Create reusable transporter

// Get admin emails - master admin email is hardcoded
const getAdminEmails = async () => {
  const adminEmails = [];
  
  // Master admin email
  const masterAdminEmail = "alleeyyy9191@gmail.com";
  adminEmails.push(masterAdminEmail);
  
  // Also get admin emails from database (if any additional admins exist)
  try {
    const adminsSnapshot = await db.collection("admins").get();
    
    adminsSnapshot.forEach((doc) => {
      const adminData = doc.data();
      // Admin email might be the doc ID or in the data
      let email = doc.id.includes("@") ? doc.id : adminData.email;
      
      // Replace @khelkood.com with @gmail.com if present
      if (email && email.includes("@khelkood.com")) {
        email = email.replace("@khelkood.com", "@gmail.com");
      }
      
      if (email && !adminEmails.includes(email)) {
        adminEmails.push(email);
      }
    });
  } catch (error) {
    console.error("Error fetching admin emails from database:", error);
    // Continue with master admin email if database fetch fails
  }
  
  return adminEmails;
};

// Email Service
const EmailService = {
  /**
   * Send email notification to admin when a new court owner registers
   */
  async notifyAdminOnCourtOwnerRegistration(courtOwnerData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping admin notification.");
        return;
      }

      const adminEmails = await getAdminEmails();
      if (adminEmails.length === 0) {
        console.warn("⚠️ No admin emails found. Skipping admin notification.");
        return;
      }

      const { name, email, courtName, courtTitle } = courtOwnerData;
      const courtDisplayName = courtTitle || courtName || "Unnamed Court";

      const mailOptions = {
        from: `"KhelKood System" <${EMAIL_CONFIG.auth.user}>`,
        to: adminEmails.join(", "), // Send to all admins
        subject: "New Court Owner Registration - Action Required",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #4CAF50; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>🏸 New Court Owner Registration</h2>
              </div>
              <div class="content">
                <p>Dear Admin,</p>
                <p>A new court owner has registered and is awaiting your verification.</p>
                
                <div class="info-box">
                  <h3>Registration Details:</h3>
                  <p><strong>Owner Name:</strong> ${name || "Not provided"}</p>
                  <p><strong>Email:</strong> ${email || "Not provided"}</p>
                  <p><strong>Court Name:</strong> ${courtDisplayName}</p>
                  <p><strong>Registration Date:</strong> ${new Date().toLocaleString()}</p>
                </div>
                
                <p>Please review the registration and verify the court owner in the admin dashboard.</p>
                <p>Thank you for your attention.</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
New Court Owner Registration - Action Required

Dear Admin,

A new court owner has registered and is awaiting your verification.

Registration Details:
- Owner Name: ${name || "Not provided"}
- Email: ${email || "Not provided"}
- Court Name: ${courtDisplayName}
- Registration Date: ${new Date().toLocaleString()}

Please review the registration and verify the court owner in the admin dashboard.

Thank you for your attention.

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Admin notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending admin notification email:", error);
      // Don't throw error - email failure shouldn't break registration
      return null;
    }
  },

  /**
   * Send email notification to court owner when admin verifies them
   */
  async notifyCourtOwnerOnVerification(courtOwnerData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping verification notification.");
        return;
      }

      const { name, email, courtName, courtTitle } = courtOwnerData;
      const courtDisplayName = courtTitle || courtName || "Your Court";

      if (!email) {
        console.warn("⚠️ No email found for court owner. Skipping verification notification.");
        return;
      }

      const mailOptions = {
        from: `"KhelKood Admin" <${EMAIL_CONFIG.auth.user}>`,
        to: email,
        subject: "Account Verified - Welcome to KhelKood!",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .success-box { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #4CAF50; }
              .button { display: inline-block; padding: 12px 24px; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 5px; margin: 10px 0; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>✅ Account Verified Successfully!</h2>
              </div>
              <div class="content">
                <p>Dear ${name || "Court Owner"},</p>
                
                <div class="success-box">
                  <h3>🎉 Congratulations!</h3>
                  <p>Your court owner account has been verified and approved by the admin.</p>
                </div>
                
                <div class="info-box">
                  <h3>Your Court Information:</h3>
                  <p><strong>Court Name:</strong> ${courtDisplayName}</p>
                  <p><strong>Status:</strong> Verified ✅</p>
                </div>
                
                <p>You can now:</p>
                <ul>
                  <li>Access your court owner dashboard</li>
                  <li>Manage your court details</li>
                  <li>Receive bookings from teams</li>
                  <li>View and manage your court's schedule</li>
                </ul>
                
                <p>Welcome to KhelKood! We're excited to have you on board.</p>
                
                <p>If you have any questions or need assistance, please don't hesitate to contact our support team.</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Account Verified - Welcome to KhelKood!

Dear ${name || "Court Owner"},

🎉 Congratulations!

Your court owner account has been verified and approved by the admin.

Your Court Information:
- Court Name: ${courtDisplayName}
- Status: Verified ✅

You can now:
- Access your court owner dashboard
- Manage your court details
- Receive bookings from teams
- View and manage your court's schedule

Welcome to KhelKood! We're excited to have you on board.

If you have any questions or need assistance, please don't hesitate to contact our support team.

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Verification notification email sent to court owner:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending verification notification email:", error);
      // Don't throw error - email failure shouldn't break verification
      return null;
    }
  },

  /**
   * Send email notification to challenge creator when a team accepts their challenge
   */
  async notifyChallengeCreatorOnAcceptance(challengeCreatorData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping challenge acceptance notification.");
        return;
      }

      const { creatorEmail, creatorTeamName, acceptingTeamName, sport, courtName, startTime, endTime } = challengeCreatorData;

      if (!creatorEmail) {
        console.warn("⚠️ No email found for challenge creator. Skipping challenge acceptance notification.");
        return;
      }

      const formattedDate = startTime ? new Date(startTime).toLocaleDateString() : "N/A";
      const formattedStartTime = startTime ? new Date(startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";
      const formattedEndTime = endTime ? new Date(endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";

      const mailOptions = {
        from: `"KhelKood" <${EMAIL_CONFIG.auth.user}>`,
        to: creatorEmail,
        subject: `🎉 Your Challenge Has Been Accepted!`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .success-box { background-color: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #2196F3; }
              .team-name { font-size: 18px; font-weight: bold; color: #2196F3; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>🎉 Challenge Accepted!</h2>
              </div>
              <div class="content">
                <p>Hello ${creatorTeamName || "Team"},</p>
                
                <div class="success-box">
                  <h3>Great News! 🏆</h3>
                  <p><strong>Team ${acceptingTeamName || "Unknown Team"}</strong> has accepted your challenge!</p>
                </div>
                
                <div class="info-box">
                  <h3>Challenge Details:</h3>
                  <p><strong>Sport:</strong> ${sport || "N/A"}</p>
                  <p><strong>Court:</strong> ${courtName || "N/A"}</p>
                  <p><strong>Date:</strong> ${formattedDate}</p>
                  <p><strong>Time:</strong> ${formattedStartTime} - ${formattedEndTime}</p>
                  <p><strong>Opponent:</strong> <span class="team-name">${acceptingTeamName || "Unknown Team"}</span></p>
                </div>
                
                <p>Your challenge has been converted into a competitive match. You can now view the match details in your dashboard.</p>
                
                <p>Good luck with your match! 🏸⚽🏏</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Challenge Accepted! 🎉

Hello ${creatorTeamName || "Team"},

Great News! 🏆
Team ${acceptingTeamName || "Unknown Team"} has accepted your challenge!

Challenge Details:
- Sport: ${sport || "N/A"}
- Court: ${courtName || "N/A"}
- Date: ${formattedDate}
- Time: ${formattedStartTime} - ${formattedEndTime}
- Opponent: ${acceptingTeamName || "Unknown Team"}

Your challenge has been converted into a competitive match. You can now view the match details in your dashboard.

Good luck with your match! 🏸⚽🏏

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Challenge acceptance notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending challenge acceptance notification email:", error);
      // Don't throw error - email failure shouldn't break match creation
      return null;
    }
  },

  /**
   * Send email notification when a match is created between two teams
   */
  async notifyMatchCreated(matchData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping match creation notification.");
        return;
      }

      const { 
        hostTeamEmail, 
        hostTeamName, 
        guestTeamEmail, 
        guestTeamName, 
        sport, 
        courtName, 
        courtNum,
        startTime, 
        endTime,
        courtOwnerEmail
      } = matchData;

      if (!hostTeamEmail && !guestTeamEmail && !courtOwnerEmail) {
        console.warn("⚠️ No email found for teams or court owner. Skipping match creation notification.");
        return;
      }

      const formattedDate = startTime ? new Date(startTime).toLocaleDateString() : "N/A";
      const formattedStartTime = startTime ? new Date(startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";
      const formattedEndTime = endTime ? new Date(endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";
      
      const sportDisplayName = sport ? sport.charAt(0).toUpperCase() + sport.slice(1) : "Unknown";
      const fieldText = courtNum ? `Field ${courtNum}` : "Field";
      const courtDisplay = courtName ? `${courtName} - ${fieldText}` : "Unknown Court";

      // Email content
      const emailContent = {
        subject: `🏆 Match Created: ${hostTeamName} vs ${guestTeamName}`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #FF6B35; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .match-box { background-color: #fff3cd; border: 2px solid #ffc107; padding: 15px; margin: 10px 0; border-radius: 5px; text-align: center; }
              .team-vs { font-size: 20px; font-weight: bold; color: #FF6B35; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #FF6B35; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>🏆 Match Created!</h2>
              </div>
              <div class="content">
                <div class="match-box">
                  <p class="team-vs">${hostTeamName || "Team 1"} vs ${guestTeamName || "Team 2"}</p>
                </div>
                
                <div class="info-box">
                  <h3>Match Details:</h3>
                  <p><strong>Sport:</strong> ${sportDisplayName}</p>
                  <p><strong>Court:</strong> ${courtDisplay}</p>
                  <p><strong>Date:</strong> ${formattedDate}</p>
                  <p><strong>Time:</strong> ${formattedStartTime} - ${formattedEndTime}</p>
                </div>
                
                <p>Your competitive match has been successfully created! Get ready for an exciting game! 🏸⚽🏏</p>
                
                <p>Make sure to arrive on time and bring your best game!</p>
                
                <p>Best of luck to both teams! 🎉</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Match Created! 🏆

Match: ${hostTeamName || "Team 1"} vs ${guestTeamName || "Team 2"}

Match Details:
- Sport: ${sportDisplayName}
- Court: ${courtDisplay}
- Date: ${formattedDate}
- Time: ${formattedStartTime} - ${formattedEndTime}

Your competitive match has been successfully created! Get ready for an exciting game! 🏸⚽🏏

Make sure to arrive on time and bring your best game!

Best of luck to both teams! 🎉

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      // Send email to both teams and court owner if they have email addresses
      const recipients = [];
      if (hostTeamEmail) recipients.push(hostTeamEmail);
      if (guestTeamEmail && guestTeamEmail !== hostTeamEmail) recipients.push(guestTeamEmail);
      if (courtOwnerEmail && !recipients.includes(courtOwnerEmail)) recipients.push(courtOwnerEmail);

      if (recipients.length === 0) {
        console.warn("⚠️ No valid email addresses found. Skipping match creation notification.");
        return;
      }

      const mailOptions = {
        from: `"KhelKood" <${EMAIL_CONFIG.auth.user}>`,
        to: recipients.join(", "),
        subject: emailContent.subject,
        html: emailContent.html,
        text: emailContent.text,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Match creation notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending match creation notification email:", error);
      // Don't throw error - email failure shouldn't break match creation
      return null;
    }
  },

  /**
   * Send email notification to challenge creator when they create a challenge
   */
  async notifyChallengeCreated(challengeData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping challenge creation notification.");
        return;
      }

      const { creatorEmail, creatorTeamName, sport, courtName, startTime, endTime } = challengeData;

      if (!creatorEmail) {
        console.warn("⚠️ No email found for challenge creator. Skipping challenge creation notification.");
        return;
      }

      const formattedDate = startTime ? new Date(startTime).toLocaleDateString() : "N/A";
      const formattedStartTime = startTime ? new Date(startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";
      const formattedEndTime = endTime ? new Date(endTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : "N/A";
      const sportDisplayName = sport ? sport.charAt(0).toUpperCase() + sport.slice(1) : "Unknown";

      const mailOptions = {
        from: `"KhelKood" <${EMAIL_CONFIG.auth.user}>`,
        to: creatorEmail,
        subject: `✅ Challenge Created Successfully!`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .success-box { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #4CAF50; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>✅ Challenge Created!</h2>
              </div>
              <div class="content">
                <p>Hello ${creatorTeamName || "Team"},</p>
                
                <div class="success-box">
                  <h3>🎉 Your Challenge Has Been Created!</h3>
                  <p>Your challenge is now live and waiting for opponents to accept.</p>
                </div>
                
                <div class="info-box">
                  <h3>Challenge Details:</h3>
                  <p><strong>Sport:</strong> ${sportDisplayName}</p>
                  <p><strong>Court:</strong> ${courtName || "N/A"}</p>
                  <p><strong>Date:</strong> ${formattedDate}</p>
                  <p><strong>Time:</strong> ${formattedStartTime} - ${formattedEndTime}</p>
                </div>
                
                <p>Other teams playing the same sport can now see and accept your challenge. You'll be notified when someone accepts it!</p>
                
                <p>Good luck! 🏸⚽🏏</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Challenge Created! ✅

Hello ${creatorTeamName || "Team"},

🎉 Your Challenge Has Been Created!

Your challenge is now live and waiting for opponents to accept.

Challenge Details:
- Sport: ${sportDisplayName}
- Court: ${courtName || "N/A"}
- Date: ${formattedDate}
- Time: ${formattedStartTime} - ${formattedEndTime}

Other teams playing the same sport can now see and accept your challenge. You'll be notified when someone accepts it!

Good luck! 🏸⚽🏏

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Challenge creation notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending challenge creation notification email:", error);
      // Don't throw error - email failure shouldn't break challenge creation
      return null;
    }
  },

  /**
   * Send email notification to user when they register (pending approval)
   */
  async notifyUserOnRegistration(userData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping user registration notification.");
        return;
      }

      const { email, name, role } = userData;

      if (!email) {
        console.warn("⚠️ No email found for user. Skipping registration notification.");
        return;
      }

      const roleDisplayName = role === "courtowner" ? "Court Owner" : role === "team" ? "Team" : "User";

      const mailOptions = {
        from: `"KhelKood" <${EMAIL_CONFIG.auth.user}>`,
        to: email,
        subject: "Registration Received - Awaiting Admin Approval",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #2196F3; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .info-box { background-color: #e3f2fd; border: 1px solid #90caf9; color: #1565c0; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>📝 Registration Received</h2>
              </div>
              <div class="content">
                <p>Hello ${name || "User"},</p>
                
                <div class="info-box">
                  <h3>✅ Registration Successful!</h3>
                  <p>Thank you for registering as a <strong>${roleDisplayName}</strong> on KhelKood!</p>
                </div>
                
                <p>Your registration has been received and is currently pending admin approval.</p>
                
                <p><strong>What happens next?</strong></p>
                <ul>
                  <li>Our admin team will review your registration</li>
                  <li>You will receive an email notification once your account is approved</li>
                  <li>Once approved, you'll be able to access all features of the platform</li>
                </ul>
                
                <p>Please be patient while we process your registration. This usually takes 24-48 hours.</p>
                
                <p>If you have any questions, please don't hesitate to contact our support team.</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Registration Received - Awaiting Admin Approval

Hello ${name || "User"},

✅ Registration Successful!

Thank you for registering as a ${roleDisplayName} on KhelKood!

Your registration has been received and is currently pending admin approval.

What happens next?
- Our admin team will review your registration
- You will receive an email notification once your account is approved
- Once approved, you'll be able to access all features of the platform

Please be patient while we process your registration. This usually takes 24-48 hours.

If you have any questions, please don't hesitate to contact our support team.

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ User registration notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending user registration notification email:", error);
      return null;
    }
  },

  /**
   * Send email notification to admin when a new user registers (for any role)
   */
  async notifyAdminOnUserRegistration(userData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping admin notification.");
        return;
      }

      const adminEmails = await getAdminEmails();
      if (adminEmails.length === 0) {
        console.warn("⚠️ No admin emails found. Skipping admin notification.");
        return;
      }

      const { name, email, role } = userData;
      const roleDisplayName = role === "courtowner" ? "Court Owner" : role === "team" ? "Team" : "User";

      const mailOptions = {
        from: `"KhelKood System" <${EMAIL_CONFIG.auth.user}>`,
        to: adminEmails.join(", "),
        subject: `New ${roleDisplayName} Registration - Action Required`,
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #FF9800; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #FF9800; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>📋 New User Registration</h2>
              </div>
              <div class="content">
                <p>Dear Admin,</p>
                <p>A new user has registered and is awaiting your verification.</p>
                
                <div class="info-box">
                  <h3>Registration Details:</h3>
                  <p><strong>Name:</strong> ${name || "Not provided"}</p>
                  <p><strong>Email:</strong> ${email || "Not provided"}</p>
                  <p><strong>Role:</strong> ${roleDisplayName}</p>
                  <p><strong>Registration Date:</strong> ${new Date().toLocaleString()}</p>
                </div>
                
                <p>Please review the registration and verify or reject the user in the admin dashboard.</p>
                <p>Thank you for your attention.</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
New User Registration - Action Required

Dear Admin,

A new user has registered and is awaiting your verification.

Registration Details:
- Name: ${name || "Not provided"}
- Email: ${email || "Not provided"}
- Role: ${roleDisplayName}
- Registration Date: ${new Date().toLocaleString()}

Please review the registration and verify or reject the user in the admin dashboard.

Thank you for your attention.

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ Admin notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending admin notification email:", error);
      return null;
    }
  },

  /**
   * Send email notification to user when admin accepts their registration
   */
  async notifyUserOnAcceptance(userData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping acceptance notification.");
        return;
      }

      const { email, name, role } = userData;

      if (!email) {
        console.warn("⚠️ No email found for user. Skipping acceptance notification.");
        return;
      }

      const roleDisplayName = role === "courtowner" ? "Court Owner" : role === "team" ? "Team" : "User";

      const mailOptions = {
        from: `"KhelKood Admin" <${EMAIL_CONFIG.auth.user}>`,
        to: email,
        subject: "Account Approved - Welcome to KhelKood!",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .success-box { background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #4CAF50; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>✅ Account Approved!</h2>
              </div>
              <div class="content">
                <p>Dear ${name || "User"},</p>
                
                <div class="success-box">
                  <h3>🎉 Congratulations!</h3>
                  <p>Your ${roleDisplayName} account has been approved by the admin.</p>
                </div>
                
                <div class="info-box">
                  <h3>Your Account:</h3>
                  <p><strong>Role:</strong> ${roleDisplayName}</p>
                  <p><strong>Status:</strong> Verified ✅</p>
                </div>
                
                <p>You can now:</p>
                <ul>
                  <li>Access your dashboard</li>
                  <li>Use all platform features</li>
                  ${role === "courtowner" ? "<li>Manage your courts</li><li>Receive bookings</li>" : ""}
                  ${role === "team" ? "<li>Create and accept challenges</li><li>Book courts</li><li>Participate in matches</li>" : ""}
                </ul>
                
                <p>Welcome to KhelKood! We're excited to have you on board.</p>
                
                <p>If you have any questions or need assistance, please don't hesitate to contact our support team.</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Account Approved - Welcome to KhelKood!

Dear ${name || "User"},

🎉 Congratulations!

Your ${roleDisplayName} account has been approved by the admin.

Your Account:
- Role: ${roleDisplayName}
- Status: Verified ✅

You can now access your dashboard and use all platform features.

Welcome to KhelKood! We're excited to have you on board.

If you have any questions or need assistance, please don't hesitate to contact our support team.

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ User acceptance notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending acceptance notification email:", error);
      return null;
    }
  },

  /**
   * Send email notification to user when admin rejects their registration
   */
  async notifyUserOnRejection(userData) {
    try {
      const transporter = createTransporter();
      if (!transporter) {
        console.log("📧 Email service not configured. Skipping rejection notification.");
        return;
      }

      const { email, name, role, reason } = userData;

      if (!email) {
        console.warn("⚠️ No email found for user. Skipping rejection notification.");
        return;
      }

      const roleDisplayName = role === "courtowner" ? "Court Owner" : role === "team" ? "Team" : "User";

      const mailOptions = {
        from: `"KhelKood Admin" <${EMAIL_CONFIG.auth.user}>`,
        to: email,
        subject: "Registration Not Approved",
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; }
              .header { background-color: #f44336; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
              .content { background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; }
              .warning-box { background-color: #ffebee; border: 1px solid #ef5350; color: #c62828; padding: 15px; margin: 10px 0; border-radius: 5px; }
              .info-box { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #f44336; }
              .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h2>❌ Registration Not Approved</h2>
              </div>
              <div class="content">
                <p>Dear ${name || "User"},</p>
                
                <div class="warning-box">
                  <h3>Registration Status Update</h3>
                  <p>We regret to inform you that your ${roleDisplayName} registration has not been approved.</p>
                </div>
                
                ${reason ? `
                <div class="info-box">
                  <h3>Reason:</h3>
                  <p>${reason}</p>
                </div>
                ` : ''}
                
                <p>Your account has been removed from our system. If you believe this is an error or would like to reapply, please contact our support team.</p>
                
                <p>If you have any questions, please don't hesitate to reach out to us.</p>
                
                <p>Best regards,<br>The KhelKood Team</p>
              </div>
              <div class="footer">
                <p>This is an automated email from KhelKood System.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `
Registration Not Approved

Dear ${name || "User"},

Registration Status Update

We regret to inform you that your ${roleDisplayName} registration has not been approved.

${reason ? `Reason: ${reason}` : ''}

Your account has been removed from our system. If you believe this is an error or would like to reapply, please contact our support team.

If you have any questions, please don't hesitate to reach out to us.

Best regards,
The KhelKood Team

---
This is an automated email from KhelKood System.
        `,
      };

      const info = await transporter.sendMail(mailOptions);
      console.log("✅ User rejection notification email sent:", info.messageId);
      return info;
    } catch (error) {
      console.error("❌ Error sending rejection notification email:", error);
      return null;
    }
  },
};

export default EmailService;

