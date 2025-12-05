# Challenge API Fixes - 500 Error Resolution

## Problem Summary
The frontend was receiving **500 Internal Server Error** for both:
1. `GET /api/challenges/open` - Could not view challenges
2. `POST /api/challenges/create` - Could not create challenges

## Root Causes Identified

### Issue 1: Controller Instance Not Created
**File**: `backend/team/challenges.js`

**Problem**:
```javascript
// ❌ WRONG - Calling static methods on class (not instance)
router.post("/create", verifyToken(["team"]), (req, res) =>
  ChallengeController.create(req, res)  // No instance created!
);
```

**Why it failed**:
- `ChallengeController` is a class, not an instance
- Methods require `this.challengeService` which only exists on instances
- Calling methods on the class directly causes `undefined` errors

**Fix**:
```javascript
// ✅ CORRECT - Create instance with dependencies
const challengeRepository = new ChallengeRepository(db);
const challengeService = new ChallengeService(challengeRepository);
const challengeController = new ChallengeController(challengeService);

router.post("/create", verifyToken(["team"]), (req, res) =>
  challengeController.createChallenge(req, res)  // Call on instance
);
```

---

### Issue 2: Missing `getOpenChallenges` Method
**Problem**: Frontend called `/api/challenges/open` but no corresponding controller method existed.

**What frontend expected**:
```json
{
  "data": {
    "incoming": [ /* challenges from other teams */ ],
    "outgoing": [ /* my team's challenges */ ]
  }
}
```

**Fix**: Implemented custom route handler with complete logic:
```javascript
router.get("/open", verifyToken(["team"]), async (req, res) => {
  // 1. Get team info
  // 2. Fetch outgoing challenges (team's own)
  // 3. Fetch all challenges and filter for incoming
  // 4. Enrich with court/team data
  // 5. Return formatted response
});
```

---

### Issue 3: Field Name Mismatch (Create Challenge)
**Problem**: Frontend sends different field names than backend expects.

**Frontend sends** (from `create_challenge_page.dart`):
```dart
{
  'courtFirebaseUID': selectedCourtId,  // ❌ Backend expects 'courtID'
  'stime': startDateTime,               // ❌ Backend expects 'startTime'
  'etime': endDateTime,                 // ❌ Backend expects 'endTime'
  'courtNum': selectedCourtNum,         // ✅ Matches
  // Missing: 'sport', 'teamName'       // ❌ Required by backend
}
```

**Backend expects** (from `ChallengeService.js`):
```javascript
{
  courtID: string,    // ❌ Frontend sends 'courtFirebaseUID'
  sport: string,      // ❌ Missing from frontend
  startTime: string,  // ❌ Frontend sends 'stime'
  endTime: string,    // ❌ Frontend sends 'etime'
  courtNum: number,   // ✅ Matches
  teamName: string    // ❌ Missing from frontend
}
```

**Fix**: Added adapter in route to map frontend → backend:
```javascript
router.post("/create", verifyToken(["team"]), async (req, res) => {
  // Get team to fill missing data
  const team = await challengeRepository.findTeamByUserId(teamID);
  
  // Map frontend fields → backend fields
  const { courtFirebaseUID, stime, etime, courtNum } = req.body;
  
  const challengeData = {
    courtID: courtFirebaseUID,    // ✅ Map field name
    sport: team.sports,            // ✅ Add from team
    startTime: stime,              // ✅ Map field name
    endTime: etime,                // ✅ Map field name
    courtNum: courtNum,            // ✅ Already matches
    teamName: team.teamName,       // ✅ Add from team
  };
  
  await challengeService.createChallenge(team.id, challengeData);
});
```

---

## Architecture Patterns Used

### ✅ Dependency Injection
```javascript
// Service depends on Repository (not hardcoded)
const challengeService = new ChallengeService(challengeRepository);

// Controller depends on Service (not hardcoded)
const challengeController = new ChallengeController(challengeService);
```

**Benefits**:
- Loose coupling
- Easy to test with mocks
- Follows **Dependency Inversion Principle**

---

### ✅ Repository Pattern
```javascript
class ChallengeRepository extends BaseRepository {
  async findTeamByUserId(userId) { /* ... */ }
  async findCourtById(courtID) { /* ... */ }
  async findAllByHostTeamID(teamID) { /* ... */ }
}
```

**Benefits**:
- Single source for data access
- Follows **Single Responsibility Principle**
- Easy to swap data sources

---

### ✅ Service Layer
```javascript
class ChallengeService {
  async createChallenge(teamID, data) {
    // Validate
    // Get related data
    // Calculate pricing
    // Create challenge
  }
}
```

**Benefits**:
- Business logic separated from routing
- Reusable across different endpoints
- Follows **Single Responsibility Principle**

---

## Complete Fix Summary

### `/api/challenges/open` (GET)
**Changes**:
1. ✅ Created controller instance
2. ✅ Implemented custom route handler
3. ✅ Added logic to separate incoming/outgoing challenges
4. ✅ Enriched challenges with court and team data
5. ✅ Formatted response to match frontend expectations

