-- XS-Boosting
-- Run once. Safe to re-run; every statement is guarded.

CREATE TABLE IF NOT EXISTS `xs_boosting_players` (
  `citizenid`  VARCHAR(64) NOT NULL,
  `handle`     VARCHAR(24) NULL DEFAULT NULL,
  `avatar`     VARCHAR(255) NULL DEFAULT NULL,
  `tagline`    VARCHAR(64) NULL DEFAULT NULL,
  `settings`   TEXT NULL DEFAULT NULL,
  `rep`        INT NOT NULL DEFAULT 0,
  `completed`  INT NOT NULL DEFAULT 0,
  `failed`     INT NOT NULL DEFAULT 0,
  `chopped`    INT NOT NULL DEFAULT 0,
  `earned`     BIGINT NOT NULL DEFAULT 0,
  `heists`     INT NOT NULL DEFAULT 0,
  `last_job`   TIMESTAMP NULL DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`),
  KEY `idx_rep` (`rep`),
  KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Everything placed in the builder. `kind` decides what the row means and
-- what `data` holds.
--   spawn      a place a target vehicle may appear
--   buyer      a handover point
--   chop       a chop shop
--   lockup     somewhere to park a car mid-contract, or keep it for good
--   fence      a no-questions fence
--   deadzone   somewhere a tracker can be killed on the move
--   heist      a heist location
--   heist_exit the exit every heist car must leave through
CREATE TABLE IF NOT EXISTS `xs_boosting_locations` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `kind`       VARCHAR(24) NOT NULL,
  `label`      VARCHAR(96) NOT NULL DEFAULT '',
  `tier`       VARCHAR(32) NULL DEFAULT NULL,
  `x`          FLOAT NOT NULL,
  `y`          FLOAT NOT NULL,
  `z`          FLOAT NOT NULL,
  `heading`    FLOAT NOT NULL DEFAULT 0,
  `radius`     FLOAT NOT NULL DEFAULT 10,
  `enabled`    TINYINT(1) NOT NULL DEFAULT 1,
  `data`       LONGTEXT NULL DEFAULT NULL,
  `created_by` VARCHAR(64) NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_kind` (`kind`),
  KEY `idx_kind_tier` (`kind`, `tier`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `xs_boosting_history` (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `citizenid`  VARCHAR(64) NOT NULL,
  `type`       VARCHAR(24) NOT NULL,
  `tier`       VARCHAR(32) NOT NULL,
  `model`      VARCHAR(64) NOT NULL DEFAULT '',
  `label`      VARCHAR(96) NOT NULL DEFAULT '',
  `outcome`    VARCHAR(24) NOT NULL,
  `payout`     INT NOT NULL DEFAULT 0,
  `condition`  INT NOT NULL DEFAULT 0,
  `crew`       TEXT NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Cars parked in a lockup mid-contract. The clock stops, so the row carries
-- everything needed to put the job back exactly as it was.
CREATE TABLE IF NOT EXISTS `xs_boosting_stored` (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `citizenid`   VARCHAR(64) NOT NULL,
  `location_id` INT NOT NULL,
  `job`         LONGTEXT NOT NULL,
  `remaining`   INT NOT NULL DEFAULT 0,
  `condition`   INT NOT NULL DEFAULT 100,
  `stored_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`),
  KEY `idx_location` (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fence prices. One row per tier, rewritten on every market shift.
CREATE TABLE IF NOT EXISTS `xs_boosting_market` (
  `tier`       VARCHAR(32) NOT NULL,
  `multiplier` FLOAT NOT NULL DEFAULT 1,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`tier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Which players have found which places, for blips set to discoveredOnly.
CREATE TABLE IF NOT EXISTS `xs_boosting_discovered` (
  `citizenid`   VARCHAR(64) NOT NULL,
  `location_id` INT NOT NULL,
  `found_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
