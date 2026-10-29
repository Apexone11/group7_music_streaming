-- ==========================================================================
-- IS410 Class Project - Music Streaming System
-- Group 7
--
-- Group Members:
--   Abdul Fornah
--   Andy Pham
--   Randy Doan
--   Rawza Bari
--   Travis Warden
--
-- Instructor: Neha Singh
-- Date: October 29, 2026
-- Database: Oracle SQL
-- ==========================================================================


-- ==========================================================================
-- SECTION 1: DROP TABLES (so the script can be re-run cleanly)
-- Drop child tables first, then parent tables (reverse of create order).
-- ==========================================================================

-- TODO: DROP TABLE Artist_Payout
-- TODO: DROP TABLE Artist_Follower
-- TODO: DROP TABLE Stream_History
-- TODO: DROP TABLE Playlist_Track
-- TODO: DROP TABLE Playlist
-- TODO: DROP TABLE Track
-- TODO: DROP TABLE Album
-- TODO: DROP TABLE Administrator
-- TODO: DROP TABLE Artist
-- TODO: DROP TABLE Listener
-- TODO: DROP TABLE Account


-- ==========================================================================
-- SECTION 2: CREATE TABLES
-- Create parent tables first so the foreign keys have something to point to.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- Table: Account (superclass)
-- Columns: Account_ID (PK), Name, Email, Join_Date
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Account


-- --------------------------------------------------------------------------
-- Table: Listener (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Subscription_Type
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Listener


-- --------------------------------------------------------------------------
-- Table: Artist (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Stage_Name, Bio, Verified_Status
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Artist


-- --------------------------------------------------------------------------
-- Table: Administrator (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Clearance_Level, Role_Title
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Administrator


-- --------------------------------------------------------------------------
-- Table: Album
-- Columns: Album_ID (PK), Title, Release_Date, Genre, Artist_ID (FK -> Artist)
-- Business rule: every Album must belong to an Artist (Artist_ID NOT NULL)
-- Business rule: deleting an Artist deletes their Albums (ON DELETE CASCADE)
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Album


-- --------------------------------------------------------------------------
-- Table: Track
-- Columns: Track_ID (PK), Title, Duration, Album_ID (FK -> Album)
-- Business rule: a Track cannot exist without an Album (Album_ID NOT NULL)
-- Business rule: deleting an Album deletes its Tracks (ON DELETE CASCADE)
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Track


-- --------------------------------------------------------------------------
-- Table: Playlist
-- Columns: Playlist_ID (PK), Playlist_Name, Creation_Date,
--          Listener_ID (FK -> Listener)
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Playlist


-- --------------------------------------------------------------------------
-- Table: Playlist_Track (bridge table: Playlist M:N Track)
-- Columns: Playlist_ID (PK, FK -> Playlist), Track_ID (PK, FK -> Track),
--          Date_Added, Track_Order
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Playlist_Track


-- --------------------------------------------------------------------------
-- Table: Stream_History
-- Columns: Stream_ID (PK), Stream_Timestamp,
--          Listener_ID (FK -> Listener), Track_ID (FK -> Track)
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Stream_History


-- --------------------------------------------------------------------------
-- Table: Artist_Follower (bridge table: Listener M:N Artist)
-- Columns: Listener_ID (PK, FK -> Listener), Artist_ID (PK, FK -> Artist),
--          Follow_Date
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Artist_Follower


-- --------------------------------------------------------------------------
-- Table: Artist_Payout
-- Columns: Payout_ID (PK), Amount, Payout_Date, Payment_Method,
--          Artist_ID (FK -> Artist)
-- --------------------------------------------------------------------------
-- TODO: CREATE TABLE Artist_Payout


-- ==========================================================================
-- SECTION 3: INSERT SAMPLE DATA
-- Insert into parent tables before child tables.
-- ==========================================================================

-- TODO: INSERT rows into Account
-- TODO: INSERT rows into Listener
-- TODO: INSERT rows into Artist
-- TODO: INSERT rows into Administrator
-- TODO: INSERT rows into Album
-- TODO: INSERT rows into Track
-- TODO: INSERT rows into Playlist
-- TODO: INSERT rows into Playlist_Track
-- TODO: INSERT rows into Stream_History
-- TODO: INSERT rows into Artist_Follower
-- TODO: INSERT rows into Artist_Payout

-- TODO: COMMIT


-- ==========================================================================
-- SECTION 4: QUERIES
-- ==========================================================================

-- TODO: Query - search tracks by genre and release date (unbiased discovery)

-- TODO: Query - count streams per artist (used to compute payouts)

-- TODO: Query - list all tracks in a listener's playlist, in Track_Order

-- TODO: Query - list the artists a listener follows

-- TODO: Query - show payout history for an artist


-- ==========================================================================
-- END OF SCRIPT
-- ==========================================================================
