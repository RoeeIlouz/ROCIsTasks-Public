# Design Document: Android Widget Data Fix

## Overview

This design addresses the data display issues in Android home screen widgets for the ROCI's Tasks Flutter app. The widgets are currently not showing data properly due to several issues in the data flow between the Flutter app and Android native widgets. The solution involves fixing data serialization, widget service implementations, and ensuring proper data synchronization.

## Architecture

The widget system follows this data flow:
1. **Flutter App** → Collects and formats data from local storage and services
2. **HomeWidget Plugin** → Serializes data to SharedPreferences for native access
3. **Widget Providers** → Initialize and configure widget layouts
4. **Widget Services** → Fetch data and populate RemoteViews for list widgets
5. **Widget UI** → Displays formatted data to users

### Current Issues Identified

1. **Data Format Inconsistencies**: Different widgets expect different JSON structures
2. **Missing Data Fields**: Some widgets reference fields not provided by Flutter
3. **Color Format Problems**: Color values not properly formatted for Android parsing
4. **Date Format Issues**: Date strings not consistently formatted across widgets
5. **Error Handling Gaps**: Widgets crash instead of showing fallback content
6. **Update Timing**: Widget updates not triggered consistently after data changes

## Components and Interfaces

### Flutter Data Providers

**TaskProvider Updates**
- Standardize task data format for widgets
- Ensure consistent field naming (title, dueDate, dueDateIso, category_color)
- Add proper error handling for widget data serialization

**CalendarProvider Updates**
- Standardize event data format for widgets
- Ensure consistent date formatting across all widgets
- Add category color support for calendar events

**Widget Service Classes**
- MonthWidgetService: Fix grid data structure and date calculations
- FullCalendarWidgetService: Ensure proper data serialization and error handling

### Android Widget Components

**Widget Providers (Kotlin)**
- TaskWidgetProvider: Fix RemoteViews setup and error handling
- CalendarWidgetProvider: Ensure proper data binding and header updates
- ScheduleWidgetProvider: Fix service binding and empty state handling

**Widget Services (Kotlin)**
- TaskWidgetService: Fix data parsing and view population
- CalendarWidgetService: Fix event/task merging and sorting logic
- ScheduleWidgetService: Fix date parsing and item formatting

### Data Models

**Standardized Task Data Structure**
```json
{
  "id": "string",
  "title": "string",
  "dueDate": "YYYY-MM-DD", // Display format
  "dueDateIso": "ISO8601", // Sorting format
  "category_color": "#RRGGBB", // Hex color with #
  "priority": "high|medium|low",
  "isCompleted": boolean
}
```

**Standardized Event Data Structure**
```json
{
  "id": "string",
  "title": "string",
  "start": "ISO8601",
  "startDisplay": "HH:mm", // Display format
  "dateDisplay": "MMM d", // Display format
  "category_color": "#RRGGBB",
  "type": "event"
}
```

**Standardized Schedule Item Structure**
```json
{
  "id": "string",
  "title": "string",
  "date": "ISO8601", // For sorting
  "dateDisplay": "MMM d",
  "timeDisplay": "HH:mm",
  "type": "task|event",
  "category_color": "#RRGGBB"
}
```

## Data Models

### Widget Data Keys
- `pending_tasks_list`: JSON array of pending tasks for Task Widget
- `calendar_events_list`: JSON array of events for Calendar Widget
- `schedule_list`: JSON array of scheduled items for Schedule Widget
- `month_grid_data`: JSON array of calendar grid data for Month Widget
- `full_calendar_grid_data`: JSON array of detailed calendar grid for Full Calendar Widget

### Color Handling
All color values must be formatted as hex strings with # prefix (e.g., "#FF5722") for consistent parsing across Android widgets.

### Date Handling
- Use ISO8601 format for sorting and calculations
- Provide separate display format fields for UI presentation
- Handle timezone conversions properly in Flutter before sending to widgets

## Error Handling

### Flutter Side Error Handling
1. **Data Serialization Errors**: Catch JSON encoding errors and provide fallback data
2. **Service Initialization Errors**: Graceful degradation when services fail to initialize
3. **Widget Update Errors**: Retry mechanism with exponential backoff

