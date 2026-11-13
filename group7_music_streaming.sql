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
    Account_ID   NUMBER(10) PRIMARY KEY,
    Name         VARCHAR2(50) NOT NULL,
    Email        VARCHAR2(60) NOT NULL,
    -- Email VARCHAR2(60) ENCRYPT USING 'AES256' NO SALT NOT NULL,  -- needs wallet
    Join_Date    DATE DEFAULT SYSDATE NOT NULL,
    Account_Type VARCHAR2(15) NOT NULL,

    CONSTRAINT Account_Email_UQ UNIQUE (Email),
    CONSTRAINT Account_Email_CK CHECK (REGEXP_LIKE(Email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
    CONSTRAINT Account_Type_CK CHECK (Account_Type IN ('Listener', 'Artist', 'Admin'))
);

CREATE OR REPLACE TRIGGER Account_JoinDate_TRG
BEFORE INSERT OR UPDATE OF Join_Date ON Account_T
FOR EACH ROW
BEGIN
    IF :NEW.Join_Date > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'Join_Date cannot be in the future.');
    END IF;
END; /

-- --------------------------------------------------------------------------
-- Table: Listener_T (subclass of Account)
-- Columns: Account_ID (PK, FK -> Account), Subscription_Type
-- --------------------------------------------------------------------------

CREATE TABLE Listener_T
(
    Account_ID        NUMBER(10) PRIMARY KEY,
    Subscription_Type VARCHAR2(20) NOT NULL,
        
        CONSTRAINT Listener_Account_FK FOREIGN KEY (Account_ID) REFERENCES Account_T (Account_ID) ON DELETE CASCADE,
        CONSTRAINT Listener_SubType_CK CHECK (Subscription_Type IN ('Free', 'Premium', 'Student', 'Family'))   
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
    Account_ID      NUMBER(10)      PRIMARY KEY,
    Clearance_Level NUMBER(1)       NOT NULL, -- thir is only 1,2,3,4 levels 
    Role_Title      VARCHAR2(40) NOT NULL,

    CONSTRAINT Administrator_Account_FK FOREIGN KEY (Account_ID) REFERENCES Account_T (Account_ID) ON DELETE CASCADE,
    CONSTRAINT Administrator_Clearance_CK CHECK (Clearance_Level BETWEEN 1 AND 4)
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

    CONSTRAINT Playlist_Listener_FK FOREIGN KEY (Listener_ID) REFERENCES Listener_T (Account_ID) ON DELETE CASCADE
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
    CONSTRAINT Playlist_Track_Order_CK CHECK (Track_Order > 0),
    CONSTRAINT Playlist_Track_Order_UQ UNIQUE (Playlist_ID, Track_Order)
);

CREATE OR REPLACE TRIGGER Playlist_Track_Date_TRG
BEFORE INSERT OR UPDATE OF Date_Added ON Playlist_Track_T
FOR EACH ROW
DECLARE
    v_created DATE;
BEGIN
    SELECT Creation_Date INTO v_created
    FROM Playlist_T
    WHERE Playlist_ID = :NEW.Playlist_ID;

    IF :NEW.Date_Added < v_created THEN
        RAISE_APPLICATION_ERROR(-20002, 'Date_Added cannot be before the playlist was created.');
    END IF;
END; /

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

    -- ON DELETE RESTRICT (Oracle default, no clause): stream records are kept for payout calculations
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
    Payout_Date    DATE         NOT NULL,
    Payment_Method VARCHAR2(30) NOT NULL,
    Artist_ID      NUMBER(10)   NOT NULL,
    Approved_By    NUMBER(10),

    -- ON DELETE RESTRICT (Oracle default): financial records cannot be deleted with the artist
    CONSTRAINT Artist_Payout_Artist_FK FOREIGN KEY (Artist_ID) REFERENCES Artist_T (Account_ID),
    CONSTRAINT Artist_Payout_Admin_FK FOREIGN KEY (Approved_By) REFERENCES Administrator_T (Account_ID) ON DELETE SET NULL,
    CONSTRAINT Artist_Payout_Amount_CK CHECK (Amount >= 0),
    CONSTRAINT Artist_Payout_Method_CK CHECK (Payment_Method IN ('Bank Transfer', 'PayPal', 'Check'))
);

