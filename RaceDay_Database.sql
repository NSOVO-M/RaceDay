/* =====================================================================
   RaceDay - Database Script (SQL Server / SSMS)
   Part 1, Section C
   Entities: Roles, Users, EventTypes, Events, Categories, Enrolments, Results
   ===================================================================== */

IF DB_ID(N'RaceDayDB') IS NULL
    CREATE DATABASE RaceDayDB;
GO
USE RaceDayDB;
GO

/* ---------- Clean re-run support (drop in dependency order) ---------- */
DROP TABLE IF EXISTS dbo.Results;
DROP TABLE IF EXISTS dbo.Enrolments;
DROP TABLE IF EXISTS dbo.Categories;
DROP TABLE IF EXISTS dbo.Events;
DROP TABLE IF EXISTS dbo.EventTypes;
DROP TABLE IF EXISTS dbo.Users;
DROP TABLE IF EXISTS dbo.Roles;
GO

/* ============================ TABLES ================================= */

CREATE TABLE dbo.Roles (
    RoleId      INT IDENTITY(1,1)  NOT NULL,
    RoleName    NVARCHAR(20)       NOT NULL,
    CONSTRAINT PK_Roles PRIMARY KEY (RoleId),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);

CREATE TABLE dbo.Users (
    UserId                  INT IDENTITY(1,1)  NOT NULL,
    RoleId                  INT                NOT NULL,
    FirstName               NVARCHAR(50)       NOT NULL,
    LastName                NVARCHAR(50)       NOT NULL,
    Email                   NVARCHAR(100)      NOT NULL,
    PasswordHash            NVARCHAR(255)      NOT NULL,
    PhoneNumber             NVARCHAR(20)       NULL,
    DateOfBirth             DATE               NOT NULL,
    Gender                  NVARCHAR(10)       NOT NULL,
    Province                NVARCHAR(30)       NULL,
    EmergencyContactName    NVARCHAR(100)      NULL,
    EmergencyContactNumber  NVARCHAR(20)       NULL,
    IsActive                BIT                NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAt               DATETIME2(0)       NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Users PRIMARY KEY (UserId),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles (RoleId),
    CONSTRAINT CK_Users_Gender CHECK (Gender IN (N'Male', N'Female', N'Other'))
);

CREATE TABLE dbo.EventTypes (
    EventTypeId INT IDENTITY(1,1)  NOT NULL,
    TypeName    NVARCHAR(20)       NOT NULL,
    CONSTRAINT PK_EventTypes PRIMARY KEY (EventTypeId),
    CONSTRAINT UQ_EventTypes_TypeName UNIQUE (TypeName)
);

CREATE TABLE dbo.Events (
    EventId          INT IDENTITY(1,1)  NOT NULL,
    OrganiserId      INT                NOT NULL,
    EventTypeId      INT                NOT NULL,
    Name             NVARCHAR(150)      NOT NULL,
    Description      NVARCHAR(1000)     NOT NULL,
    EventDate        DATETIME2(0)       NOT NULL,
    Location         NVARCHAR(200)      NOT NULL,
    DistanceKm       DECIMAL(6,2)       NOT NULL,
    MaxParticipants  INT                NULL,
    CreatedAt        DATETIME2(0)       NOT NULL CONSTRAINT DF_Events_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Events PRIMARY KEY (EventId),
    CONSTRAINT FK_Events_Users FOREIGN KEY (OrganiserId) REFERENCES dbo.Users (UserId),
    CONSTRAINT FK_Events_EventTypes FOREIGN KEY (EventTypeId) REFERENCES dbo.EventTypes (EventTypeId),
    CONSTRAINT CK_Events_Distance CHECK (DistanceKm > 0),
    CONSTRAINT CK_Events_MaxParticipants CHECK (MaxParticipants IS NULL OR MaxParticipants > 0)
);

CREATE TABLE dbo.Categories (
    CategoryId    INT IDENTITY(1,1)  NOT NULL,
    EventId       INT                NOT NULL,
    Name          NVARCHAR(60)       NOT NULL,
    CategoryType  NVARCHAR(10)       NOT NULL,
    MinAge        INT                NULL,
    MaxAge        INT                NULL,
    DistanceKm    DECIMAL(6,2)       NULL,
    EntryFee      DECIMAL(10,2)      NOT NULL CONSTRAINT DF_Categories_EntryFee DEFAULT (0),
    CONSTRAINT PK_Categories PRIMARY KEY (CategoryId),
    CONSTRAINT UQ_Categories_Event_Name UNIQUE (EventId, Name),
    CONSTRAINT UQ_Categories_Id_Event UNIQUE (CategoryId, EventId),  -- target for composite FK from Enrolments
    CONSTRAINT FK_Categories_Events FOREIGN KEY (EventId) REFERENCES dbo.Events (EventId) ON DELETE CASCADE,
    CONSTRAINT CK_Categories_Type CHECK (CategoryType IN (N'Age', N'Distance')),
    CONSTRAINT CK_Categories_AgeRange CHECK (MinAge IS NULL OR MaxAge IS NULL OR MinAge <= MaxAge),
    CONSTRAINT CK_Categories_Fee CHECK (EntryFee >= 0)
);