**Response format**:
```json
{
  "success": true,
  "message": "Open challenges retrieved successfully",
  "data": {
    "incoming": [
      {
        "challengeID": "abc123",
        "Court_Name": "Main Court",
        "Court_Address": "123 Street",
        "Host_Team_Name": "Warriors",
        "Host_Team_Points": 150,
        "Sport": "football",
        "Start_Time": "2024-01-01T10:00:00Z",
        "End_Time": "2024-01-01T12:00:00Z",
        "Price": 5000
      }
    ],
    "outgoing": [ /* ... */ ]
  }
}
```

---

### `/api/challenges/create` (POST)
**Changes**:
1. ✅ Created controller instance
2. ✅ Added field mapping adapter
3. ✅ Fetched team data to fill missing fields
4. ✅ Proper error handling with try-catch
5. ✅ Formatted response to match frontend expectations

**Request flow**:
```
Frontend sends:
{ courtFirebaseUID, stime, etime, courtNum }
    ↓
Adapter maps to:
{ courtID, startTime, endTime, courtNum, sport, teamName }
    ↓
Service validates and creates challenge
    ↓
Response sent to frontend
```

---

## Files Modified

### Backend Files:
1. ✅ `backend/team/challenges.js` - **Main fix file**
   - Created instances of Repository, Service, Controller
   - Implemented `/open` route handler
   - Implemented `/create` route adapter
   - Added proper error handling

---

## Testing Checklist

### ✅ View Challenges (GET /api/challenges/open)
- [x] Returns incoming challenges (from other teams, same sport, not matched)
- [x] Returns outgoing challenges (team's own challenges)
- [x] Enriches with court names, addresses, ratings
- [x] Enriches with team names and points
- [x] Filters out matched challenges
- [x] Returns proper error for missing team

### ✅ Create Challenge (POST /api/challenges/create)
- [x] Accepts frontend field names (courtFirebaseUID, stime, etime)
- [x] Maps to backend field names (courtID, startTime, endTime)
- [x] Automatically fills sport from team data
- [x] Automatically fills teamName from team data
- [x] Validates required fields
- [x] Calculates pricing
- [x] Returns challengeID and pricing info

---

## SOLID Principles Demonstrated

### 1. **Single Responsibility Principle (SRP)**
- `ChallengeRepository` - Only data access
- `ChallengeService` - Only business logic
- `ChallengeController` - Only request/response handling
- Route handlers - Only routing and adaptation

### 2. **Dependency Inversion Principle (DIP)**
- Controller depends on Service (abstract interface)
- Service depends on Repository (abstract interface)
- High-level modules don't depend on low-level details

### 3. **Open/Closed Principle (OCP)**
- `BaseRepository` provides common operations
- Subclasses extend without modifying base
- `ChallengeRepository` adds specific methods

---

## Error Handling Improvements

### Before:
```javascript
// ❌ No error handling
router.post("/create", (req, res) => controller.create(req, res));
```

### After:
```javascript
// ✅ Comprehensive error handling
router.post("/create", async (req, res) => {
  try {
    // Validate auth
    if (!teamID) {
      return res.status(401).json({ error: "Unauthorized" });
    }
    
    // Validate team exists
    const team = await repository.findTeamByUserId(teamID);
    if (!team) {
      return res.status(404).json({ error: "Team not found" });
    }
    
    // Process request
    const result = await service.createChallenge(/*...*/);
    return res.status(201).json({ success: true, data: result });
    
  } catch (error) {
    console.error("Error:", error);
    return res.status(500).json({ error: error.message });
  }
});
```

---

## Future Improvements

### 1. Extract Adapter to Separate Function
```javascript
// Could be moved to a utility file
function adaptChallengeRequest(frontendData, team) {
  return {
    courtID: frontendData.courtFirebaseUID,
    sport: team.sports,
    startTime: frontendData.stime,
    endTime: frontendData.etime,
    courtNum: frontendData.courtNum,
    teamName: team.teamName,
  };
}
```

### 2. Add Response Formatter
```javascript
function formatChallengeResponse(challenge, court, team) {
  return {
    challengeID: challenge.id,
    Court_Name: court?.name || "Unknown Court",
    // ... rest of formatting
  };
}
```

### 3. Add Validation Middleware
```javascript
const validateChallengeCreate = (req, res, next) => {
  const { courtFirebaseUID, stime, etime, courtNum } = req.body;
  
  if (!courtFirebaseUID || !stime || !etime || !courtNum) {
    return res.status(400).json({ error: "Missing required fields" });
  }
  
  next();
};

router.post("/create", 
  verifyToken(["team"]), 
  validateChallengeCreate,  // Add validation middleware
  createChallengeHandler
);
```

---

## Conclusion

The 500 errors were caused by:
1. ❌ Not creating controller instances
2. ❌ Missing route handler for `/open`
3. ❌ Field name mismatches between frontend/backend

All issues are now **FIXED** and the architecture follows **SOLID principles** with proper:
- ✅ Dependency Injection
- ✅ Repository Pattern
- ✅ Service Layer
- ✅ Error Handling
- ✅ Request/Response Adaptation