-- ==========================================================================
-- SECTION 2.5: INDEXES
-- These indexes prevent full table scans, speeding up query times
-- as the database grows with more streams.
-- ==========================================================================

CREATE INDEX idx_stream_track     ON Stream_History_T(Track_ID);      -- streams per track (payouts)
CREATE INDEX idx_stream_listener  ON Stream_History_T(Listener_ID);   -- listener history
CREATE INDEX idx_album_artist     ON Album_T(Artist_ID);              -- albums by artist
CREATE INDEX idx_album_genre_date ON Album_T(Genre, Release_Date);    -- discovery search
CREATE INDEX idx_track_album      ON Track_T(Album_ID);               -- tracks in an album
CREATE INDEX idx_playlist_listener ON Playlist_T(Listener_ID);        -- a listener's playlists
CREATE INDEX idx_pltrack_track    ON Playlist_Track_T(Track_ID);      -- playlists containing a track
CREATE INDEX idx_follower_artist  ON Artist_Follower_T(Artist_ID);    -- follower counts
CREATE INDEX idx_payout_artist    ON Artist_Payout_T(Artist_ID);      -- payout history

-- idx_follower_listener removed: the PK (Listener_ID, Artist_ID) already covers it

-- ==========================================================================
-- SECTION 3: INSERT SAMPLE DATA
-- Insert into parent tables before child tables.
-- Accounts 1-10 = Listeners, 11-17 = Artists, 18-20 = Administrators
-- ==========================================================================

