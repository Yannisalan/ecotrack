ECOTrack Full Enhancement - Implementation Summary

Status: Implemented (incremental edits to existing codebase)

Backend changes:
- Models: UserPoints, PointsLedger, EcoScoreHistory, Challenge, UserChallenge (non-destructive additions)
- Blueprints/endpoints: achievements, goals, reports, assistant, challenges; DELETE /auth/account; GET /api/stats/score-history
- Recommendations: fixed/verified to use existing provider data with fallback

Frontend changes:
- Screens: Achievements (linked from Profile), Challenges (accessible), Carbon Reports UI
- Profile: Delete Account with confirmation dialog, navigation to login on success
- Recommendations: wired to DashboardProvider to display real data when available

Preservation:
- All existing functionality/auth/calculations preserved
- No destructive DB operations

Verification:
- Backend pytest: 37 passed
- Flutter analyze: No issues found
- Flutter test: 1 passed

Ready for manual demonstration.
