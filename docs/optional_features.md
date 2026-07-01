# 🚀 Optional Features & Future Roadmap

This document outlines potential features and improvements for ROCI's Tasks to enhance user engagement, productivity, and overall experience.

## 1. Gamification & Engagement

To keep users coming back and motivated:

- **Daily Streaks**: Display a "Daily Completion Streak" on the Insights tab.
- **Focus Mode (Pomodoro)**: A built-in timer for specific tasks with ambient sounds.
- **Productivity Score**: A weekly score based on completion rates and priority handling.
- **Confetti Animations**: Visual rewards for completing important tasks or finishing the daily list.

## 2. UI/UX Polish

Enhancing the "Premium" feel of the application:

- **Haptic Feedback**: Subtle vibration feedback for completion, deletion, and pinning.
- **Enhanced Empty States**: Custom illustrations and tips for empty tabs (Calendar/Insights).
- **Smooth Transitions**: Improved hero animations when opening task details.

## 3. Power User Features

Streamlining the workflow for advanced users:

- **Bulk Actions**: Multi-select mode to move, delete, or pin multiple tasks at once.
- **Natural Language Parsing**: "Smart Add" that parses dates and times from text (e.g., "Lunch tomorrow at 2pm").
- **Sub-task Dependencies (Pro)**: Prevent a task from becoming "Active" (or sending reminders) until prerequisite sub-tasks are completed.
- **Task Attachments & File Syncing (Pro)**: Attach photos, documents, or voice notes directly to tasks using a cloud storage layer (e.g., Firebase Storage / Supabase Storage).
- **Quick Actions**: Force-touch/Long-press shortcuts from the home screen icon.
- **Geofencing**: Location-based reminders (e.g., "Remind me when I get home").

## 4. Expanded Ecosystem

Reaching users where they are:

- **Wearable Support**: Companion app for Apple Watch and Wear OS.
- **Desktop Clients**: Native versions for Windows and macOS.
- **Collaboration**: Shared lists for team or family coordination.

## 5. Advanced Analytics

Deeper insights into work patterns:

- **Activity Heatmap**: A year-view completion heatmap (GitHub style).
- **Time Allocation**: Analysis of how much time is spent on different categories.
- **Predictive Deadlines**: AI-powered suggestions for task deadlines based on historical behavior.

## 6. New Features

- [x] **The default visibility of private tasks is locked**: If a private task is created immediately lock it, and if the user doesnt have the security setting turned on then when he creted the private task/private category then they will see a pop up prompting them to enable the security settings (setting up a pin or biometrics).
- [x] **Fix the issue where notifications are sent for tasks that are created with the "Do not remind" option**: These notifications should not be sent.
- [x] **When a task is created immediately call the task counter notification so it will be updated**.
- [x] **Add search symbols**: add the functionality of adding a "@" for searching a category, a "#" for searching a task, a "!" for searching a priority, a "%" for searching a due date, a "&" for searching a sub-task, a "\*" for searching a completion status and a "?" for searching a task that is due today. add this feature to the app guide.
- [x] **App Guide Update**: Update the app guide to include the new features. also show the app guide in the onboarding page when new users get in to the app.
- **New Widgets**: Suggest new widgets that we can add to the app to improve the user experience.
  - [x] **Quick Add Widget**: A small widget with just a text field and + button for rapid task creation without opening the app.
  - [x] **Overdue Tasks Widget**: A compact widget showing only overdue tasks with priority colors and due times.
  - [x] **Mini Calendar Widget**: A compact single-month grid variant with event/task indicator dots and month navigation.
  - **Weekly Summary Widget**: Shows completion stats for the current week (completed vs pending, streak info).
  - **Habit Tracker Widget**: Daily streak tracking widget with checkmarks for completed habits.
- [x] **Fix the issue where the due date is not updated when the task is rescheduled**.
- [x] **Fix the issue where attached files arent shown in the task details**.
