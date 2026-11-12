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


DROP TABLE Artist_Payout_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Artist_Follower_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Stream_History_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Playlist_Track_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Playlist_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Track_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Album_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Administrator_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Artist_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Listener_T CASCADE CONSTRAINTS PURGE;

DROP TABLE Account_T CASCADE CONSTRAINTS PURGE;


-- ==========================================================================
-- SECTION 2: CREATE TABLES
-- Create parent tables first so the foreign keys have something to point to.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- Table: Account_T (superclass)
-- Columns: Account_ID (PK), Name, Email, Join_Date
-- --------------------------------------------------------------------------

CREATE TABLE Account_T
(
    Account_ID NUMBER(10) PRIMARY KEY,
    Name       VARCHAR2(50) NOT NULL,
    Email      VARCHAR2(60) NOT NULL,
    Join_Date  DATE         DEFAULT SYSDATE NOT NULL,

    CONSTRAINT Account_Email_UQ UNIQUE (Email),
    CONSTRAINT Account_Email_CK CHECK (Email LIKE '%_@_%._%')
);

-- Makes sure that Join Dates aren't in the future
CREATE OR REPLACE TRIGGER Account_JoinDate_TRG
BEFORE INSERT OR UPDATE OF Join_Date ON Account_T
FOR EACH ROW
BEGIN
    IF :NEW.Join_Date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Join_Date cannot be in the future.');
    END IF;
END;