CREATE TABLE dbo.Enrolments (
    EnrolmentId  INT IDENTITY(1,1)  NOT NULL,
    UserId       INT                NOT NULL,   -- Participant
    EventId      INT                NOT NULL,
    CategoryId   INT                NOT NULL,
    RaceNumber   INT                NULL,
    Status       NVARCHAR(15)       NOT NULL CONSTRAINT DF_Enrolments_Status DEFAULT (N'Confirmed'),
    EnrolledAt   DATETIME2(0)       NOT NULL CONSTRAINT DF_Enrolments_EnrolledAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Enrolments PRIMARY KEY (EnrolmentId),
    CONSTRAINT UQ_Enrolments_User_Event UNIQUE (UserId, EventId),   -- one entry per participant per event
    CONSTRAINT FK_Enrolments_Users FOREIGN KEY (UserId) REFERENCES dbo.Users (UserId),
    CONSTRAINT FK_Enrolments_Events FOREIGN KEY (EventId) REFERENCES dbo.Events (EventId) ON DELETE CASCADE,
    -- composite FK guarantees the chosen category belongs to the same event
    CONSTRAINT FK_Enrolments_Categories FOREIGN KEY (CategoryId, EventId)
        REFERENCES dbo.Categories (CategoryId, EventId),
    CONSTRAINT CK_Enrolments_Status CHECK (Status IN (N'Confirmed', N'Withdrawn'))
);

CREATE TABLE dbo.Results (
    ResultId          INT IDENTITY(1,1)  NOT NULL,
    EnrolmentId       INT                NOT NULL,
    CapturedByUserId  INT                NOT NULL,   -- Organiser
    FinishTime        TIME(0)            NULL,
    OverallPosition   INT                NULL,
    CategoryPosition  INT                NULL,
    ResultStatus      NVARCHAR(10)       NOT NULL CONSTRAINT DF_Results_Status DEFAULT (N'Finished'),
    CapturedAt        DATETIME2(0)       NOT NULL CONSTRAINT DF_Results_CapturedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Results PRIMARY KEY (ResultId),
    CONSTRAINT UQ_Results_Enrolment UNIQUE (EnrolmentId),           -- 1:1 with Enrolment
    CONSTRAINT FK_Results_Enrolments FOREIGN KEY (EnrolmentId) REFERENCES dbo.Enrolments (EnrolmentId) ON DELETE CASCADE,
    CONSTRAINT FK_Results_Users FOREIGN KEY (CapturedByUserId) REFERENCES dbo.Users (UserId),
    CONSTRAINT CK_Results_Status CHECK (ResultStatus IN (N'Finished', N'DNF', N'DNS', N'DSQ')),
    CONSTRAINT CK_Results_Positions CHECK ((OverallPosition IS NULL OR OverallPosition > 0)
                                       AND (CategoryPosition IS NULL OR CategoryPosition > 0)),
    CONSTRAINT CK_Results_FinishedHasTime CHECK (ResultStatus <> N'Finished'
                                       OR (FinishTime IS NOT NULL AND OverallPosition IS NOT NULL))
);
GO

/* ====================== INDEXES (common lookups) ===================== */
CREATE INDEX IX_Events_EventDate     ON dbo.Events (EventDate);
CREATE INDEX IX_Events_OrganiserId   ON dbo.Events (OrganiserId);
CREATE INDEX IX_Enrolments_EventId   ON dbo.Enrolments (EventId);
GO

/* =========================== SEED DATA =============================== */
-- NOTE: Identity values start at 1 on a fresh database, so literal IDs are used below.
-- PasswordHash values are PLACEHOLDERS. In Part 2 the API hashes passwords (BCrypt) on
-- registration - register new accounts through POST /api/auth/register to log in.

INSERT INTO dbo.Roles (RoleName) VALUES (N'Organiser'), (N'Participant');   -- 1, 2

INSERT INTO dbo.EventTypes (TypeName) VALUES (N'Run'), (N'Walk'), (N'Cycle'); -- 1, 2, 3

-- Users: 1-2 Organisers, 3-6 Participants
INSERT INTO dbo.Users
 (RoleId, FirstName, LastName, Email, PasswordHash, PhoneNumber, DateOfBirth, Gender, Province, EmergencyContactName, EmergencyContactNumber)
