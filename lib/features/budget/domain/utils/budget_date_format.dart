// ignore_for_file: dangling_library_doc_comments
/// budget_date_format.dart
///
/// Purpose: Provides date-formatting helper functions used across the budget
/// feature's presentation layer.
///
/// Responsibility: Centralise the repeated DateFormat patterns used by budget
/// widgets and screens so the same locale ('ar') and pattern strings are not
/// duplicated across multiple files.
///
/// Dependencies: intl (DateFormat).
///
/// Why this file exists: Multiple budget widgets and budget_tracking_screen.dart
/// called DateFormat('d MMM', 'ar').format(…) and similar patterns inline.
/// Extracting them to named helpers makes call sites more readable and ensures
/// the locale string is defined in exactly one place.
///
/// Must never: Contain business logic, financial calculations, Cubit calls,
/// widget code, or any formatting beyond pure date/time presentation strings.

import 'package:intl/intl.dart';

/// Short date — e.g. "5 يون"
/// Pattern: `d MMM`
String budgetFormatShortDate(DateTime date) =>
    DateFormat('d MMM', 'ar').format(date);

/// Medium date — e.g. "5 يونيو"
/// Pattern: `d MMMM`
String budgetFormatMediumDate(DateTime date) =>
    DateFormat('d MMMM', 'ar').format(date);

/// Full date — e.g. "5 يونيو 2025"
/// Pattern: `d MMMM yyyy`
String budgetFormatFullDate(DateTime date) =>
    DateFormat('d MMMM yyyy', 'ar').format(date);

/// Month and year — e.g. "يونيو 2025"
/// Pattern: `MMMM yyyy`
String budgetFormatMonthYear(DateTime date) =>
    DateFormat('MMMM yyyy', 'ar').format(date);

/// Short numeric date — e.g. "5/6"
/// Pattern: `d/M`
String budgetFormatShortNumericDate(DateTime date) =>
    DateFormat('d/M', 'ar').format(date);

/// 24-hour time — e.g. "09:11"
/// Pattern: `HH:mm`
String budgetFormatTime(DateTime date) =>
    DateFormat('HH:mm', 'ar').format(date);

/// Date and time combined — e.g. "5/6 - 09:11"
/// Pattern: `d/M - HH:mm`
String budgetFormatDateAndTime(DateTime date) =>
    DateFormat('d/M - HH:mm', 'ar').format(date);