-- Account_T
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (1, 'Maya Johnson', 'maya.johnson@example.com', DATE '2024-02-14', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (2, 'Kevin Osei', 'kevin.osei@example.com', DATE '2024-05-03', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (3, 'Sofia Ramirez', 'sofia.ramirez@example.com', DATE '2024-08-21', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (4, 'Daniel Kim', 'daniel.kim@example.com', DATE '2024-11-09', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (5, 'Aisha Bello', 'aisha.bello@example.com', DATE '2025-01-17', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (6, 'Tyler Brooks', 'tyler.brooks@example.com', DATE '2025-03-30', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (7, 'Hannah Nguyen', 'hannah.nguyen@example.com', DATE '2025-06-12', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (8, 'Marcus Reed', 'marcus.reed@example.com', DATE '2025-09-05', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (9, 'Grace Mensah', 'grace.mensah@example.com', DATE '2026-01-22', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (10, 'Lucas Ortiz', 'lucas.ortiz@example.com', DATE '2026-04-08', 'Listener');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (11, 'Jordan Ellis', 'jordan.ellis@example.com', DATE '2024-01-10', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (12, 'Amara Okafor', 'amara.okafor@example.com', DATE '2024-03-02', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (13, 'Ethan Walsh', 'ethan.walsh@example.com', DATE '2024-06-18', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (14, 'Priya Desai', 'priya.desai@example.com', DATE '2024-09-27', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (15, 'Caleb Turner', 'caleb.turner@example.com', DATE '2025-02-11', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (16, 'Naomi Clarke', 'naomi.clarke@example.com', DATE '2025-07-04', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (17, 'Omar Haddad', 'omar.haddad@example.com', DATE '2026-02-19', 'Artist');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (18, 'Rachel Stone', 'rachel.stone@example.com', DATE '2024-01-02', 'Admin');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (19, 'Victor Chen', 'victor.chen@example.com', DATE '2024-04-15', 'Admin');
INSERT INTO Account_T (Account_ID, Name, Email, Join_Date, Account_Type) VALUES (20, 'Leah Patel', 'leah.patel@example.com', DATE '2025-05-20', 'Admin');

-- Listener_T
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (1, 'Premium');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (2, 'Free');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (3, 'Student');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (4, 'Family');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (5, 'Premium');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (6, 'Free');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (7, 'Student');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (8, 'Premium');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (9, 'Free');
INSERT INTO Listener_T (Account_ID, Subscription_Type) VALUES (10, 'Family');

-- Artist_T
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (11, 'Kairo Blaze', 'Baltimore rapper blending boom bap with modern trap.', 'Y');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (12, 'Amara Sol', 'Afrobeats singer and songwriter from Lagos.', 'Y');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (13, 'Velvet Harbor', 'Indie rock band built around big guitars and quiet verses.', 'N');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (14, 'Luna Marisol', 'Bedroom pop producer and vocalist.', 'Y');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (15, 'Echo Drift', 'Electronic producer focused on ambient and house.', 'N');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (16, 'Naomi Blue', 'R and B vocalist with a jazz background.', 'Y');
INSERT INTO Artist_T (Account_ID, Stage_Name, Bio, Verified_Status) VALUES (17, 'Solstice Kid', NULL, 'N');

-- Administrator_T
INSERT INTO Administrator_T (Account_ID, Clearance_Level, Role_Title) VALUES (18, 4, 'System Administrator');
INSERT INTO Administrator_T (Account_ID, Clearance_Level, Role_Title) VALUES (19, 3, 'Finance Manager');
INSERT INTO Administrator_T (Account_ID, Clearance_Level, Role_Title) VALUES (20, 2, 'Content Moderator');

-- Album_T
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (1, 'Charm City Nights', DATE '2024-04-12', 'Hip Hop', 11);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (2, 'Back Alley Gospel', DATE '2025-08-29', 'Hip Hop', 11);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (3, 'Lagos Sunrise', DATE '2024-06-07', 'Afrobeats', 12);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (4, 'Golden Hour', DATE '2025-11-14', 'Afrobeats', 12);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (5, 'Static Coastline', DATE '2024-10-04', 'Rock', 13);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (6, 'Paper Lanterns', DATE '2025-02-21', 'Pop', 14);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (7, 'Soft Focus', DATE '2026-03-13', 'Pop', 14);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (8, 'Low Tide Signals', DATE '2025-05-16', 'Electronic', 15);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (9, 'Night Bus', DATE '2026-06-26', 'Electronic', 15);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (10, 'Blue Velvet Hours', DATE '2025-10-10', 'R and B', 16);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (11, 'Late Set', DATE '2026-08-07', 'Jazz', 16);
INSERT INTO Album_T (Album_ID, Title, Release_Date, Genre, Artist_ID) VALUES (12, 'First Light', DATE '2026-05-01', 'Hip Hop', 17);

-- Track_T (Duration is in seconds)
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (1, 'Harbor Lights', 187, 1);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (2, 'Rowhouse Dreams', 229, 1);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (3, 'Light Rail', 154, 1);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (4, 'Sunday Hustle', 234, 2);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (5, 'Mercy Rule', 173, 2);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (6, 'Corner Choir', 226, 2);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (7, 'Third Mainland', 268, 3);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (8, 'Market Day', 203, 3);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (9, 'Ocean Breeze', 200, 3);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (10, 'Golden Hour', 193, 4);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (11, 'Dance For Me', 191, 4);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (12, 'Afro Heat', 271, 4);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (13, 'Saltwater Radio', 162, 5);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (14, 'Undertow', 233, 5);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (15, 'Pier Lights', 209, 5);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (16, 'Paper Lanterns', 255, 6);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (17, 'Glow Stick Heart', 265, 6);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (18, 'Daydream Club', 175, 6);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (19, 'Soft Focus', 289, 7);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (20, 'Polaroid', 189, 7);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (21, 'Slow Motion', 293, 7);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (22, 'Low Tide', 268, 8);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (23, 'Signal Lost', 209, 8);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (24, 'Drift Away', 195, 8);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (25, 'Night Bus', 253, 9);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (26, 'Last Stop', 291, 9);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (27, 'City Hum', 151, 9);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (28, 'Blue Velvet', 173, 10);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (29, 'Candlelight', 269, 10);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (30, 'Stay Awhile', 226, 10);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (31, 'Late Set', 295, 11);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (32, 'Smoke Rings', 311, 11);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (33, 'Brass Moon', 258, 11);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (34, 'First Light', 256, 12);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (35, 'New Money', 183, 12);
INSERT INTO Track_T (Track_ID, Title, Duration, Album_ID) VALUES (36, 'Day One', 174, 12);

-- Playlist_T
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (1, 'Workout Mix', DATE '2024-03-01', 1);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (2, 'Late Night Drive', DATE '2025-01-05', 1);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (3, 'Chill Vibes', DATE '2024-06-10', 2);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (4, 'Study Session', DATE '2024-09-15', 3);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (5, 'Family Road Trip', DATE '2024-12-20', 4);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (6, 'Afro Party', DATE '2025-02-14', 5);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (7, 'Rock Out', DATE '2025-04-22', 6);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (8, 'Focus Beats', DATE '2025-07-01', 7);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (9, 'Weekend Hits', DATE '2025-10-11', 8);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (10, 'Rainy Day', DATE '2026-02-03', 9);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (11, 'New Finds', DATE '2026-05-09', 10);
INSERT INTO Playlist_T (Playlist_ID, Playlist_Name, Creation_Date, Listener_ID) VALUES (12, 'Throwbacks', DATE '2025-11-30', 8);

-- Playlist_Track_T (Date_Added is on or after the playlist Creation_Date)
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (1, 23, DATE '2025-06-01', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (1, 31, DATE '2026-09-17', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (1, 30, DATE '2025-10-29', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (1, 35, DATE '2026-06-03', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (2, 16, DATE '2025-03-28', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (2, 6, DATE '2025-09-14', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (2, 35, DATE '2026-05-21', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (3, 3, DATE '2024-06-28', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (3, 6, DATE '2025-10-01', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (3, 24, DATE '2025-06-30', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (3, 15, DATE '2024-10-20', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (4, 7, DATE '2024-11-11', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (4, 10, DATE '2025-11-15', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (4, 5, DATE '2025-09-25', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (5, 35, DATE '2026-05-01', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (5, 31, DATE '2026-08-30', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (5, 5, DATE '2025-10-25', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (6, 15, DATE '2025-03-18', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (6, 13, DATE '2025-04-12', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (6, 17, DATE '2025-03-05', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (6, 30, DATE '2025-10-11', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (7, 1, DATE '2025-05-24', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (7, 12, DATE '2025-12-02', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (7, 19, DATE '2026-03-25', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (7, 27, DATE '2026-08-02', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (7, 31, DATE '2026-10-06', 5);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (8, 20, DATE '2026-04-06', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (8, 11, DATE '2026-01-02', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (8, 8, DATE '2025-07-17', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (9, 19, DATE '2026-03-28', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (9, 16, DATE '2025-11-02', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (9, 27, DATE '2026-08-24', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (9, 3, DATE '2025-10-16', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (10, 13, DATE '2026-02-24', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (10, 33, DATE '2026-09-26', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (10, 20, DATE '2026-03-26', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (10, 2, DATE '2026-03-17', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (10, 19, DATE '2026-05-02', 5);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (11, 30, DATE '2026-05-14', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (11, 11, DATE '2026-06-11', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (11, 8, DATE '2026-05-12', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (11, 23, DATE '2026-06-13', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (11, 9, DATE '2026-05-27', 5);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (12, 15, DATE '2026-01-17', 1);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (12, 29, DATE '2026-01-11', 2);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (12, 3, DATE '2026-01-26', 3);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (12, 23, DATE '2026-01-05', 4);
INSERT INTO Playlist_Track_T (Playlist_ID, Track_ID, Date_Added, Track_Order) VALUES (12, 31, DATE '2026-08-11', 5);

-- Stream_History_T
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (1, TIMESTAMP '2026-01-24 08:22:20', 8, 30);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (2, TIMESTAMP '2026-02-10 16:16:25', 4, 5);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (3, TIMESTAMP '2026-02-14 22:54:32', 3, 4);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (4, TIMESTAMP '2026-02-28 20:30:05', 6, 15);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (5, TIMESTAMP '2026-03-28 04:46:00', 9, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (6, TIMESTAMP '2026-03-30 22:24:40', 2, 21);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (7, TIMESTAMP '2026-04-02 23:14:29', 9, 7);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (8, TIMESTAMP '2026-04-07 01:27:07', 8, 4);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (9, TIMESTAMP '2026-04-09 17:11:47', 5, 5);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (10, TIMESTAMP '2026-04-10 04:35:54', 1, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (11, TIMESTAMP '2026-04-20 20:51:00', 9, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (12, TIMESTAMP '2026-04-20 23:59:02', 6, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (13, TIMESTAMP '2026-04-25 12:36:33', 9, 9);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (14, TIMESTAMP '2026-04-26 01:01:35', 4, 19);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (15, TIMESTAMP '2026-05-04 10:26:05', 3, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (16, TIMESTAMP '2026-05-11 23:50:20', 10, 14);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (17, TIMESTAMP '2026-05-18 17:17:45', 9, 28);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (18, TIMESTAMP '2026-05-20 04:06:57', 1, 3);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (19, TIMESTAMP '2026-05-20 04:51:28', 2, 5);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (20, TIMESTAMP '2026-05-26 01:03:20', 8, 15);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (21, TIMESTAMP '2026-05-28 10:19:21', 7, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (22, TIMESTAMP '2026-06-04 05:09:33', 6, 20);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (23, TIMESTAMP '2026-06-07 23:57:28', 10, 2);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (24, TIMESTAMP '2026-06-08 01:25:14', 7, 28);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (25, TIMESTAMP '2026-06-10 17:21:51', 2, 9);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (26, TIMESTAMP '2026-06-22 07:09:39', 4, 19);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (27, TIMESTAMP '2026-07-01 00:06:05', 3, 3);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (28, TIMESTAMP '2026-07-01 10:27:45', 4, 4);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (29, TIMESTAMP '2026-07-04 03:31:28', 5, 27);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (30, TIMESTAMP '2026-07-07 03:43:49', 2, 18);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (31, TIMESTAMP '2026-07-07 09:12:45', 5, 21);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (32, TIMESTAMP '2026-07-14 05:56:17', 9, 27);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (33, TIMESTAMP '2026-07-18 15:16:26', 3, 25);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (34, TIMESTAMP '2026-07-30 13:29:49', 1, 4);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (35, TIMESTAMP '2026-08-02 06:13:33', 9, 23);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (36, TIMESTAMP '2026-08-03 05:03:10', 6, 27);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (37, TIMESTAMP '2026-08-07 11:19:08', 9, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (38, TIMESTAMP '2026-08-09 08:52:35', 2, 3);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (39, TIMESTAMP '2026-08-11 05:37:52', 8, 33);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (40, TIMESTAMP '2026-08-13 01:07:37', 8, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (41, TIMESTAMP '2026-08-15 05:40:42', 8, 2);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (42, TIMESTAMP '2026-08-17 11:15:03', 3, 22);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (43, TIMESTAMP '2026-08-20 13:33:06', 1, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (44, TIMESTAMP '2026-08-25 10:18:56', 2, 25);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (45, TIMESTAMP '2026-08-28 04:10:20', 5, 26);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (46, TIMESTAMP '2026-08-28 16:24:13', 2, 14);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (47, TIMESTAMP '2026-08-30 08:03:12', 2, 30);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (48, TIMESTAMP '2026-09-05 03:12:11', 8, 33);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (49, TIMESTAMP '2026-09-05 04:14:12', 4, 25);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (50, TIMESTAMP '2026-09-06 06:09:49', 8, 20);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (51, TIMESTAMP '2026-09-07 21:04:32', 6, 33);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (52, TIMESTAMP '2026-09-14 06:40:47', 8, 24);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (53, TIMESTAMP '2026-09-17 00:04:17', 4, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (54, TIMESTAMP '2026-09-17 02:43:58', 10, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (55, TIMESTAMP '2026-09-17 11:36:52', 8, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (56, TIMESTAMP '2026-09-19 17:05:34', 5, 21);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (57, TIMESTAMP '2026-09-20 04:40:13', 4, 34);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (58, TIMESTAMP '2026-09-20 22:53:32', 9, 15);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (59, TIMESTAMP '2026-09-21 07:50:24', 2, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (60, TIMESTAMP '2026-09-24 03:16:58', 1, 26);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (61, TIMESTAMP '2026-09-25 11:38:00', 7, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (62, TIMESTAMP '2026-09-28 05:37:20', 1, 33);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (63, TIMESTAMP '2026-10-03 02:58:28', 5, 35);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (64, TIMESTAMP '2026-10-03 05:15:25', 5, 27);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (65, TIMESTAMP '2026-10-04 08:03:56', 10, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (66, TIMESTAMP '2026-10-05 04:42:17', 7, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (67, TIMESTAMP '2026-10-07 05:07:43', 7, 33);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (68, TIMESTAMP '2026-10-09 15:11:14', 5, 27);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (69, TIMESTAMP '2026-10-10 03:31:28', 4, 30);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (70, TIMESTAMP '2026-10-11 08:53:21', 7, 5);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (71, TIMESTAMP '2026-10-14 23:56:12', 9, 10);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (72, TIMESTAMP '2026-10-15 06:12:36', 4, 1);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (73, TIMESTAMP '2026-10-17 19:22:17', 4, 22);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (74, TIMESTAMP '2026-10-18 04:54:09', 2, 31);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (75, TIMESTAMP '2026-10-26 03:36:35', 10, 8);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (76, TIMESTAMP '2026-10-29 08:27:23', 5, 15);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (77, TIMESTAMP '2026-11-04 18:06:33', 9, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (78, TIMESTAMP '2026-11-04 22:28:30', 4, 29);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (79, TIMESTAMP '2026-11-06 07:52:21', 3, 9);
INSERT INTO Stream_History_T (Stream_ID, Stream_Timestamp, Listener_ID, Track_ID) VALUES (80, TIMESTAMP '2026-11-07 20:30:44', 3, 31);

-- Artist_Follower_T
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (1, 11, DATE '2025-09-08');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (2, 12, DATE '2026-03-30');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (2, 16, DATE '2026-10-12');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (3, 11, DATE '2025-12-22');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (3, 16, DATE '2025-08-12');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (4, 11, DATE '2025-07-02');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (4, 13, DATE '2025-11-07');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (4, 15, DATE '2025-03-19');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (5, 12, DATE '2025-08-31');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (5, 13, DATE '2026-09-06');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (5, 14, DATE '2025-11-26');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (5, 16, DATE '2025-09-06');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (6, 12, DATE '2025-10-16');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (6, 14, DATE '2026-06-19');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (6, 17, DATE '2026-08-19');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (7, 11, DATE '2026-06-27');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (7, 15, DATE '2025-07-19');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (7, 17, DATE '2026-10-03');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (8, 11, DATE '2025-11-20');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (8, 12, DATE '2026-05-31');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (8, 14, DATE '2026-04-28');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (8, 16, DATE '2026-03-23');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (9, 13, DATE '2026-04-05');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (9, 16, DATE '2026-10-18');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (9, 17, DATE '2026-07-09');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (10, 11, DATE '2026-10-07');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (10, 16, DATE '2026-08-24');
INSERT INTO Artist_Follower_T (Listener_ID, Artist_ID, Follow_Date) VALUES (10, 17, DATE '2026-10-11');

-- Artist_Payout_T (Approved_By NULL = not yet approved)
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (1, 390.38, DATE '2026-07-31', 'Bank Transfer', 11, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (2, 72.95, DATE '2026-08-31', 'Bank Transfer', 11, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (3, 336.56, DATE '2026-09-30', 'Bank Transfer', 11, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (4, 472.71, DATE '2026-07-31', 'PayPal', 12, 18);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (5, 375.44, DATE '2026-08-31', 'PayPal', 12, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (6, 148.78, DATE '2026-09-30', 'PayPal', 12, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (7, 44.74, DATE '2026-07-31', 'Check', 13, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (8, 308.30, DATE '2026-08-31', 'Check', 13, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (9, 105.16, DATE '2026-09-30', 'Check', 13, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (10, 384.46, DATE '2026-07-31', 'Bank Transfer', 14, 18);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (11, 329.71, DATE '2026-08-31', 'Bank Transfer', 14, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (12, 331.87, DATE '2026-09-30', 'Bank Transfer', 14, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (13, 36.73, DATE '2026-07-31', 'PayPal', 15, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (14, 45.33, DATE '2026-08-31', 'PayPal', 15, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (15, 162.29, DATE '2026-09-30', 'PayPal', 15, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (16, 366.87, DATE '2026-07-31', 'Bank Transfer', 16, NULL);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (17, 142.96, DATE '2026-08-31', 'Bank Transfer', 16, 19);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (18, 184.00, DATE '2026-09-30', 'Bank Transfer', 16, 18);
INSERT INTO Artist_Payout_T (Payout_ID, Amount, Payout_Date, Payment_Method, Artist_ID, Approved_By) VALUES (19, 290.44, DATE '2026-09-30', 'PayPal', 17, 19);

COMMIT;

-- ==========================================================================
-- SECTION 4: QUERIES
-- ==========================================================================

-- Query 1: Search tracks by genre and release date (unbiased discovery)
-- Sorted by release date and title, NOT by stream count, so new and small
-- artists show up next to popular ones.
SELECT t.Track_ID,
       t.Title        AS Track_Title,
       ar.Stage_Name  AS Artist,
       al.Title       AS Album,
       al.Genre,
       al.Release_Date,
       t.Duration     AS Duration_Seconds
FROM Track_T t
JOIN Album_T al  ON al.Album_ID   = t.Album_ID
JOIN Artist_T ar ON ar.Account_ID = al.Artist_ID
WHERE al.Genre = 'Hip Hop'
  AND al.Release_Date >= DATE '2025-01-01'
ORDER BY al.Release_Date DESC, t.Title;


-- Query 2: Count streams per artist (used to compute payouts)
-- LEFT JOIN keeps artists with zero streams in the list.
-- Est_Payout uses an example rate of $0.004 per stream.
SELECT ar.Account_ID          AS Artist_ID,
       ar.Stage_Name,
       COUNT(s.Stream_ID)     AS Total_Streams,
       ROUND(COUNT(s.Stream_ID) * 0.004, 2) AS Est_Payout
FROM Artist_T ar
LEFT JOIN Album_T al          ON al.Artist_ID = ar.Account_ID
LEFT JOIN Track_T t           ON t.Album_ID   = al.Album_ID
LEFT JOIN Stream_History_T s  ON s.Track_ID   = t.Track_ID
GROUP BY ar.Account_ID, ar.Stage_Name
ORDER BY Total_Streams DESC;


-- Query 3: List all tracks in a listener's playlists, in Track_Order
SELECT p.Playlist_Name,
       pt.Track_Order,
       t.Title        AS Track_Title,
       ar.Stage_Name  AS Artist,
       pt.Date_Added
FROM Playlist_T p
JOIN Playlist_Track_T pt ON pt.Playlist_ID = p.Playlist_ID
JOIN Track_T t           ON t.Track_ID     = pt.Track_ID
JOIN Album_T al          ON al.Album_ID    = t.Album_ID
JOIN Artist_T ar         ON ar.Account_ID  = al.Artist_ID
WHERE p.Listener_ID = 1
ORDER BY p.Playlist_Name, pt.Track_Order;


-- Query 4: List the artists a listener follows
SELECT ar.Stage_Name,
       ar.Verified_Status,
       af.Follow_Date
FROM Artist_Follower_T af
JOIN Artist_T ar ON ar.Account_ID = af.Artist_ID
WHERE af.Listener_ID = 1
ORDER BY af.Follow_Date;


-- Query 5: Show payout history for an artist (with who approved it)
SELECT ap.Payout_ID,
       ap.Payout_Date,
       ap.Amount,
       ap.Payment_Method,
       NVL(acc.Name, 'Pending approval') AS Approved_By
FROM Artist_Payout_T ap
LEFT JOIN Account_T acc ON acc.Account_ID = ap.Approved_By
WHERE ap.Artist_ID = 11
ORDER BY ap.Payout_Date DESC;

-- ==========================================================================
-- SECTION 5: SECURITY
-- ==========================================================================

COMMENT ON COLUMN Account_T.Name   IS 'Restricted/PII - encryption candidate';
COMMENT ON COLUMN Account_T.Email  IS 'Restricted/PII - encryption candidate';
COMMENT ON COLUMN Artist_Payout_T.Amount IS 'Confidential - encryption candidate';
COMMENT ON COLUMN Artist_T.Stage_Name    IS 'Public';
COMMENT ON COLUMN Listener_T.Subscription_Type IS 'Internal';

CREATE OR REPLACE VIEW Artist_Public_V AS
SELECT Account_ID, Stage_Name, Bio, Verified_Status
FROM Artist_T;

CREATE OR REPLACE VIEW Artist_Stream_Count_V AS
SELECT al.Artist_ID, COUNT(s.Stream_ID) AS Total_Streams
FROM Album_T al
JOIN Track_T t ON t.Album_ID = al.Album_ID
LEFT JOIN Stream_History_T s ON s.Track_ID = t.Track_ID
GROUP BY al.Artist_ID;

CREATE ROLE Listener_Role;
CREATE ROLE Artist_Role;
CREATE ROLE Admin_Role;

-- Listener
GRANT SELECT ON Album_T TO Listener_Role;
GRANT SELECT ON Track_T TO Listener_Role;
GRANT SELECT ON Artist_Public_V TO Listener_Role;
GRANT SELECT, INSERT, UPDATE, DELETE ON Playlist_T TO Listener_Role;
GRANT SELECT, INSERT, UPDATE, DELETE ON Playlist_Track_T TO Listener_Role;
GRANT SELECT, INSERT, DELETE ON Artist_Follower_T TO Listener_Role;
GRANT SELECT, INSERT ON Stream_History_T TO Listener_Role;

-- Artist
GRANT SELECT, INSERT, UPDATE, DELETE ON Album_T TO Artist_Role;
GRANT SELECT, INSERT, UPDATE, DELETE ON Track_T TO Artist_Role;
GRANT UPDATE (Bio) ON Artist_T TO Artist_Role;
GRANT SELECT ON Artist_Payout_T TO Artist_Role;
GRANT SELECT ON Artist_Stream_Count_V TO Artist_Role;

-- Admin
GRANT SELECT, INSERT, UPDATE, DELETE ON Account_T TO Admin_Role;
GRANT SELECT, INSERT, DELETE ON Artist_T TO Admin_Role;
GRANT UPDATE (Verified_Status) ON Artist_T TO Admin_Role;
GRANT SELECT, INSERT ON Artist_Payout_T TO Admin_Role;
GRANT SELECT ON Stream_History_T TO Admin_Role;


-- ==========================================================================
-- END OF SCRIPT
-- ==========================================================================
