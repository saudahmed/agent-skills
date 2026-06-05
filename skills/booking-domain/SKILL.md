---
name: booking-domain
description: Defines the canonical domain vocabulary for the Mr.Cleaner booking wizard. Use when working on booking features, the multi-step wizard, service selection, contact forms, scheduling, or any domain type (BookingFormData, ResolvedBooking, ServiceSelection, resolveBooking).
---

Use these terms consistently in code, tests, commits, and issues. Each entry lists words to avoid so we don't drift into synonyms.

**Booking**: Data assembled in the wizard — services, property details, cleaning details, scheduling, contact info. Lives as `BookingFormData`, keyed by step (`step1`–`step5`). _Avoid_: Order, request (while editing), form.

**Booking Request**: Resolved, business-language, human-readable form of a Booking — IDs mapped to labels, booleans rendered, values formatted — ready for the operator. Type: `ResolvedBooking`; builder: `resolveBooking(formData, messages)`. _Avoid_: Submission payload, German labels, resolved form data.

**Operator**: The cleaning business that receives and acts on Booking Requests. Identified per deployment by business config (email, phone, language). _Avoid_: Admin, vendor, merchant, business (as a role).

**Business Locale**: Language the operator reads, set per deployment via `BUSINESS_LOCALE` (default `de`). Independent of the visitor's UI locale — a booking on `cleanerpro.nl` produces a Dutch Booking Request regardless of how the visitor browsed. _Avoid_: Default locale, German, server locale.

**Service Selection**: One service the visitor picked plus choices within that service's option groups. Lives as `ServiceSelection` (`serviceId` + `groupSelections`). _Avoid_: Product, item, cart entry.
