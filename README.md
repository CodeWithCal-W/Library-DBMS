# Library-DBMS
# Library Management System Database

## Project Description
This is a complete database management system for a library, built entirely with MySQL. The system tracks books, authors, publishers, categories, library members, loans, reservations, and fines. It includes all the necessary tables, relationships, constraints, views, stored procedures, and triggers to manage a library's operations.

## Features
- Comprehensive book tracking with authors, publishers, and categories
- Member management with membership status tracking
- Loan management with due dates and return tracking
- Fine calculation for overdue books
- Book reservation system
- Staff management
- Views for common queries like available books and overdue books
- Stored procedures for common operations like borrowing and returning books
- Triggers for maintaining data integrity

## Database Schema
The database consists of the following main tables:
- `members` - Library members information
- `books` - Book information
- `authors` - Author information
- `publishers` - Publisher information
- `categories` - Book categories/genres
- `loans` - Book loans to members
- `fines` - Fines for overdue/lost books
- `reservations` - Book reservations
- `staff` - Library staff information

## ER Diagram
[ER Diagram](https://drive.google.com/file/d/14PFTKsHvp-qZxlK2Z3q-MgBfF1DeE6YQ/view?usp=drive_link)

## Setup Instructions
1. Install MySQL Server.
2. Open MySQL Workbench
3. Import and run the `library_management_system.sql` file.