VALUES
 (1, N'Thabo',   N'Mokoena',  N'thabo.mokoena@raceday.co.za',  N'SEED_PLACEHOLDER_HASH', N'0821234567', '1984-03-12', N'Male',   N'Gauteng',       N'Lerato Mokoena',  N'0839876543'),
 (1, N'Annelize',N'van Wyk',  N'annelize.vanwyk@raceday.co.za',N'SEED_PLACEHOLDER_HASH', N'0724567890', '1979-11-02', N'Female', N'Western Cape',  N'Pieter van Wyk',  N'0827654321'),
 (2, N'Sipho',   N'Dlamini',  N'sipho.dlamini@example.co.za',  N'SEED_PLACEHOLDER_HASH', N'0611112222', '1995-06-21', N'Male',   N'Gauteng',       N'Nomsa Dlamini',   N'0612223333'),
 (2, N'Chantelle',N'Naidoo',  N'chantelle.naidoo@example.co.za',N'SEED_PLACEHOLDER_HASH',N'0733334444', '2008-01-15', N'Female', N'KwaZulu-Natal', N'Priya Naidoo',    N'0734445555'),
 (2, N'Johan',   N'Botha',    N'johan.botha@example.co.za',    N'SEED_PLACEHOLDER_HASH', N'0845556666', '1961-09-30', N'Male',   N'Gauteng',       N'Marie Botha',     N'0846667777'),
 (2, N'Zanele',  N'Khumalo',  N'zanele.khumalo@example.co.za', N'SEED_PLACEHOLDER_HASH', N'0767778888', '1990-12-05', N'Female', N'Gauteng',       N'Themba Khumalo',  N'0768889999');

-- Events: 1 = past (has results), 2 & 3 = upcoming
INSERT INTO dbo.Events (OrganiserId, EventTypeId, Name, Description, EventDate, Location, DistanceKm, MaxParticipants)
VALUES
 (1, 1, N'Joburg Spring 10K Run',
     N'A fast, flat 10km road race through the northern suburbs to welcome spring.',
     '2026-09-12 06:30', N'Delta Park, Randburg, Johannesburg', 10.00, 1500),
 (1, 2, N'Rosebank Charity Fun Walk',
     N'A relaxed community walk raising funds for local children''s charities. Prams and dogs welcome.',
     '2026-11-21 07:00', N'Rosebank Park, Johannesburg', 5.00, 3000),
 (2, 3, N'Magaliesberg Cycle Classic',
     N'A scenic road cycling event through the Magaliesberg with rolling hills and water points.',
     '2026-12-05 05:45', N'Hartbeespoort Dam, North West', 70.00, 2000);

-- Categories (event 1: 1-3, event 2: 4-6, event 3: 7-10)
INSERT INTO dbo.Categories (EventId, Name, CategoryType, MinAge, MaxAge, DistanceKm, EntryFee)
VALUES
 (1, N'Under 20',      N'Age',      13, 19,   10.00, 120.00),
 (1, N'Open (20-49)',  N'Age',      20, 49,   10.00, 150.00),
 (1, N'Veteran 50+',   N'Age',      50, NULL, 10.00, 150.00),
 (2, N'2.5km Family',  N'Distance', NULL, NULL, 2.50, 50.00),
 (2, N'5km Walk',      N'Distance', NULL, NULL, 5.00, 80.00),
 (2, N'Senior 60+ 5km',N'Age',      60, NULL,  5.00, 60.00),
 (3, N'35km Fun Ride', N'Distance', NULL, NULL, 35.00, 350.00),
 (3, N'70km Standard', N'Distance', NULL, NULL, 70.00, 450.00),
 (3, N'Under 20 70km', N'Age',      13, 19,   70.00, 300.00),
 (3, N'Masters 50+ 70km', N'Age',   50, NULL, 70.00, 450.00);

-- Enrolments (category must belong to the same event - enforced by composite FK)
INSERT INTO dbo.Enrolments (UserId, EventId, CategoryId, RaceNumber, Status)
VALUES
 (3, 1, 2, 101, N'Confirmed'),   -- 1 Sipho   -> 10K Open
 (4, 1, 1, 102, N'Confirmed'),   -- 2 Chantelle -> 10K Under 20
 (5, 1, 3, 103, N'Confirmed'),   -- 3 Johan   -> 10K Veteran
 (6, 1, 2, 104, N'Confirmed'),   -- 4 Zanele  -> 10K Open
 (3, 2, 5, 201, N'Confirmed'),   -- 5 Sipho   -> Charity 5km
 (5, 2, 6, 202, N'Confirmed'),   -- 6 Johan   -> Senior 5km
 (6, 3, 8, 301, N'Confirmed'),   -- 7 Zanele  -> Cycle 70km
 (3, 3, 8, 302, N'Confirmed'),   -- 8 Sipho   -> Cycle 70km
 (5, 3, 10,303, N'Confirmed');   -- 9 Johan   -> Masters 70km

-- Results for the completed 10K (enrolments 1-4), captured by Organiser 1
INSERT INTO dbo.Results (EnrolmentId, CapturedByUserId, FinishTime, OverallPosition, CategoryPosition, ResultStatus)
VALUES
 (4, 1, '00:42:30', 1, 1, N'Finished'),   -- Zanele   - Open, 1st overall
 (1, 1, '00:44:12', 2, 2, N'Finished'),   -- Sipho    - Open, 2nd in category
 (2, 1, '00:51:40', 3, 1, N'Finished'),   -- Chantelle- Under 20, 1st in category
 (3, 1, '00:58:05', 4, 1, N'Finished');   -- Johan    - Veteran 50+, 1st in category
GO