-- --------------------------------------------------------------------------
-- Table: Listener_T (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Subscription_Type
-- --------------------------------------------------------------------------

CREATE TABLE Listener_T
(
    Account_ID        NUMBER(10) PRIMARY KEY,
    Subscription_Type VARCHAR2(20) NOT NULL,

    CONSTRAINT Listener_Account_FK FOREIGN KEY (Account_ID) REFERENCES Account_T (Account_ID) ON DELETE CASCADE
);

-- --------------------------------------------------------------------------
-- Table: Artist_T (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Stage_Name, Bio, Verified_Status
-- --------------------------------------------------------------------------

CREATE TABLE Artist_T
(
    Account_ID      NUMBER(10) PRIMARY KEY,
    Stage_Name      VARCHAR2(50)  NOT NULL,
    Bio             VARCHAR2(500),
    Verified_Status CHAR(1) DEFAULT 'N' NOT NULL,

    CONSTRAINT Artist_Account_FK FOREIGN KEY (Account_ID) REFERENCES Account_T (Account_ID) ON DELETE CASCADE,
    CONSTRAINT Artist_Verified_CK CHECK (Verified_Status IN ('Y', 'N'))
);

-- --------------------------------------------------------------------------
-- Table: Administrator_T (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Clearance_Level, Role_Title
-- --------------------------------------------------------------------------

CREATE TABLE Administrator_T
(
    Account_ID      NUMBER PRIMARY KEY,
    Clearance_Level NUMBER(1)       NOT NULL, -- thir is only 1,2,3,4 levels 
    Role_Title      VARCHAR2(40) NOT NULL,

    CONSTRAINT Administrator_Account_FK FOREIGN KEY (Account_ID) REFERENCES Account_T (Account_ID) ON DELETE CASCADE,
    CONSTRAINT Administrator_Clearance_CK CHECK (Clearance_Level BETWEEN 1 AND 5)
);


-- --------------------------------------------------------------------------
-- Table: Album_T
-- Columns: Album_ID (PK), Title, Release_Date, Genre, Artist_ID (FK -> Artist)
-- Business rule: every Album must belong to an Artist (Artist_ID NOT NULL)
-- Business rule: deleting an Artist deletes their Albums (ON DELETE CASCADE)
-- --------------------------------------------------------------------------

CREATE TABLE Album_T
(
    Album_ID     NUMBER(10) PRIMARY KEY,
    Title        VARCHAR2(50) NOT NULL,
    Release_Date DATE         NOT NULL,
    Genre        VARCHAR2(30) NOT NULL,
    Artist_ID    NUMBER(10)       NOT NULL,

    CONSTRAINT Album_Artist_FK FOREIGN KEY (Artist_ID) REFERENCES Artist_T (Account_ID) ON DELETE CASCADE
);


-- --------------------------------------------------------------------------
-- Table: Track_T
-- Columns: Track_ID (PK), Title, Duration, Album_ID (FK -> Album)
-- Business rule: a Track cannot exist without an Album (Album_ID NOT NULL)
-- Business rule: deleting an Album deletes its Tracks (ON DELETE CASCADE)
-- --------------------------------------------------------------------------

CREATE TABLE Track_T
(
    Track_ID NUMBER(10) PRIMARY KEY,
    Title    VARCHAR2(50) NOT NULL,
    Duration NUMBER(6)      NOT NULL,
    Album_ID NUMBER(10)     NOT NULL,

    CONSTRAINT Track_Album_FK FOREIGN KEY (Album_ID) REFERENCES Album_T (Album_ID) ON DELETE CASCADE,
    CONSTRAINT Track_Duration_CK CHECK (Duration > 0)
);

-- --------------------------------------------------------------------------
-- Table: Playlist
-- Columns: Playlist_ID (PK), Playlist_Name, Creation_Date,
--          Listener_ID (FK -> Listener)
-- --------------------------------------------------------------------------

CREATE TABLE Playlist_T
(
    Playlist_ID   NUMBER(10) PRIMARY KEY,
    Playlist_Name VARCHAR2(50) NOT NULL,
    Creation_Date DATE         NOT NULL,
    Listener_ID   NUMBER(10)       NOT NULL,

    CONSTRAINT Playlist_Listener_FK FOREIGN KEY (Listener_ID) REFERENCES Listener_T (Account_ID)
);

-- --------------------------------------------------------------------------
-- Table: Playlist_Track (bridge table: Playlist M:N Track)
-- Columns: Playlist_ID (PK, FK -> Playlist), Track_ID (PK, FK -> Track),
--          Date_Added, Track_Order
-- --------------------------------------------------------------------------

CREATE TABLE Playlist_Track_T
(
    Playlist_ID NUMBER(10) NOT NULL,
    Track_ID    NUMBER(10) NOT NULL,
    Date_Added  DATE   NOT NULL,
    Track_Order NUMBER(10) NOT NULL,

    CONSTRAINT Playlist_Track_PK PRIMARY KEY (Playlist_ID, Track_ID),
    CONSTRAINT Playlist_Track_Playlist_FK FOREIGN KEY (Playlist_ID) REFERENCES Playlist_T (Playlist_ID) ON DELETE CASCADE,
    CONSTRAINT Playlist_Track_Track_FK FOREIGN KEY (Track_ID) REFERENCES Track_T (Track_ID) ON DELETE CASCADE,
    CONSTRAINT Playlist_Track_Order_CK CHECK (Track_Order > 0)
);


-- --------------------------------------------------------------------------
-- Table: Stream_History
-- Columns: Stream_ID (PK), Stream_Timestamp,
--          Listener_ID (FK -> Listener), Track_ID (FK -> Track)
-- --------------------------------------------------------------------------

CREATE TABLE Stream_History_T
(
    Stream_ID        NUMBER(10) PRIMARY KEY,
    Stream_Timestamp TIMESTAMP     NOT NULL,
    Listener_ID      NUMBER(10)    NOT NULL,
    Track_ID         NUMBER(10)    NOT NULL,

    CONSTRAINT Stream_History_Listener_FK FOREIGN KEY (Listener_ID) REFERENCES Listener_T (Account_ID),
    CONSTRAINT Stream_History_Track_FK FOREIGN KEY (Track_ID) REFERENCES Track_T (Track_ID)
);


-- --------------------------------------------------------------------------
-- Table: Artist_Follower (bridge table: Listener M:N Artist)
-- Columns: Listener_ID (PK, FK -> Listener), Artist_ID (PK, FK -> Artist),
--          Follow_Date
-- --------------------------------------------------------------------------

CREATE TABLE Artist_Follower_T
(
    Listener_ID NUMBER(10) NOT NULL,
    Artist_ID   NUMBER(10) NOT NULL,
    Follow_Date DATE   NOT NULL,

    CONSTRAINT Artist_Follower_PK PRIMARY KEY (Listener_ID, Artist_ID),
    CONSTRAINT Artist_Follower_Listener_FK FOREIGN KEY (Listener_ID) REFERENCES Listener_T (Account_ID) ON DELETE CASCADE,
    CONSTRAINT Artist_Follower_Artist_FK FOREIGN KEY (Artist_ID) REFERENCES Artist_T (Account_ID) ON DELETE CASCADE
);


-- --------------------------------------------------------------------------
-- Table: Artist_Payout
-- Columns: Payout_ID (PK), Amount, Payout_Date, Payment_Method,
--          Artist_ID (FK -> Artist)
-- --------------------------------------------------------------------------

CREATE TABLE Artist_Payout_T
(
    Payout_ID      NUMBER(10) PRIMARY KEY,
    Amount         NUMBER(10,2) NOT NULL,
    Payout_Date    DATE          NOT NULL,
    Payment_Method VARCHAR2(30)  NOT NULL,
    Artist_ID      NUMBER(10)        NOT NULL,

    CONSTRAINT Artist_Payout_Artist_FK FOREIGN KEY (Artist_ID) REFERENCES Artist_T (Account_ID),
    CONSTRAINT Artist_Payout_Amount_CK CHECK (Amount >= 0)
);

-- ==========================================================================
-- SECTION 2.5: INDEXES
-- These indexes prevent full table scans, speeding up query times
-- as the database grows with more streams.
-- ==========================================================================

-- Allows the system to instantly find all streams for a specific track.
CREATE INDEX idx_stream_track ON Stream_History_T(Track_ID);

-- Acts as a directory of albums sorted by artist. 
CREATE INDEX idx_album_artist ON Album_T(Artist_ID);

-- Groups listening history by user.
CREATE INDEX idx_stream_listener ON Stream_History_T(Listener_ID);

-- Groups following records by user.
CREATE INDEX idx_follower_listener ON Artist_Follower_T(Listener_ID);
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