### Android Side Error Handling
1. **Data Parsing Errors**: Use try-catch blocks with fallback to default values
2. **Color Parsing Errors**: Default to transparent or theme colors when parsing fails
3. **Date Parsing Errors**: Show "No date" or use current date as fallback
4. **Empty Data Handling**: Show appropriate empty state messages

### Logging Strategy
- Use consistent log tags for each widget type
- Log data sizes and parsing results for debugging
- Include error context and stack traces for failures

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Pending Task Filtering
*For any* collection of tasks with mixed completion states, the widget data should only include tasks where isCompleted is false
**Validates: Requirements 1.1**

### Property 2: Task Title Preservation
*For any* task with a non-empty title, the widget data should contain the exact same title string
**Validates: Requirements 1.2**

### Property 3: Date Format Consistency
*For any* task with a due date, the widget data should contain both a display format (YYYY-MM-DD) and ISO format for the same date
**Validates: Requirements 1.3**

### Property 4: Color Format Standardization
*For any* task with a category color, the widget data should contain the color as a hex string starting with '#'
**Validates: Requirements 1.4**

### Property 5: Calendar Data Merging
*For any* collection of events and tasks, the calendar widget data should contain all items sorted by their date/time values
**Validates: Requirements 2.1**

### Property 6: Event Field Completeness
*For any* event in the widget data, it should contain title, start time, and display time fields
**Validates: Requirements 2.2**

### Property 7: Task Field Completeness
*For any* task in the calendar widget data, it should contain title, due date, and display date fields
**Validates: Requirements 2.3**

### Property 8: Color Indicator Consistency
*For any* item with a category color, the widget data should format the color consistently across all widget types
**Validates: Requirements 2.4**

### Property 9: Week Number Calculation
*For any* date, the calculated week number should be between 1 and 53 and consistent with ISO week numbering
**Validates: Requirements 2.6**

### Property 10: Schedule Sorting
*For any* collection of scheduled items, the widget data should be sorted in chronological order by date and time
**Validates: Requirements 3.1**

### Property 11: Schedule Field Requirements
*For any* scheduled item, the widget data should contain title, date display, time display, and type fields
**Validates: Requirements 3.2**

### Property 12: Task Type Identification
*For any* task in the schedule widget data, it should have type field set to "task"
**Validates: Requirements 3.3**

### Property 13: Event Type Identification
*For any* event in the schedule widget data, it should have type field set to "event"
**Validates: Requirements 3.4**

### Property 14: Error Handling Graceful Degradation
*For any* malformed JSON input, the widget parsing should return empty data rather than crashing
**Validates: Requirements 5.1**

### Property 15: Color Parsing Fallback
*For any* invalid color string, the color parsing should return a default color value rather than throwing an exception
**Validates: Requirements 5.3**

### Property 16: Date Parsing Fallback
*For any* invalid date string, the date parsing should return a fallback display value rather than throwing an exception
**Validates: Requirements 5.4**

### Property 17: Data Size Limiting
*For any* large collection of items, the widget data should be limited to a maximum reasonable size (e.g., 50 items)
**Validates: Requirements 6.3**

## Testing Strategy

### Unit Testing
- Test data serialization and deserialization in Flutter
- Test JSON parsing logic in Android widget services
- Test color and date format conversions
- Test error handling paths with invalid data

### Property-Based Testing
Property-based tests will validate universal correctness properties across the widget system using the Dart test framework with the `test` package and custom property generators.

**Dual Testing Approach**:
- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property tests**: Verify universal properties across all inputs
- Both are complementary and necessary for comprehensive coverage

**Property Test Configuration**:
- Minimum 100 iterations per property test (due to randomization)
- Each property test must reference its design document property
- Tag format: **Feature: android-widget-data-fix, Property {number}: {property_text}**

### Integration Testing
- Test complete data flow from Flutter app to widget display
- Test widget updates after data changes in app
- Test widget behavior with various data sizes and edge cases
- Test widget performance under load

### Manual Testing
- Test widgets on different Android versions and screen sizes
- Test widget behavior during app lifecycle changes
- Test widget updates during network connectivity issues