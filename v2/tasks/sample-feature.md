# Sample Task: Build User Dashboard

## Objective
Create a user dashboard component that displays user statistics and recent activity.

## Requirements

### Functional Requirements
1. Display user profile information (name, email, avatar)
2. Show statistics cards (total projects, active tasks, completed tasks)
3. List recent activity feed (last 10 items)
4. Add quick action buttons (new project, new task)

### Technical Requirements
1. Use React with TypeScript
2. Style with Tailwind CSS
3. Fetch data from `/api/user/dashboard` endpoint
4. Include loading and error states
5. Make it responsive (mobile-first)

### File Structure
```
src/
  components/
    dashboard/
      Dashboard.tsx
      DashboardStats.tsx
      ActivityFeed.tsx
      QuickActions.tsx
      Dashboard.test.tsx
  hooks/
    useDashboard.ts
  types/
    dashboard.types.ts
```

## Acceptance Criteria
- [ ] All components render without errors
- [ ] TypeScript has no errors
- [ ] ESLint passes
- [ ] Unit tests pass with 80%+ coverage
- [ ] Responsive on mobile and desktop
- [ ] Loading skeleton shows during data fetch
- [ ] Error boundary catches and displays errors

## Notes
- Use shadcn/ui components where applicable
- Follow existing code patterns in the project
- Add JSDoc comments to exported functions
